-- ┌───────┐
-- │ gopls │
-- └───────┘
--
-- Install: `mise use -g go:golang.org/x/tools/gopls@latest`. Only tables here:
-- 'nvim-lspconfig' defines `root_dir` as a function, and a function of ours would replace it.
return {
  settings = {
    gopls = {
      -- The `go vet` and staticcheck analyzers while typing, as `clippy` is for Rust.
      staticcheck = true,
    },
  },
}
