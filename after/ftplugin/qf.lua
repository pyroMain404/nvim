-- ┌───────────────────────────────────┐
-- │ Quickfix and location list window │
-- └───────────────────────────────────┘
--
-- On top of '$VIMRUNTIME/ftplugin/qf.vim' (`:h quickfix-window`).
-- 'list' is global; its marks hit the indented rendered messages.
vim.wo[0][0].list = false

require('config.ft').undo('setlocal list<')
