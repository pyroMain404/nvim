-- ┌──────────────┐
-- │ basedpyright │
-- └──────────────┘
--
-- Install with `mise use -g npm:basedpyright@latest`.
-- `before_init` supplies the interpreter from 'lua/config/python.lua', which `:Run` also uses.
-- This makes imports resolve in the nearest venv.

-- Do not add `on_attach` here.
-- `vim.tbl_deep_extend('force')` merges files in 'lsp/' and replaces functions.
-- This would delete `:LspPyrightOrganizeImports` and `:LspPyrightSetPythonPath` from
-- 'nvim-lspconfig'.
return {
  before_init = function(_, config)
    -- `root_dir` is nil for a single script; the buffer that started the client is current.
    local python = require('config.python').interpreter(
      config.root_dir or vim.api.nvim_buf_get_name(0)
    )
    if python == nil then return end
    -- NOTE: Change `config.settings` directly because the client keeps its reference.
    -- A new table never reaches the server.
    -- The interpreter stays fixed after startup. A later venv needs `:lsp restart basedpyright`.
    config.settings.python =
      vim.tbl_extend('force', config.settings.python or {}, { pythonPath = python })
  end,
}
