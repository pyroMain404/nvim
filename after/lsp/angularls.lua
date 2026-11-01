-- ┌───────────┐
-- │ angularls │
-- └───────────┘
--
-- Install: `check_angular()` in 'lua/config/health.lua'. `workspace_required`
-- (`:h vim.lsp.Config`) keeps it off plain '.ts' files, where it exits with a popup.
return {
  workspace_required = true,
}
