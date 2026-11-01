-- ┌──────────────────────┐
-- │ Go build → quickfix  │
-- └──────────────────────┘
--
-- `:compiler go`: `:make build ./...`, `:make test ./...`, `:make vet ./...`
-- into quickfix (`:h write-compiler-plugin`).

-- NOTE: `:compiler` unlets `current_compiler` first, and `.vim` in the name keeps
-- `runtime` from finding this very file. The runtime one knows the build error shape.
vim.cmd('runtime compiler/go.vim')

-- The runtime format misses three things `go` prints: `go vet` prefixes its
-- lines with the tool name (`vet.exe: file:1:2: msg`), a failed test reports
-- `    file_test.go:7: msg` indented, and a panic ends in the frames of the stack
-- (`\tfile.go:13 +0x28`), most of them inside the standard library.
-- NOTE: `^=` prepends, so the last line is tried first: the filters go last.
vim.cmd([[CompilerSet errorformat^=%Avet%.%#:\ %f:%l:%c:\ %m]])
vim.cmd([[CompilerSet errorformat^=%*\\s%f:%l:\ %m]])
vim.cmd([[CompilerSet errorformat^=%*\\s%f:%l\ +0x%*\\x]])
vim.cmd([[CompilerSet errorformat^=%-G%*\\s%.%#/src/runtime/%.%#]])
vim.cmd([[CompilerSet errorformat^=%-G%*\\s%.%#/src/testing/testing.go%.%#]])

vim.g.current_compiler = 'go'

vim.cmd([[CompilerSet makeprg=go\ $*]])
