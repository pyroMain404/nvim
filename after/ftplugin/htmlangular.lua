-- ┌────────────────────────────┐
-- │ Angular template behaviour │
-- └────────────────────────────┘
--
-- On top of '$VIMRUNTIME/ftplugin/htmlangular.vim'. `:make` goes through
-- 'compiler/ngc.lua'; `:Run` is the npm script contract of 'lua/config/run.lua'.
local ft = require('config.ft')
local run = require('config.run')

ft.build('ngc', { 'package.json' })
ft.ts_fold()
run.command(run.npm)
