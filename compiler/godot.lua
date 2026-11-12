-- ┌──────────────────────────────┐
-- │ Godot parse check → quickfix │
-- └──────────────────────────────┘
--
-- NOTE: This checks parsing only because a call to a missing method exits 0.
-- The LSP reports semantic errors.

vim.g.current_compiler = 'godot'

-- Use `--path .` because quickfix resolves names against Neovim's directory, not the project.
vim.cmd(
  [[CompilerSet makeprg=godot\ --headless\ --path\ .\ --check-only\ $*\ --script\ %:p:S]]
)

-- NOTE: Use `\ ` because `CompilerSet` is a `:set` (`:h option-backslash`).
vim.cmd([[CompilerSet errorformat=%ESCRIPT\ ERROR:\ %m]])
vim.cmd([[CompilerSet errorformat+=%Z%.%#(res://%f:%l)]])

vim.cmd([[CompilerSet errorformat+=%-G%.%#]])
