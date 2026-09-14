-- ┌─────────────────┐
-- │ Run the project │
-- └─────────────────┘
--
-- `:Run` is one command with one meaning in every language that has one: start
-- *this project*, in a terminal split, with the command the project itself says
-- to use. Deliberately not one name per ecosystem - `:Crun` for cargo, an
-- `:NpmStart`, an `:MvnExec` - because what has to be remembered when opening an
-- unfamiliar repository is a single key, not the build tool it happens to use.
--
-- The contract, which every filetype that defines it keeps:
--
-- - It runs the PROJECT, not the file. The only exception is a file that belongs
--   to no project at all, where the two coincide.
-- - It captures: a terminal split (`:h terminal-emulator`), so the output is
--   there while it comes and the process dies with the editor instead of being
--   left holding a port. Something with a window of its own would be detached
--   instead (`:h vim.system()` with `detach`), which is another axis.
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

-- TODO: exercise this against a real project, which is the half a headless
-- check cannot reach. What the probes prove is *which* command would start:
-- they run with `vim.fn.jobstart` replaced by a stub, so no process is ever
-- spawned, no terminal buffer is ever drawn, and nothing is ever killed on
-- quit. Still unproven is the part `:h terminal-emulator` owns - the split
-- showing output while it comes rather than at the end, `<C-\><C-N>` leaving
-- its insert mode, and closing Neovim taking the process down with it instead
-- of leaving a port held. Not now: it needs a project that actually boots, and
-- the Maven ones here resolve from a private repository that is not always
-- reachable. First step is `:Run` in one of them with the split visible, then
-- `:qa` and a look at what is still running.

local M = {}

-- Define `:Run` for the current buffer. `resolve` is given the arguments the
-- command was called with and returns the command as a list, or `nil` and the
-- reason when the project does not say how to run itself.
--
-- NOTE: `resolve` runs before the split is opened, and the order is not a matter
-- of taste: `:vertical new` makes an unnamed buffer the current one, so a
-- resolver that asks about the file it was invoked on - the one outside any
-- project - would read an empty name.
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

M.command = function(resolve)
  vim.api.nvim_buf_create_user_command(0, 'Run', function(params)
    local cmd, reason = project_command(params.fargs)
    if cmd == nil and reason == nil then
      cmd, reason = resolve(params.fargs)
    end
    if cmd == nil then
      vim.notify(reason or 'nothing to run here', vim.log.levels.WARN)
      return
    end

    vim.cmd('vertical new')
    local ok, err = pcall(vim.fn.jobstart, cmd, { term = true })
    if not ok then
      vim.cmd('quit')
      vim.notify(tostring(err), vim.log.levels.ERROR)
    end
  end, { nargs = '*', desc = 'Run the project in a terminal split' })
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
  if #args > 0 then return vim.list_extend({ 'npm', 'run' }, args) end

  local ok, manifest_data =
    pcall(vim.json.decode, table.concat(vim.fn.readfile(manifest), '\n'))
  local scripts = (ok and type(manifest_data) == 'table' and manifest_data.scripts)
    or {}
  for _, script in ipairs({ 'start', 'dev', 'serve' }) do
    if scripts[script] ~= nil then return { 'npm', 'run', script } end
  end

  local reason =
    '%s declares no `start`, `dev` or `serve` script: name one, `:Run <task>`'
  return nil, reason:format(vim.fs.basename(manifest))
end

return M
