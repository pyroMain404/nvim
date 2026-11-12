-- ┌──────────────────────┐
-- │ TypeScript behaviour │
-- └──────────────────────┘
--
-- This file extends '$VIMRUNTIME/ftplugin/typescript.vim'. `:make` uses 'compiler/ngc.lua'.
-- `:Run` follows the npm script contract in 'lua/config/run.lua'.
local run = require('config.run')

require('config.ft').build('ngc', { 'package.json' })
run.command(run.npm)
