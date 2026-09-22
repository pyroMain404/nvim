-- ┌─────────────────┐
-- │ Run the project │
-- └─────────────────┘
--
-- `:Run` is one command with one meaning in every language that has one: start
-- *this project*, with the command the project itself says to use. Deliberately
-- not one name per ecosystem - `:Crun` for cargo, an
-- `:NpmStart`, an `:MvnExec` - because what has to be remembered when opening an
-- unfamiliar repository is a single key, not the build tool it happens to use.
--
-- The contract, which every filetype that defines it keeps:
--
-- - It runs the PROJECT, not the file. The only exception is a file that belongs
--   to no project at all, where the two coincide.
-- - It shows the output where the program actually writes it, and that is one
--   choice per language rather than one for all. The default is CAPTURED: a
--   terminal split (`:h terminal-emulator`), so the output is there while it
--   comes and the process dies with the editor instead of being left holding a
--   port. A program with a window of its own takes `{ detach = true }` instead
--   (`:h vim.system()`), and the reason is not taste: measured on Windows with
--   Godot, a captured game leaves the split EMPTY and writes on the stdout of
--   Neovim itself - the screen the interface is drawn on. A detached process
--   outlives `:qa`, which is the price of having a window of its own, and the
--   price of showing nothing: where there is no window to write in, what is
--   reported instead is a process that DIED - its exit status and the last line
--   it wrote on stderr. A start that fails has to stay visible even when the
--   output does not.
-- - Its default is READ from the project, never fixed: which script, which goal,
--   which binary is a property of the checkout. Where it cannot be read, the
--   command has to fail loudly - `cargo run` in a workspace lists the binaries
--   it could not choose between - rather than quietly run the wrong thing.
-- - Arguments replace that default (`:Run --bin server`, `:Run e2e`,
--   `:Run test -DskipTests`). That is how the project specific case is answered
--   without teaching any of these files about it.
-- - It is NOT `:make`, which answers a question that ends and fills the quickfix
--   list. This starts something that lives.
-- - The PROJECT has the last word: `vim.b.run_command` or `vim.g.run_command`,
--   set from its '.nvim.lua' (`:h 'exrc'`, skill `nvim-project-environment`),
--   replaces whatever the language would have resolved. A repository that is
--   always started one way says so once instead of having it typed every time.
--
-- The command is buffer-local, so the name costs nothing in any other buffer,
-- and it is defined from 'after/ftplugin/<ft>.lua' - which is where the
-- knowledge of a language belongs. What lives here is the shape they share.

local M = {}

-- Define `:Run` for the current buffer. `resolve` is given the arguments the
-- command was called with. It returns a command and, as its optional third
-- value, the project root it resolved; a failed resolver returns `nil` and the
-- reason to report.
--
-- NOTE: `resolve` runs before the split is opened, and even when an override
-- wins: `:new` makes an unnamed buffer the current one, while an
-- override still has to run from the root the original resolver identified.
--
-- `jobstart()` takes a list, which never goes through `:h 'shell'`, so nothing
-- here depends on quoting rules that differ between `cmd.exe` and PowerShell. It
-- raises instead of returning when the program is missing, hence the `pcall`:
-- the message it carries ("no such file or directory: mvn") is the useful half,
-- and the split opened for it has to go away with it.
-- The override is either a list - the whole command, to which the arguments of
-- the call are appended - or a function of those arguments, which answers like
-- any other resolver. A project whose filetypes need different commands reads
-- `vim.bo.filetype` inside that function.
--
-- NOTE: the list is copied before it is extended. Extending it in place would
-- append to the variable itself, so the second `:Run test` of a session would
-- carry the arguments of the first, and the third both - each run quietly
-- different from the last.
local function project_command(args)
  local project = vim.b.run_command or vim.g.run_command
  if type(project) == 'function' then return project(args) end
  if type(project) == 'table' then
    return vim.list_extend(vim.deepcopy(project), args)
  end
  return nil, nil
end

