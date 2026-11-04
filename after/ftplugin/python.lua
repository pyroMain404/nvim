-- ┌──────────────────┐
-- │ Python behaviour │
-- └──────────────────┘
--
-- On top of '$VIMRUNTIME/ftplugin/python.vim' (indent, `gf` on an import,
-- `keywordprg`, `:compiler pytest`): `:Run`.

-- `:Run` under the contract of 'lua/config/run.lua': `<interpreter> <file> <args>`
-- with the interpreter of 'lua/config/python.lua', resolved at every call so a
-- venv created mid-session is used at once. A script belongs to no project, so
-- the working directory is the file's.
require('config.run').command(function(args)
  local file = vim.api.nvim_buf_get_name(0)
  local python = require('config.python').interpreter(file)
  if python == nil then
    return nil,
      "no Python interpreter: no '.venv' or 'venv' above this file and no `python` on PATH"
  end
  return vim.list_extend({ python, file }, args)
end)
