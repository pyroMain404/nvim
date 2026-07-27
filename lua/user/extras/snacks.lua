-- Sostituisce dressing.nvim (archiviato): il suo README indica folke/snacks.nvim
-- come rimpiazzo. Qui si usano solo i due moduli che coprivano dressing:
--   input  -> override di vim.ui.input (floating)
--   picker -> override di vim.ui.select (floating + ricerca fuzzy, es. lista chat di agentic)
-- Gli altri moduli di snacks restano disabilitati (non passati in opts).
local M = {
  "folke/snacks.nvim",
  -- snacks va caricato eager (raccomandazione ufficiale): il setup registra
  -- subito gli override di vim.ui.*; i singoli moduli restano lazy internamente.
  priority = 1000,
  lazy = false,
}

function M.config()
  require("snacks").setup {
    input = {
      enabled = true,
    },
    picker = {
      enabled = true,
      ui_select = true, -- rimpiazza vim.ui.select con il picker di snacks
    },
    -- Preserva l'estetica di dressing per l'input flottante.
    styles = {
      input = {
        border = "rounded",
        title_pos = "left",
        relative = "cursor",
        row = 1,
        wo = { winblend = 10 },
      },
    },
  }
end

return M
