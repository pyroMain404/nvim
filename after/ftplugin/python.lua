-- ┌──────────────────┐
-- │ Python behaviour │
-- └──────────────────┘
--
-- This file adds `:Run` to '$VIMRUNTIME/ftplugin/python.vim'.
-- The runtime file supplies indentation, `gf` on imports, `keywordprg`, and `:compiler pytest`.

-- `:Run` follows the contract in 'lua/config/run.lua': `<interpreter> <file> <args>`.
-- Each call resolves the interpreter through 'lua/config/python.lua', so a new venv works
-- immediately in the current session.
-- A script belongs to no project, so its working directory is the file's directory.
require('config.run').command(function(args)
  local file = vim.api.nvim_buf_get_name(0)
  local python = require('config.python').interpreter(file)
  if python == nil then
    return nil,
      "no Python interpreter: no '.venv' or 'venv' above this file and no `python` on PATH"
  end
  return vim.list_extend({ python, file }, args)
end)
