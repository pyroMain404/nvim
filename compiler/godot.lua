-- ┌──────────────────────────────┐
-- │ Godot parse check → quickfix │
-- └──────────────────────────────┘
--
-- NOTE: parse only (a call to a missing method exits 0); semantic errors come from the LSP.

vim.g.current_compiler = 'godot'

-- `--path .`: quickfix names resolve against Neovim's directory, not the project.
vim.cmd(
  [[CompilerSet makeprg=godot\ --headless\ --path\ .\ --check-only\ $*\ --script\ %:p:S]]
)

-- NOTE: `\ ` is required because `CompilerSet` is a `:set` (`:h option-backslash`).
vim.cmd([[CompilerSet errorformat=%ESCRIPT\ ERROR:\ %m]])
vim.cmd([[CompilerSet errorformat+=%Z%.%#(res://%f:%l)]])

vim.cmd([[CompilerSet errorformat+=%-G%.%#]])
