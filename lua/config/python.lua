-- ┌────────────────────┐
-- │ Python interpreter │
-- └────────────────────┘
--
-- This module selects the same Python interpreter for the server and `:Run`.
-- 'after/lsp/basedpyright.lua', 'after/ftplugin/python.lua' and
-- 'lua/config/health.lua' load it by name.
local M = {}

-- For `start` (a file or directory), use the nearest '.venv' or 'venv' at or above it.
-- Otherwise, use `python` on PATH, or return nil if none exists.
-- One `find` checks both names, so the nearest wins.
-- `uv venv` makes '.venv'; `python -m venv venv` makes 'venv'.
-- The code does not read `VIRTUAL_ENV`: an activated shell already puts that `python` first on
-- PATH.
function M.interpreter(start)
  local venv = vim.fs.find({ '.venv', 'venv' }, {
    upward = true,
    path = start,
    type = 'directory',
  })[1]
  if venv then
    -- Check Windows and POSIX layouts. Continue to PATH if the venv has no interpreter.
    for _, exe in ipairs({ 'Scripts/python.exe', 'bin/python' }) do
      local python = vim.fs.joinpath(venv, exe)
      if vim.uv.fs_stat(python) then return python end
    end
  end
  local global = vim.fn.exepath('python')
  return global ~= '' and global or nil
end

return M
