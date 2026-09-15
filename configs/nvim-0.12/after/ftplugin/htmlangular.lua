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

-- `:make` prints paths relative to the Angular project; same remedy the
-- TypeScript ftplugin needs next to it, through 'lua/config/run.lua''s
-- `make_root()`.
require('config.run').make_root({ 'package.json' })

-- Fold by structure. The `angular` parser is in `languages` in
-- 'plugin/40_plugins.lua', so the tree exists; without a `foldexpr` a template
-- folds by indentation, which in nested markup groups by depth of nesting
-- rather than by element (`:h vim.treesitter.foldexpr()`). The second index is
-- what keeps the two inside this buffer: plain `vim.wo` writes like `:set` and
-- moves the global value as well, so every window opened after the first
-- template would fold by this expression (`:h vim.wo`).
vim.wo[0][0].foldmethod = 'expr'
vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'

-- Running the project, under the contract of 'lua/config/run.lua': `:Run` alone
-- starts the script the 'package.json' declares (`start`, then `dev`, then
-- `serve`), and `:Run <task>` is `npm run <task>` - which is how a project whose
-- start is not `ng serve` says so. The resolver is shared with
-- 'after/ftplugin/htmlangular.lua', because a component is two files and one
-- project; why it goes through npm rather than straight to `ng serve` is
-- explained there.
local run = require('config.run')
run.command(run.npm)

-- Undo what this file sets when the filetype changes away from `htmlangular`
-- (`:h b:undo_ftplugin`). `:Run` undoes itself, registered inside
-- 'lua/config/run.lua''s `M.command()`.
vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n'
  .. table.concat({
    'setlocal makeprg< errorformat< foldmethod< foldexpr<',
    'unlet! b:current_compiler',
  }, ' | ')
