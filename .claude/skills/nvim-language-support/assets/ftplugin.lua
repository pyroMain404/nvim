-- ┌───────────────────┐
-- │ Filetype behavior │
-- └───────────────────┘
--
-- Skeleton for 'after/ftplugin/<ft>.lua'. Copy, rename after the filetype, and
-- keep only what the runtime does not already do. 'after/ftplugin/markdown.lua' is
-- the worked example already in the config.
--
-- This file is sourced on every 'filetype' change to the target value, so it runs
-- once per buffer and must stay cheap: no filesystem scans, no external commands.
-- Because it is under 'after/', it takes effect after the runtime ftplugin of the
-- same name and can correct it (`:h ftplugin-overrule`).
--
-- Before writing a line here, ask who sets the value already:
--   :verbose setlocal shiftwidth? commentstring? makeprg?
-- If the answer names a file under $VIMRUNTIME, the work is done.
--
-- The loading helpers of 'init.lua' (`now`, `now_if_args`, `later`) have no place
-- here: they order what happens during startup, while this file is already lazy by
-- construction — it runs when a buffer of this filetype appears, and never before.

-- Buffer-local options: `vim.bo`. Window-local ones: `vim.wo`. Both say what they
-- act on, which `:setlocal` deliberately does not.
vim.bo.shiftwidth = 4
vim.bo.softtabstop = 4
vim.bo.textwidth = 100

-- Fold by structure once the tree-sitter parser is installed
-- (`:h vim.treesitter.foldexpr()`). With a server that reports better ranges, use
-- `vim.lsp.foldexpr` instead (`:h vim.lsp.foldexpr()`).
vim.wo.foldmethod = 'expr'
vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'

-- Pick the compiler for this filetype, so that `:make` fills the quickfix list.
-- `:compiler` has no Lua API and defines its options through a temporary command,
-- so `vim.cmd()` is the only way to call it — one of the few places where it is
-- the right tool rather than a shortcut.
-- vim.cmd('compiler mytool')

-- Buffer-local MINI configuration (`:h mini.nvim-buffer-local-config`). Tree-sitter
-- textobjects reuse the captures 'nvim-treesitter-textobjects' already ships, so
-- naming them is usually enough (`:h MiniAi.gen_spec.treesitter()`):
-- vim.b.miniai_config = {
--   custom_textobjects = {
--     F = require('mini.ai').gen_spec.treesitter({
--       a = '@function.outer',
--       i = '@function.inner',
--     }),
--   },
-- }

-- 'mini.pairs' is the exception: `vim.b.minipairs_config` has no effect, because
-- the module creates its mappings in `setup()`. Adjust a pair for this buffer with
-- `:h MiniPairs.map_buf()` and `:h MiniPairs.unmap_buf()` instead — needed where a
-- pairing character means something else in the language.
-- MiniPairs.unmap_buf(0, 'i', "'", "''")

-- A command is better than a global mapping for something that only makes sense in
-- this filetype: it costs no key, and it disappears with the buffer.
-- vim.api.nvim_buf_create_user_command(0, 'MylangDocs', function()
--   vim.system({ 'mylang', 'doc', '--open' })
-- end, { desc = 'Open language documentation' })

-- When this file sets many options and defines commands, teach Neovim how to undo
-- them, so that a later `:setfiletype` does not leave a hybrid buffer
-- (`:h undo_ftplugin`). For two options it is overhead; for ten it is not.
-- vim.b.undo_ftplugin = 'setlocal shiftwidth< softtabstop< textwidth<'
