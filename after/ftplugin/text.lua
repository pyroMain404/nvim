-- ┌────────────────┐
-- │ Text behaviour │
-- └────────────────┘
--
-- On top of '$VIMRUNTIME/ftplugin/text.vim'. A '*.txt' inside a 'doc/' directory
-- is `help` and not touched here.

-- 'list' is on globally ('plugin/10_options.lua'); prose has no whitespace
-- distinction to show.
vim.wo[0][0].list = false

require('config.ft').undo('setlocal list<')
