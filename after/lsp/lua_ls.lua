-- ┌────────┐
-- │ lua_ls │
-- └────────┘
--
-- Install: `mise use -g lua-language-server@latest`. Tuned for editing this config.

-- Read for definitions, never reported on; the whole 'runtimepath' is slow and trips the server.
local library = {
  vim.env.VIMRUNTIME,
  '${3rd}/luv/library',
}
vim.list_extend(library, vim.api.nvim_get_runtime_file('lua/mini', true))

-- NOTE: `$HOME` has a '.git' here, so a loose '.lua' would resolve to `$HOME` and scan
-- the whole profile; `root_dir` excludes it (`os_homedir()` uses backslashes).
local home = vim.fs.normalize(vim.uv.os_homedir())
return {
  root_dir = function(bufnr, on_dir)
    local root_markers =
      vim.iter(vim.lsp.config.lua_ls.root_markers):flatten():totable()
    local root = vim.fs.root(bufnr, root_markers)
    if root ~= nil and root ~= home then on_dir(root) end
  end,
  on_attach = function(client)
    client.server_capabilities.completionProvider.triggerCharacters =
      { '.', ':', '#', '(' }
  end,
  settings = {
    Lua = {
      runtime = {
        version = 'LuaJIT',
        path = { 'lua/?.lua', 'lua/?/init.lua' },
      },
      workspace = {
        ignoreSubmodules = true,
        library = library,
        checkThirdParty = false,
      },
      diagnostics = { globals = { 'Config' } },
      -- NOTE: the lens of 'nvim-lspconfig' are reference counters with an empty
      -- `command`, so running one fails with "does not support command ``";
      -- `<Leader>lR` goes to the references.
      codeLens = { enable = false },
    },
  },
}
