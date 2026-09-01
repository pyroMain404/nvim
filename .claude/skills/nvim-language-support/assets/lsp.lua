-- ┌───────────────────────────────┐
-- │ Language server configuration │
-- └───────────────────────────────┘
--
-- Skeleton for 'after/lsp/<server>.lua'. Copy, rename after the server as
-- 'nvim-lspconfig' names it, and add that same name to the `vim.lsp.enable({ ... })`
-- call under `-- Language servers ===` in 'plugin/40_plugins.lua'.
-- 'after/lsp/lua_ls.lua' is the worked example already in the config.
--
-- Source: <upstream URL of the server>
-- Install: <exact command, so that the health check and this file agree>
--
-- The file returns a table read by `:h vim.lsp.config()` and `:h vim.lsp.enable()`.
-- See `:h vim.lsp.Config` for every field.
--
-- Set only what differs from what 'nvim-lspconfig' already provides. To see what is
-- inherited before writing anything:
--   :=vim.lsp.config['<server>']

return {
  -- `cmd`, `filetypes` and `root_markers` usually come from 'nvim-lspconfig'
  -- (`:h lsp-root_markers`). Override them only for a real reason, and say the
  -- reason: naming an absolute `cmd`, for instance, bypasses the version manager
  -- proxy and pins one toolchain for every project.

  -- Structure defined by the server, not by Neovim. Worth stating in a comment so
  -- that the reader does not go looking for these names in `:h`.
  settings = {},

  on_attach = function(client, buf_id)
    -- Only what makes sense with a server attached. Everything unconditional
    -- belongs in 'after/ftplugin/' instead.

    -- Servers that declare many trigger characters make the 'mini.completion'
    -- popup appear mid-word; trimming the list is the usual fix.
    -- client.server_capabilities.completionProvider.triggerCharacters =
    --   { '.', ':' }

    -- Inferred types and parameter names as virtual text. Useful and intrusive in
    -- equal measure, and it shifts the text: propose it, do not decide it.
    -- vim.lsp.inlay_hint.enable(true, { bufnr = buf_id })

    -- Buffer-local mappings for what only this server can do.
  end,
}
