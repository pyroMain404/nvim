-- ┌──────────────┐
-- │ basedpyright │
-- └──────────────┘
--
-- Install: `mise use -g npm:basedpyright@latest`. Only `before_init` here: it
-- gives the server the interpreter of 'lua/config/python.lua', the one `:Run`
-- uses, so imports resolve in the nearest venv. Never write `on_attach`: files in
-- 'lsp/' are merged with `vim.tbl_deep_extend('force')`, which replaces
-- functions, and it would delete 'nvim-lspconfig''s `:LspPyrightOrganizeImports`
-- and `:LspPyrightSetPythonPath`.
return {
  before_init = function(_, config)
    -- `root_dir` is nil for a lone script; the buffer that started the client is current
    local python = require('config.python').interpreter(
      config.root_dir or vim.api.nvim_buf_get_name(0)
    )
    if python == nil then return end
    -- NOTE: the client keeps `config.settings` by reference, so mutate it; a new
    -- table never reaches the server. The interpreter is fixed at start: a venv
    -- created later needs `:lsp restart basedpyright`.
    config.settings.python =
      vim.tbl_extend('force', config.settings.python or {}, { pythonPath = python })
  end,
}