-- `opts.detach` picks the other branch: no window, no terminal buffer, and a
-- process that survives the editor - for a program that draws its own window and
-- would leave an empty split behind. `vim.system()` also takes a list and also
-- raises when the program is missing, so the two branches fail the same way.
--
-- NOTE: a detached program has no window here to write in, so the only thing
-- this branch can report is that it DIED - and it has to, because a start that
-- fails is otherwise indistinguishable from one that works. Measured on a Godot
-- project with no `run/main_scene`: `:Run` said nothing at all, while the same
-- command on the command line printed `Can't run project: no main scene defined
-- in the project` and exited 1. `on_exit` is what closes that hole, and a
-- program that is still running is reported by nothing, which is the point.
--
-- NOTE: `stdout` and `stderr` are functions and not the default `true`, which
-- ACCUMULATES everything a process writes for as long as it lives - and a game
-- lives for hours. What is kept instead is the last two thousand characters of
-- each stream, and BOTH of them: Godot writes `Can't run project: no main scene
-- defined in the project` on STDOUT (measured: 65 bytes there, 0 on stderr), so
-- reading one of the two would miss exactly the message this reports. The exit
-- callback runs in a fast event context (`:h lua-loop-callbacks`), where
-- `vim.notify()` is not allowed, hence the `vim.schedule()`.
M.command = function(resolve, opts)
  local detach = (opts or {}).detach == true
  local desc = detach and 'Run the project as its own process'
    or 'Run the project in a terminal split'
  vim.api.nvim_buf_create_user_command(0, 'Run', function(params)
    local resolved, reason, cwd = resolve(params.fargs)
    local cmd = project_command(params.fargs) or resolved
    if cmd == nil then
      vim.notify(reason or 'nothing to run here', vim.log.levels.WARN)
      return
    end
    cwd = cwd or vim.fs.dirname(vim.api.nvim_buf_get_name(0))

    if detach then
      local tail = { stdout = '', stderr = '' }
      local function keep(stream)
        return function(_, data)
          if data == nil then return end
          -- No length test needed: `sub(-2000)` of a shorter string is the
          -- string itself
          tail[stream] = (tail[stream] .. data):sub(-2000)
        end
      end
      local started, err = pcall(vim.system, cmd, {
        cwd = cwd,
        detach = true,
        stdout = keep('stdout'),
        stderr = keep('stderr'),
      }, function(out)
        if out.code == 0 and out.signal == 0 then return end
        vim.schedule(function()
          local status = out.signal ~= 0 and ('signal ' .. out.signal)
            or ('code ' .. out.code)
          -- The last line written, not the whole tail: one message, not a
          -- paragraph. stderr first, stdout as the fallback it had to be for
          -- the engine this branch was measured on.
          local function last_line(s)
            local lines = vim.split(vim.trim(s), '\n', { trimempty = true })
            return lines[#lines] or ''
          end
          local why = last_line(tail.stderr)
          if why == '' then why = last_line(tail.stdout) end
          local message = ('`%s` exited with %s'):format(cmd[1], status)
          if why ~= '' then message = message .. ': ' .. why end
          vim.notify(message, vim.log.levels.ERROR)
        end)
      end)
      if not started then vim.notify(tostring(err), vim.log.levels.ERROR) end
      return
    end

    vim.cmd('new')
    local ok, err = pcall(vim.fn.jobstart, cmd, { cwd = cwd, term = true })
    if not ok then
      vim.cmd('quit')
      vim.notify(tostring(err), vim.log.levels.ERROR)
    end
  end, { nargs = '*', desc = desc })
  -- Every ftplugin that calls `M.command()` gets `:Run` undone for free when
  -- the filetype changes away, instead of each one registering it by hand
  -- (`:h b:undo_ftplugin`).
  vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '') .. '\n' .. 'delcommand Run'
end

-- The npm ecosystem, used by both 'after/ftplugin/typescript.lua' and
-- 'after/ftplugin/htmlangular.lua': an Angular component is two files and one
-- project. It sits here for the same reason 'compiler/ngc.lua' is a single file
-- selected from two ftplugins.
--
-- `npm run <task>` is the whole interface, and the default is the script the
-- project declares. Reaching for `ng serve` instead would be right for a
-- standard Angular CLI project and wrong for every one whose start is a proxy, a
-- `dev` script, or a wrapper of its own - while `"start": "ng serve"` is what
-- those same projects write in their 'package.json' anyway (checked against the
-- three on this machine).
--
-- NOTE: `npm`, with no extension. On Windows `jobstart()` resolves it through
-- PATHEXT like any other program, while `npm.cmd` - the name most recipes use -
-- is not on the PATH here at all and raises `E475`.
M.npm = function(args)
  local manifest = vim.fs.find('package.json', {
    upward = true,
    path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
  })[1]
  if manifest == nil then return nil, 'no package.json above this file' end
  local root = vim.fs.dirname(manifest)
  if #args > 0 then return vim.list_extend({ 'npm', 'run' }, args), nil, root end

  local ok, manifest_data =
    pcall(vim.json.decode, table.concat(vim.fn.readfile(manifest), '\n'))
  local scripts = (ok and type(manifest_data) == 'table' and manifest_data.scripts)
    or {}
  for _, script in ipairs({ 'start', 'dev', 'serve' }) do
    if scripts[script] ~= nil then return { 'npm', 'run', script }, nil, root end
  end

  local reason =
    '%s declares no `start`, `dev` or `serve` script: name one, `:Run <task>`'
  return nil, reason:format(vim.fs.basename(manifest)), root
