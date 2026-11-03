-- ┌────────────────────┐
-- │ Python interpreter │
-- └────────────────────┘
--
-- Which interpreter a Python file uses, so that the language server's analysis
-- and `:Run` always agree. Required by name from 'after/lsp/basedpyright.lua',
-- 'after/ftplugin/python.lua' and 'lua/config/health.lua'.
local M = {}

-- Return the interpreter for `start` (a file or directory path): the one inside
-- the nearest '.venv' or 'venv' directory at or above it, else the `python`
-- on PATH, else nil.
--
-- Both names go through one `find` so the *nearest* wins whatever its name:
-- `uv venv` makes '.venv', `python -m venv venv` the other. `VIRTUAL_ENV` is
-- deliberately not read: an activated shell already puts that environment's
-- `python` first on PATH, which `exepath()` returns.
function M.interpreter(start)
  local venv = vim.fs.find({ '.venv', 'venv' }, {
    upward = true,
    path = start,
    type = 'directory',
  })[1]
  if venv then
    -- 'Scripts/python.exe' is the Windows layout, 'bin/python' the POSIX one;
    -- checking both costs one `stat` and needs no platform branch. A venv
    -- without an interpreter (broken, half-created) falls through to the
    -- global one instead of returning a path that does not exist.
    for _, exe in ipairs({ 'Scripts/python.exe', 'bin/python' }) do
      local python = vim.fs.joinpath(venv, exe)
      if vim.uv.fs_stat(python) then return python end
    end
  end
  local global = vim.fn.exepath('python')
  return global ~= '' and global or nil
end

return M
