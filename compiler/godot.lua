-- ┌──────────────────────────────┐
-- │ Godot parse check → quickfix │
-- └──────────────────────────────┘
--
-- NOTE: This checks parsing only because a call to a missing method exits 0.
-- The LSP reports semantic errors.

vim.g.current_compiler = 'godot'

-- The command passes `--path .` because quickfix resolves names against the Neovim directory,
-- not the project directory.
vim.cmd(
  [[CompilerSet makeprg=godot\ --headless\ --path\ .\ --check-only\ $*\ --script\ %:p:S]]
)

-- NOTE: `CompilerSet` is a `:set`, so the code needs `\ ` (`:h option-backslash`).
vim.cmd([[CompilerSet errorformat=%ESCRIPT\ ERROR:\ %m]])
vim.cmd([[CompilerSet errorformat+=%Z%.%#(res://%f:%l)]])

vim.cmd([[CompilerSet errorformat+=%-G%.%#]])
