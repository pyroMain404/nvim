-- ┌───────────────────────────────────┐
-- │ Quickfix and location list window │
-- └───────────────────────────────────┘
--
-- One filetype answers for both `:copen` and `:lopen` (`:h quickfix-window`),
-- on top of '$VIMRUNTIME/ftplugin/qf.vim'.

-- 'list' is on globally ('plugin/10_options.lua'); its marks would hit the
-- indented messages of a quickfix entry, which is rendered text, not code.
vim.wo[0][0].list = false

require('config.ft').undo('setlocal list<')