end

-- The remedy for `:make` printing paths relative to the project instead of
-- relative to Neovim's own directory: chdir to the project root for the
-- duration of `:make`/`:lmake` and back after. Lifted out of the GDScript
-- ftplugin, which was the only file that had it, once the same fix turned out
-- to be needed for Angular (`ng`/`npm`) and Maven, both of which print
-- project-relative paths while `setup_auto_root()` in 'plugin/30_mini.lua'
-- keeps Neovim's cwd at the repository root - not necessarily the manifest's
-- directory in a monorepo or a nested checkout.
--
-- NOTE: the pair cannot be buffer-local. `QuickFixCmdPre` matches its pattern
-- against the COMMAND NAME (`:h QuickFixCmdPre`), so `buffer = 0` would ask
-- for a pattern that never matches. Hence one named group per filetype,
-- cleared on every load so opening a second buffer of that filetype replaces
-- the pair instead of adding one, and a filetype test inside the callback.
--
-- `vim.fn.chdir()` and not `:lcd`: it changes the directory in whatever scope
-- the current one has - window, tab or global - and returns the previous one
-- to restore. `:lcd` would leave the window with a local directory it did not
-- have, which `MiniMisc.setup_auto_root()` would then never move again.
M.make_root = function(markers)
  local ft = vim.bo.filetype
  local group =
    vim.api.nvim_create_augroup('config-make-root-' .. ft, { clear = true })
  local previous = nil
  vim.api.nvim_create_autocmd('QuickFixCmdPre', {
    group = group,
    pattern = { 'make', 'lmake' },
    desc = 'Run `:make` from the project root (' .. ft .. ')',
    callback = function()
      if vim.bo.filetype ~= ft then return end
      local project = vim.fs.root(0, markers)
      if project == nil then return end
      previous = vim.fn.chdir(project)
    end,
  })
  vim.api.nvim_create_autocmd('QuickFixCmdPost', {
    group = group,
    pattern = { 'make', 'lmake' },
    desc = 'Return to the directory `:make` was called from (' .. ft .. ')',
    callback = function()
      if previous == nil or previous == '' then return end
      vim.fn.chdir(previous)
      previous = nil
    end,
  })
end

-- Shared Maven run resolution. `after/ftplugin/java.lua` uses this when walking
-- up from an arbitrary '.java' buffer to the project's `pom.xml`;
-- `after/ftplugin/xml.lua` uses the same table when the buffer opened IS that
-- manifest - the case that used to have no `:Run` at all, because
-- `:h ft-xml-plugin` never loads `java.lua`. Only the *run* half is shared:
-- which compiler plugin `:make` selects, and the rest of Java's buffer-local
-- settings, stay in `java.lua` and are never pulled into a plain XML buffer.
--
-- `goal(args, default)` turns the arguments `:Run` was called with into the
-- goal/task handed to the build tool, or the project's own default when
-- none were given.
local function goal(args, default) return #args > 0 and args or { default } end

M.java_builds = {
  ['pom.xml'] = {
    -- Maven has no universal goal for running a project: `spring-boot:run`
    -- exists only with the Spring Boot plugin, `exec:java` only where the
    -- project configures `exec-maven-plugin`. Reading which one off the POM
    -- and letting the other fail loudly in the terminal beats picking one
    -- and doing nothing quietly.
    run = function(args, build_file)
      local boot = false
      for _, line in ipairs(vim.fn.readfile(build_file)) do
        if line:find('spring%-boot%-maven%-plugin') then
          boot = true
          break
        end
      end
      local task = boot and 'spring-boot:run' or 'exec:java'
      return vim.list_extend({ 'mvn' }, goal(args, task))
    end,
  },
}

return M
