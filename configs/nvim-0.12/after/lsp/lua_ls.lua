-- ┌────────┐
-- │ lua_ls │
-- └────────┘
--
-- This file contains configuration of the Lua language server.
-- Source: https://github.com/LuaLS/lua-language-server
-- Install: `mise use -g lua-language-server@latest`.
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
--
-- What is inherited from 'nvim-lspconfig' and not repeated here: `cmd`,
-- `filetypes`, the `root_markers` that make '.luarc.json', '.stylua.toml' or
-- '.git' the workspace root, and `settings.Lua` with code lens and inlay hints
-- already enabled. Unlike the Rust one, that file defines no function, so the
-- `on_attach` below adds behavior instead of deleting some: read it with
-- `:=vim.lsp.config['lua_ls']` before adding anything of that kind here.
--
-- The settings are tuned for editing this config, which is the Lua written here:
-- Neovim's own API, 'mini.nvim' and the `Config` helpers of 'init.lua'.
-- Their structure comes from LuaLS, not from Neovim: https://luals.github.io/wiki/settings/

-- Directories whose Lua is read for definitions and completion, but never
-- reported on. Only what is actually used is listed: pulling in the whole
-- 'runtimepath' is much slower and makes the server stumble over the config
-- being edited (see the comment in 'nvim-lspconfig' own 'lsp/lua_ls.lua').
local library = {
  -- Neovim's API: what makes `vim.api`, `vim.fn` and `vim.o` known
  vim.env.VIMRUNTIME,
  -- `vim.uv` is `luv`, whose annotations LuaLS ships as a third party library
  -- and resolves through this placeholder (`:h vim.uv`)
  '${3rd}/luv/library',
}
-- 'mini.nvim' is where the `MiniXxx` globals and every `setup()` table of
-- 'plugin/30_mini.lua' are defined
vim.list_extend(library, vim.api.nvim_get_runtime_file('lua/mini', true))

-- HACK: `root_markers` (inherited from 'nvim-lspconfig', see the file header)
-- includes `.git` as its lowest-priority tier, and this machine's user
-- profile directory (`$HOME`) happens to have one - unrelated to any Lua
-- project. `vim.fs.root()` then resolves ANY loose '.lua' file opened
-- anywhere under the profile (a scratch script, an editor test file) to
-- `$HOME` itself, and `lua_ls` starts a workspace scan of the whole profile
-- (100000+ files, growing notification) instead of running in single-file
-- mode. `root_dir` overrides `root_markers` (`:h lsp-root_dir()`), so the
-- same tiers are repeated here with that one directory excluded; not
-- calling `on_dir()` leaves `lua_ls` off for that buffer entirely, which is
-- the same "outside any workspace" outcome vim.fs.root() would have given if
-- $HOME had no '.git' at all.
-- `vim.fs.normalize()` because `os_homedir()` answers with backslashes on
-- Windows while `vim.fs.root()` always answers with forward slashes.
local home = vim.fs.normalize(vim.uv.os_homedir())
return {
  root_dir = function(bufnr, on_dir)
    local root = vim.fs.root(bufnr, {
      { '.emmyrc.json', '.luarc.json', '.luarc.jsonc' },
      { '.luacheckrc', '.stylua.toml', 'stylua.toml', 'selene.toml', 'selene.yml' },
      { '.git' },
    })
    if root ~= nil and root ~= home then on_dir(root) end
  end,
  on_attach = function(client)
    -- Reduce very long list of triggers for better 'mini.completion' experience
    client.server_capabilities.completionProvider.triggerCharacters =
      { '.', ':', '#', '(' }
  end,
  settings = {
    Lua = {
      runtime = {
        -- The Lua built into Neovim
        version = 'LuaJIT',
        -- How Neovim itself resolves `require('config.health')`, so that `gd`
        -- on a `require()` lands in the same file the editor would load
        -- (`:h lua-module-load`). The default of LuaLS is the `package.path` of
        -- a standalone interpreter, which points nowhere here.
        path = { 'lua/?.lua', 'lua/?/init.lua' },
      },
      workspace = {
        -- Don't analyze code from submodules
        ignoreSubmodules = true,
        library = library,
        -- Without this the server asks, in a prompt that blocks until answered,
        -- whether to set up the environment for each third party library it
        -- recognizes. The `library` above already answers that question.
        checkThirdParty = false,
      },
      -- `Config` is defined in 'init.lua' of this config and used by every
      -- 'plugin/' file, so it is a global on purpose, not a typo to report
      diagnostics = { globals = { 'Config' } },
      -- NOTE: the code lens 'nvim-lspconfig' enables for this server are a
      -- reference counter and nothing else: resolved, they carry
      -- `title = "N references"` and an empty `command`. Neovim resolves the
      -- lens under the cursor and then runs it, so `<Leader>ll` answers
      -- "does not support command ``" with an empty name. The count in virtual
      -- text is what they are for; `<Leader>lR` is what goes to the references.
      -- They are disabled here because the empty command is not useful.
      codeLens = { enable = false },
    },
  },
}
