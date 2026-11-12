-- ┌───────┐
-- │ gopls │
-- └───────┘
--
-- Install with `mise use -g go:golang.org/x/tools/gopls@latest`. Use only tables here.
-- 'nvim-lspconfig' defines `root_dir` as a function; a function here would replace it.
return {
  settings = {
    gopls = {
      -- The `go vet` and staticcheck analyzers run while you type, like `clippy` for Rust.
      staticcheck = true,
    },
  },
}
