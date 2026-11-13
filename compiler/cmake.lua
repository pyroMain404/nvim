-- ┌──────────────────────────┐
-- │ CMake build → quickfix   │
-- └──────────────────────────┘
--
-- `:compiler cmake` sends `:make` results to quickfix (`:h write-compiler-plugin`).

-- NOTE: `gcc.vim` exits early when `current_compiler` is set.
-- This file sources `gcc.vim` before it sets `current_compiler`.
-- `:compiler` unlets `current_compiler` first.
vim.cmd('runtime compiler/gcc.vim')

vim.cmd([[CompilerSet errorformat+=%ECMake\ Error\ at\ %f:%l\ %m]])
vim.cmd([[CompilerSet errorformat+=%ECMake\ Error\ at\ %f:%l:]])
vim.cmd([[CompilerSet errorformat+=%C\ \ %m]])
vim.cmd([[CompilerSet errorformat+=%+GError:%.%#]])

vim.cmd([[CompilerSet errorformat+=%-G%.%#]])

vim.g.current_compiler = 'cmake'

vim.cmd([[CompilerSet makeprg=cmake\ --build\ build\ $*]])
