-- ┌─────────────────────────────┐
-- │ Angular compiler → quickfix │
-- └─────────────────────────────┘
--
-- `:compiler ngc` teaches `:make` to run the Angular compiler and put what it
-- says in the quickfix list, so that `]q` and `[q` of 'mini.bracketed' walk the
-- errors. Selected for a buffer in 'after/ftplugin/typescript.lua' and
-- 'after/ftplugin/htmlangular.lua'. See `:h write-compiler-plugin`,
-- `:h :compiler`, `:h errorformat`.
--
-- Why not `:compiler tsc`, which the runtime already ships: `tsc` does not read
-- templates. On a component whose template uses a property the class does not
-- declare, `tsc --noEmit` reports nothing at all, while `ngc` reports the error
-- at the line and column inside the '.html' file. The Angular compiler is the
-- only one that type checks a template, so it is the one worth driving here.

vim.g.current_compiler = 'ngc'

-- `npx` is what finds the Angular compiler of *this* project, which is the one
-- whose version matches its sources; `--no-install` keeps it from silently
-- downloading a different one when the project has none. `$*` is where `:make`
-- inserts its arguments, so `:make -p tsconfig.app.json` still works.
--
-- `--noEmit` is baked in rather than left to the caller because `ngc` with no
-- argument reads the 'tsconfig.json' of the current directory and *writes*
-- JavaScript next to the sources. A build is a deliberate act for a terminal
-- (`ng build`, `<Leader>tt`); what `:make` is for here is the fast check of the
-- inner loop, the way `:make check` is for cargo.
vim.cmd([[CompilerSet makeprg=npx\ --no-install\ ngc\ --noEmit\ $*]])

-- NOTE: `ngc` colours its diagnostics unconditionally. It formats them with
-- TypeScript's `formatDiagnosticsWithColorAndContext`, which emits the escape
-- sequences whatever the output is attached to, and `--pretty false` does not
-- reach that call. Measured under `:make`, where 'shellpipe' hands the output
-- to a pipe and `NO_COLOR` is already 1 in the child environment: the escapes
-- are there all the same. So the format below has to see through them, or
-- `:make` silently leaves the quickfix list empty — which reads exactly like a
-- build that passed. Still true in @angular/compiler-cli 17.3 / 22.1.
--
-- Zero or more colour sequences: `\%(\e\[[0-9;]*m\)*`, written twice over,
-- because two escapings stack here and each one is silent when wrong.
--
-- 'errorformat' first: `%#` is the regular expression star (a bare `*` is a
-- literal asterisk), `%[` a literal bracket, and `%\%%(` opens a NON capturing
-- group — a capturing `%\(` competes with the groups 'errorformat' builds for
-- `%f` and friends and hands back the wrong text.
--
-- Then `:set`, which `CompilerSet` is: it eats one backslash of every pair, so
-- a backslash meant for the pattern is written doubled. That is the same reason
-- '$VIMRUNTIME/compiler/tsc.vim' writes `\\,` for a comma inside its format.
local color = [[%\\%%(%\\e%[[0-9;]%#m%\\)%#]]

-- One diagnostic, as `ngc` writes it. Uncoloured the line reads
--
--   src/app/app.component.html:1:8 - error TS2339: Property 'titleXYZ' does...
--
-- and the sequences sit between every one of these fields. The space before
-- the code belongs after them, not before: the compiler closes the severity,
-- opens the colour of the code, and only then writes ` TS2339: `.
local function diagnostic(severity, code)
  return color
    .. [[%f]]
    .. color
    .. [[:]]
    .. color
    .. [[%l]]
    .. color
    .. [[:]]
    .. color
    .. [[%c]]
    .. color
    .. [[\ -\ ]]
    .. color
    .. severity
    .. color
    .. [[\ ]]
    .. code
    .. [[%n:\ ]]
    .. color
    .. [[%m]]
end

-- `TS` codes come from the TypeScript checker, `NG` ones from the Angular
-- compiler itself (`NG8001`, an element no module declares). Both appear as
-- errors and as warnings.
vim.cmd('CompilerSet errorformat=' .. diagnostic([[%trror]], 'TS'))
vim.cmd('CompilerSet errorformat+=' .. diagnostic([[%trror]], 'NG'))
vim.cmd('CompilerSet errorformat+=' .. diagnostic([[%tarning]], 'TS'))
vim.cmd('CompilerSet errorformat+=' .. diagnostic([[%tarning]], 'NG'))

-- Everything else `ngc` prints is the excerpt of the offending source and, for
-- a template error, the place in the '.ts' file that pulled the template in.
-- Keeping those would fill the list with entries that jump nowhere.
vim.cmd([[CompilerSet errorformat+=%-G%.%#]])
