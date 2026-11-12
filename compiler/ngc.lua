-- ┌─────────────────────────────┐
-- │ Angular compiler → quickfix │
-- └─────────────────────────────┘
--
-- With `:compiler ngc`, `:make` runs the Angular compiler because `tsc` skips templates.
-- See `:h write-compiler-plugin`.

vim.g.current_compiler = 'ngc'

-- Use `--noEmit` because bare `ngc` writes JavaScript next to the sources.
vim.cmd([[CompilerSet makeprg=npx\ --no-install\ ngc\ --noEmit\ $*]])

-- NOTE: `ngc` always emits color escapes (@angular/compiler-cli 17.3 / 22.1).
-- `--pretty false` and `NO_COLOR` do not reach it.
-- Handle escapes to prevent an empty quickfix list from falsely indicating a successful build.
--
-- Double backslashes because `CompilerSet` is a `:set` and removes one backslash from each pair.
local color = [[%\\%%(%\\e%[[0-9;]%#m%\\)%#]]

-- Build one diagnostic with color sequences between all fields.
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

vim.cmd('CompilerSet errorformat=' .. diagnostic([[%trror]], 'TS'))
vim.cmd('CompilerSet errorformat+=' .. diagnostic([[%trror]], 'NG'))
vim.cmd('CompilerSet errorformat+=' .. diagnostic([[%tarning]], 'TS'))
vim.cmd('CompilerSet errorformat+=' .. diagnostic([[%tarning]], 'NG'))

vim.cmd([[CompilerSet errorformat+=%-G%.%#]])
