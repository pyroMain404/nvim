-- ┌───────────────────────────────────┐
-- │ Quickfix and location list window │
-- └───────────────────────────────────┘
--
-- This file extends '$VIMRUNTIME/ftplugin/qf.vim' (`:h quickfix-window`).
-- 'list' is global; its marks interfere with the indentation of rendered messages.
vim.wo[0][0].list = false

require('config.ft').undo('setlocal list<')
