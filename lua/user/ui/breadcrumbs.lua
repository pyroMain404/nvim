local M = {
  "LunarVim/breadcrumbs.nvim",
}

function M.config()
  require("breadcrumbs").setup()

  -- breadcrumbs sovrascrive il winbar (su CursorHold/InsertEnter/…) di ogni
  -- buffer non escluso, mostrando "<devicon> <nome file>". Le finestre di
  -- agentic disegnano da sé il proprio header nel winbar (chat: model/token/
  -- costo; prompt: hint di submit) e fungono anche da separatore tra i pannelli:
  -- senza questa esclusione breadcrumbs le calpesta al primo CursorHold/insert
  -- (era il "collasso" degli header). Aggiungiamo i loro filetype alla lista di
  -- esclusione, che breadcrumbs consulta a runtime.
  local bc = require "breadcrumbs"
  vim.list_extend(bc.winbar_filetype_exclude, {
    "AgenticChat",
    "AgenticInput",
    "AgenticCode",
    "AgenticFiles",
    "AgenticDiagnostics",
  })
end

return M
