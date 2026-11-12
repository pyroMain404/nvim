-- ┌───────────┐
-- │ angularls │
-- └───────────┘
--
-- For installation, see `check_angular()` in 'lua/config/health.lua'.
-- `workspace_required` (`:h vim.lsp.Config`) excludes plain '.ts' files, where the server exits
-- with a popup.
return {
  workspace_required = true,
}
