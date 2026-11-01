-- ┌──────────────────────┐
-- │ TypeScript behaviour │
-- └──────────────────────┘
--
-- On top of '$VIMRUNTIME/ftplugin/typescript.vim'. `:make` goes through
-- 'compiler/ngc.lua'; `:Run` is the npm script contract of 'lua/config/run.lua'.
local run = require('config.run')

require('config.ft').build('ngc', { 'package.json' })
run.command(run.npm)
