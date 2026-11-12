-- ┌───────────────────┐
-- │ Filetype behavior │
-- └───────────────────┘
--
-- Use this template for 'after/ftplugin/<ft>.lua'.
-- Copy it with the filetype name.
-- Keep only behavior that the runtime does not supply.
--
-- See 'after/ftplugin/markdown.lua' for an example in this config.
-- Neovim loads this file on each 'filetype' change to the target value, once per buffer.
-- Keep it fast: do not scan the filesystem or run external commands.
-- Its 'after/' location lets it correct the runtime ftplugin of the same name (`:h ftplugin-overrule`).
--
-- Before you change an option, check which file sets it:
--   :verbose setlocal shiftwidth? commentstring? makeprg?
-- If a file under $VIMRUNTIME supplies the value, no change is necessary.
--
-- Do not use the 'init.lua' loading helpers (`now`, `now_if_args`, `later`) here.
-- They control startup order.
-- This file already loads only when a buffer with this filetype appears.

-- Use `vim.bo` for buffer-local options and `vim.wo` for window-local options.
-- These names show the target scope, unlike `:setlocal`.
vim.bo.shiftwidth = 4
vim.bo.softtabstop = 4
vim.bo.textwidth = 100

-- Use structure-based folds after the tree-sitter parser is installed (`:h vim.treesitter.foldexpr()`).
-- Use `vim.lsp.foldexpr` instead if a server gives better ranges (`:h vim.lsp.foldexpr()`).
vim.wo.foldmethod = 'expr'
vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'

-- Select the compiler for this filetype so `:make` fills the quickfix list.
-- `:compiler` has no Lua API and sets its options through a temporary command.
-- Thus, use `vim.cmd()` to call it.
-- vim.cmd('compiler mytool')

-- Use buffer-local MINI configuration (`:h mini.nvim-buffer-local-config`).
-- Tree-sitter textobjects reuse captures from 'nvim-treesitter-textobjects'.
-- Usually, only the capture names are necessary (`:h MiniAi.gen_spec.treesitter()`).
-- vim.b.miniai_config = {
--   custom_textobjects = {
--     F = require('mini.ai').gen_spec.treesitter({
--       a = '@function.outer',
--       i = '@function.inner',
--     }),
--   },
-- }

-- 'mini.pairs' creates mappings in `setup()`, so `vim.b.minipairs_config` has no effect.
-- Use `:h MiniPairs.map_buf()` or `:h MiniPairs.unmap_buf()` to change a pair for this buffer.
-- This is necessary when a pairing character has another meaning in the language.
-- MiniPairs.unmap_buf(0, 'i', "'", "''")

-- Use a buffer-local command instead of a global mapping for behavior specific to this filetype.
-- It uses no key and disappears with the buffer.
-- vim.api.nvim_buf_create_user_command(0, 'MylangDocs', function()
--   vim.system({ 'mylang', 'doc', '--open' })
-- end, { desc = 'Open language documentation' })

-- `:make` runs a finite task and fills the quickfix list.
-- Use a terminal for a process that keeps running and writing output.
-- 'lua/config/run.lua' defines the command, its name, and its window.
-- See `references/capabilities.md` "Eseguire il programma, e le viste che non sono file".
-- Put only the language-specific resolver here.
-- The resolver selects the command and reads its default from the project instead of fixing one here.
-- require('config.run').command(function(args)
--   return vim.list_extend({ 'mylang', 'run' }, args)
-- end)
--
-- For languages with several build tools, use a resolver table with a `run` for each manifest.
-- Give each entry an optional `compiler`; a build tool does not always supply both features.
-- A `:compiler` missing from the runtime raises `E666` when this file loads.
-- See 'after/ftplugin/java.lua' for an example.

-- If this file sets many options and defines commands, define how Neovim must undo them
-- (`:h undo_ftplugin`).
-- This prevents mixed filetype settings after a later `:setfiletype`.
-- This is unnecessary for two options, but useful for ten.
-- vim.b.undo_ftplugin = 'setlocal shiftwidth< softtabstop< textwidth<'
