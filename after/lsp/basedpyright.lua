-- ┌───────────────┐
-- │ basedpyright  │
-- └───────────────┘
--
-- This file contains configuration of the Python language server.
-- Source: https://github.com/DetachHead/basedpyright
-- Install: `mise use -g npm:basedpyright@latest`.
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
--
-- The only thing added to 'nvim-lspconfig' is the interpreter: the server
-- resolves imports through it, so a script that imports a package installed in
-- the nearest '.venv' or 'venv' must be analyzed with that venv's `python`
-- (see 'lua/config/python.lua'), the same one `:Run` uses.
--
-- NOTE: `before_init` is safe to define because the 'nvim-lspconfig' default
-- has none, but `on_attach` must never be written here: files in 'lsp/' are
-- merged with `vim.tbl_deep_extend('force')`, which replaces functions, and it
-- would delete `:LspPyrightOrganizeImports` and `:LspPyrightSetPythonPath`.
return {
  before_init = function(_, config)
    -- `root_dir` is nil for a lone script without markers; the current buffer
    -- is then the one whose `FileType` started the client.
    local python = require('config.python').interpreter(
      config.root_dir or vim.api.nvim_buf_get_name(0)
    )
    -- With no interpreter the server keeps its own default (the `python` on
    -- its PATH).
    if python == nil then return end
    -- NOTE: `config.settings` is stored by reference by the client and read by
    -- the `workspace/configuration` handler, so it has to be mutated in place;
    -- assigning a new table to `config.settings` would never reach the server.
    -- The interpreter is fixed at client start: a venv created afterwards needs
    -- `:lsp restart basedpyright`.
    config.settings.python =
      vim.tbl_extend('force', config.settings.python or {}, { pythonPath = python })
  end,
}
