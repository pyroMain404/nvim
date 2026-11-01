-- ┌─────────────────────────────┐
-- │ Angular compiler → quickfix │
-- └─────────────────────────────┘
--
-- `:compiler ngc`: `:make` runs the Angular compiler (`tsc` skips templates). `:h write-compiler-plugin`

vim.g.current_compiler = 'ngc'

-- `--noEmit`: bare `ngc` writes JavaScript next to the sources.
vim.cmd([[CompilerSet makeprg=npx\ --no-install\ ngc\ --noEmit\ $*]])

-- NOTE: `ngc` emits colour escapes unconditionally (`--pretty false` and
-- `NO_COLOR` do not reach it), so the format must see through them or the
-- quickfix list stays empty like a green build (@angular/compiler-cli 17.3 / 22.1).
--
-- `CompilerSet` is a `:set` and eats one backslash of every pair: doubled here.
local color = [[%\\%%(%\\e%[[0-9;]%#m%\\)%#]]

-- One diagnostic, with colour sequences between all fields.
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
