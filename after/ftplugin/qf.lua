-- ┌───────────────────────────────────┐
-- │ Quickfix and location list window │
-- └───────────────────────────────────┘
--
-- This file extends '$VIMRUNTIME/ftplugin/qf.vim' (`:h quickfix-window`).
-- 'list' is global; its whitespace marks show on the indented rendered messages.
vim.wo[0][0].list = false

require('config.ft').undo('setlocal list<')
