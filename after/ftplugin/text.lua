-- ┌────────────────┐
-- │ Text behaviour │
-- └────────────────┘
--
-- This file extends '$VIMRUNTIME/ftplugin/text.vim'; prose has no whitespace to show.
vim.wo[0][0].list = false

require('config.ft').undo('setlocal list<')
