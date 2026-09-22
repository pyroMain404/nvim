-- ┌────────────────┐
-- │ Lua behaviour  │
-- └────────────────┘
--
-- This file contains behavior specific to Lua buffers, added on top of what
-- '$VIMRUNTIME/ftplugin/lua.vim' and '$VIMRUNTIME/ftplugin/lua.lua' already do:
-- `commentstring`, `gf` on a `require()` through `includeexpr` and
-- `suffixesadd`, tree-sitter highlighting and folding, and the `omnifunc` that
-- completes Neovim's API without a server. None of that is repeated here.
-- `:verbose setlocal commentstring? includeexpr?` says who set what.
--
-- 'textwidth' is the one thing missing, and it is not a style preference: it is
-- the same 85 columns as `column_width` in '.stylua.toml', which is what
-- `stylua --check` enforces before a commit. Setting it here makes 'colorcolumn'
-- (set to '+1' in 'plugin/10_options.lua', hence relative to this) draw the
-- limit while typing, instead of leaving it to be discovered by a failing check.
--
-- What it does not do is wrap anything while typing: the runtime ftplugin removes
-- `t` from 'formatoptions', and the `FileType` autocommand in
-- 'plugin/10_options.lua' removes `c` from every buffer, so neither code nor
-- comments are broken automatically. The 85 columns feed 'colorcolumn' and an
-- explicit `gq`/`gw`, and nothing else.
vim.bo.textwidth = 85

-- Undo what this file sets when the filetype changes away from `lua`
-- (`:h b:undo_ftplugin`), appending to what the runtime ftplugin already
-- registered rather than overwriting it.
vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '') .. '\n' .. 'setlocal textwidth<'
