-- ┌──────────────────────────┐
-- │ CMake build → quickfix   │
-- └──────────────────────────┘
--
-- `:compiler cmake`: `:make` into quickfix (`:h write-compiler-plugin`).

-- NOTE: gcc.vim exits early if `current_compiler` is set, so source it BEFORE
-- claiming the name (`:compiler` unlets it first).
vim.cmd('runtime compiler/gcc.vim')

vim.cmd([[CompilerSet errorformat+=%ECMake\ Error\ at\ %f:%l\ %m]])
vim.cmd([[CompilerSet errorformat+=%ECMake\ Error\ at\ %f:%l:]])
vim.cmd([[CompilerSet errorformat+=%C\ \ %m]])
vim.cmd([[CompilerSet errorformat+=%+GError:%.%#]])

vim.cmd([[CompilerSet errorformat+=%-G%.%#]])

vim.g.current_compiler = 'cmake'

vim.cmd([[CompilerSet makeprg=cmake\ --build\ build\ $*]])
