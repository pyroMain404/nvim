-- ┌────────────────────────────┐
-- │ Angular template behaviour │
-- └────────────────────────────┘
--
-- '$VIMRUNTIME/ftplugin/htmlangular.vim' does one thing: it sources
-- 'ftplugin/html.vim'. So a template already has the HTML `commentstring`,
-- `matchpairs` and `path`, and this file only adds what is Angular's.
--
-- An error in a template is reported by the compiler at a line and column
-- inside this file, not inside the component, so the same `:make` is worth
-- having here as in the TypeScript buffer next to it (see 'compiler/ngc.lua').
vim.cmd('compiler ngc')

-- Fold by structure. The `angular` parser is in `languages` in
-- 'plugin/40_plugins.lua', so the tree exists; without a `foldexpr` a template
-- folds by indentation, which in nested markup groups by depth of nesting
-- rather than by element (`:h vim.treesitter.foldexpr()`).
vim.wo.foldmethod = 'expr'
vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
