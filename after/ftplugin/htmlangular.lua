-- ┌────────────────────────────┐
-- │ Angular template behaviour │
-- └────────────────────────────┘
--
-- This file extends '$VIMRUNTIME/ftplugin/htmlangular.vim'. `:make` uses 'compiler/ngc.lua'.
-- `:Run` follows the npm script contract in 'lua/config/run.lua'.
local ft = require('config.ft')
local run = require('config.run')

ft.build('ngc', { 'package.json' })
ft.ts_fold()
run.command(run.npm)
