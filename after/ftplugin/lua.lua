-- ┌────────────────┐
-- │ Lua behaviour  │
-- └────────────────┘
--
-- This file extends '$VIMRUNTIME/ftplugin/lua.vim' and '$VIMRUNTIME/ftplugin/lua.lua'.
-- 'textwidth' matches `column_width` in '.stylua.toml'.
-- The relative 'colorcolumn' in 'plugin/10_options.lua' shows the `stylua --check` limit.
vim.bo.textwidth = 85

require('config.ft').undo('setlocal textwidth<')
