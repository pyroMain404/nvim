-- ┌────────────────────┐
-- │ Python interpreter │
-- └────────────────────┘
--
-- Which interpreter a Python file uses, so the server and `:Run` agree. Required
-- by name from 'after/lsp/basedpyright.lua', 'after/ftplugin/python.lua' and
-- 'lua/config/health.lua'.
local M = {}

-- The interpreter for `start` (a file or directory): the one in the nearest
-- '.venv' or 'venv' at or above it, else the `python` on PATH, else nil. One
-- `find` for both names, so the nearest wins (`uv venv` makes '.venv',
-- `python -m venv venv` the other). `VIRTUAL_ENV` is not read: an activated shell
-- already puts that `python` first on PATH.
function M.interpreter(start)
  local venv = vim.fs.find({ '.venv', 'venv' }, {
    upward = true,
    path = start,
    type = 'directory',
  })[1]
  if venv then
    -- Windows and POSIX layouts; a venv without an interpreter falls through
    for _, exe in ipairs({ 'Scripts/python.exe', 'bin/python' }) do
      local python = vim.fs.joinpath(venv, exe)
      if vim.uv.fs_stat(python) then return python end
    end
  end
  local global = vim.fn.exepath('python')
  return global ~= '' and global or nil
end

return M
