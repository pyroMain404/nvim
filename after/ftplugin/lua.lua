-- ┌────────────────┐
-- │ Lua behaviour  │
-- └────────────────┘
--
-- On top of '$VIMRUNTIME/ftplugin/lua.vim' and '$VIMRUNTIME/ftplugin/lua.lua'.
-- 'textwidth' matches `column_width` in '.stylua.toml', so 'colorcolumn'
-- (relative, in 'plugin/10_options.lua') draws the limit `stylua --check` enforces.
vim.bo.textwidth = 85

require('config.ft').undo('setlocal textwidth<')
