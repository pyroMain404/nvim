-- ┌──────────────────────┐
-- │ TypeScript behaviour │
-- └──────────────────────┘
--
-- On top of '$VIMRUNTIME/ftplugin/typescript.vim', which already sets
-- `commentstring=// %s` and a `suffixesadd` that lets `gf` follow an import
-- without its extension. `:verbose setlocal commentstring? suffixesadd?` says
-- who set what; nothing of that is repeated here.
--
-- What the runtime leaves empty is `makeprg`: TypeScript has no compiler plugin
-- selected by the ftplugin, and the `tsc` one it ships does not read Angular
-- templates. 'compiler/ngc.lua' explains the choice; here it is only selected.
-- `:compiler` has no Lua API — it defines its options through a command it
-- creates and deletes — so `vim.cmd()` is the call, not a shortcut.
vim.cmd('compiler ngc')

-- `:make` (compiled through `compiler ngc`) prints paths relative to the
-- Angular project, while Neovim resolves quickfix `%f` entries against its
-- own directory - which 'setup_auto_root()' in 'plugin/30_mini.lua' keeps at
-- the repository root, not necessarily the project's own directory in
-- a monorepo. Same remedy the GDScript ftplugin needed first, now shared
-- through 'lua/config/run.lua''s `make_root()`.
require('config.run').make_root({ 'package.json' })

-- Running the project, under the contract of 'lua/config/run.lua': `:Run` alone
-- starts the script the 'package.json' declares (`start`, then `dev`, then
-- `serve`), and `:Run <task>` is `npm run <task>` - which is how a project whose
-- start is not `ng serve` says so. The resolver is shared with
-- 'after/ftplugin/htmlangular.lua', because a component is two files and one
-- project; why it goes through npm rather than straight to `ng serve` is
-- explained there.
local run = require('config.run')
run.command(run.npm)
