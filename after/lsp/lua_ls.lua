-- ┌────────┐
-- │ lua_ls │
-- └────────┘
--
-- Install with `mise use -g lua-language-server@latest`.
-- These settings support edits to this config.

-- The server reads these files as a library and reports no diagnostics for them.
-- The full 'runtimepath' is slow and makes the server fail.
local library = {
  vim.env.VIMRUNTIME,
  '${3rd}/luv/library',
}
vim.list_extend(library, vim.api.nvim_get_runtime_file('lua/mini', true))

-- NOTE: `$HOME` contains '.git', so a separate '.lua' would use `$HOME` as its root and scan the
-- full profile.
-- `root_dir` excludes it; `os_homedir()` uses backslashes.
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
      -- NOTE: Code lenses from 'nvim-lspconfig' count references but have an empty `command`.
      -- Thus, execution fails with "does not support command ``".
      -- `<Leader>lR` goes to the references.
      codeLens = { enable = false },
    },
  },
}
