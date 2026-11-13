-- ┌─────────────────┐
-- │ Run the project │
-- └─────────────────┘
--
-- `:Run` starts the project with its declared command, under one command name for all languages.
-- 'after/ftplugin/<ft>.lua' defines it with the contract below.
--
-- - It runs the project, or the file if no project exists.
-- - A terminal split shows output (`:h terminal-emulator`).
-- - A program with its own window uses `{ detach = true }` (`:h vim.system()`) and continues after
-- `:qa`.
-- - Read the default from the project. Report an error if the default is unavailable.
-- - Unlike `:make`, this command starts a running program.
--
-- - Arguments replace the default.
-- - `vim.b.run_command` or the project's `run` contract (`lua/config/project.lua`) replace the default.

local M = {}

-- Define `:Run` for the current buffer.
-- `resolve(args)` returns a command and optional project root, or `nil` and a reason to report.
-- NOTE: `resolve` runs before the split opens, even when an override wins.
-- `:new` makes an unnamed buffer current, and the override needs the original root.
-- NOTE: Copy the override list before adding arguments so each `:Run` does not retain previous
-- arguments.
local function project_command(args)
  local project = vim.b.run_command or (require('config.project').contract('run'))
  if type(project) == 'function' then return project(args) end
  if type(project) == 'table' then
    return vim.list_extend(vim.deepcopy(project), args)
  end
  return nil, nil
end

-- NOTE: `on_exit` reports a failed detached process with its status and last output line;
-- otherwise, the failure stays invisible.
-- NOTE: Use functions for `stdout`/`stderr`; `true` accumulates output throughout the process.
-- Keep the last 2000 characters of both because Godot writes errors on stdout.
-- The exit callback uses a fast context, so use `vim.schedule()`.
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
  vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '') .. '\n' .. 'delcommand Run'
end

-- For npm projects (typescript, htmlangular), use the declared script, not `ng serve`.
-- NOTE: Use `npm`, not `npm.cmd`, which is absent from PATH here and raises `E475`.
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

-- For a C, C++ or Rust file outside a project, compile into the cache directory.
-- Run the result. `compiler` supplies argv up to the source file.
-- One shell command runs in the terminal job.
-- Compiler errors and program output share the split, and the editor never waits for the compiler.
-- `&&` prevents a failed compilation from starting an old binary.
--
-- NOTE: Use an unquoted command name because pwsh rejects a quoted name.
-- The `& ` operator runs a quoted path in pwsh but means "background" in `sh`.
M.compiled = function(compiler, args)
  local source = vim.api.nvim_buf_get_name(0)
  if source == '' then
    return nil, 'save the buffer first: there is no file to compile'
  end
  if vim.fn.executable(compiler[1]) ~= 1 then
    return nil, ('`%s` is not on PATH'):format(compiler[1])
  end

  local dir = vim.fs.joinpath(vim.fn.stdpath('cache'), 'run')
  vim.fn.mkdir(dir, 'p')
  local windows = vim.fn.has('win32') == 1
  local out = vim.fs.joinpath(
    dir,
    vim.fn.fnamemodify(source, ':t:r') .. (windows and '.exe' or '')
  )

  local quote = vim.fn.shellescape
  local compile = { compiler[1] }
  for i = 2, #compiler do
    table.insert(compile, quote(compiler[i]))
  end
  vim.list_extend(compile, { quote(source), '-o', quote(out) })

  local run = { (windows and '& ' or '') .. quote(out) }
  for _, arg in ipairs(args) do
    table.insert(run, quote(arg))
  end

  local script = table.concat(compile, ' ') .. ' && ' .. table.concat(run, ' ')
  return require('config.make').shell_argv(script)
end

-- Run `:make`/`:lmake` from the project root because tools print project-relative paths.
-- NOTE: `QuickFixCmdPre` matches the command name (`:h QuickFixCmdPre`); the pair cannot be buffer-local.
-- Use `vim.fn.chdir()`, not `:lcd`, which leaves a window-local directory
-- that `setup_auto_root()` never changes.
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

-- Resolve Maven run commands for 'after/ftplugin/java.lua' and `xml.lua`.
-- `java.lua` keeps the `:make` settings.
local function goal(args, default) return #args > 0 and args or { default } end

M.java_builds = {
  ['pom.xml'] = {
    -- `spring-boot:run` and `exec:java` need different plugins. Select by POM because the other
    -- command reports an error.
    run = function(args, build_file)
      local boot = vim.iter(vim.fn.readfile(build_file)):any(
        function(line) return line:find('spring%-boot%-maven%-plugin') ~= nil end
      )
      local task = boot and 'spring-boot:run' or 'exec:java'
      return vim.list_extend({ 'mvn' }, goal(args, task))
    end,
  },
}

return M
