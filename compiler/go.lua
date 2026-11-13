-- ┌──────────────────────┐
-- │ Go build → quickfix  │
-- └──────────────────────┘
--
-- `:compiler go` sends results to quickfix for these commands:
-- `:make build ./...`, `:make test ./...`, and `:make vet ./...`.
-- See `:h write-compiler-plugin`.

-- NOTE: `:compiler` unlets `current_compiler` first.
-- `.vim` in the name stops `runtime` from finding this file.
-- The runtime file handles the build error format.
vim.cmd('runtime compiler/go.vim')

-- The runtime format misses three kinds of `go` output.
-- `go vet` adds the tool name before each line (`vet.exe: file:1:2: msg`).
-- A failed test indents `    file_test.go:7: msg`.
-- A panic ends with stack frames (`\tfile.go:13 +0x28`), mostly from the standard library.
--
-- NOTE: `^=` adds entries at the start, so the last line takes priority.
-- The filters therefore come last.
vim.cmd([[CompilerSet errorformat^=%Avet%.%#:\ %f:%l:%c:\ %m]])
vim.cmd([[CompilerSet errorformat^=%*\\s%f:%l:\ %m]])
vim.cmd([[CompilerSet errorformat^=%*\\s%f:%l\ +0x%*\\x]])
vim.cmd([[CompilerSet errorformat^=%-G%*\\s%.%#/src/runtime/%.%#]])
vim.cmd([[CompilerSet errorformat^=%-G%*\\s%.%#/src/testing/testing.go%.%#]])

vim.g.current_compiler = 'go'

vim.cmd([[CompilerSet makeprg=go\ $*]])
