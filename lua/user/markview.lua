local M = {
  "OXY2DEV/markview.nvim",
  -- Anche "AgenticChat": il buffer chat di agentic.nvim è filetype AgenticChat
  -- (col parser treesitter markdown già registrato), non "markdown" → senza
  -- questo ft markview non si caricherebbe mai aprendo la chat.
  ft = { "markdown", "AgenticChat" },
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
}

function M.config()
  require("markview").setup {
    -- preview disabilitato di default: il buffer sorgente resta grezzo
    -- (coerente con conceallevel = 0 in options.lua). Il rendering avviene
    -- solo nel buffer laterale dello splitview, aperto a richiesta.
    preview = {
      enable = false,
      splitview_winopts = { split = "right" },
      -- Il buffer chat di agentic è `buftype = "nofile"`, che markview scarta di
      -- default (ignore_buftypes). `condition` scavalca filetypes+ignore_buftypes:
      -- true → aggancia comunque la chat; nil → ricade sul comportamento standard
      -- per tutto il resto (così NON riscrivo la lista filetypes di default).
      -- Il rendering resta on-demand (preview.enable = false): nella chat si attiva
      -- con gli stessi <leader>mm / <leader>ms degli altri markdown.
      condition = function(buf)
        if vim.bo[buf].filetype == "AgenticChat" then
          return true
        end
      end,
    },
  }

  local wk = require "which-key"
  wk.add {
    { "<leader>m", group = "Markdown" },
    { "<leader>ms", "<cmd>Markview splitToggle<cr>", desc = "Split preview" },
    { "<leader>mm", "<cmd>Markview toggle<cr>", desc = "Toggle inline preview" },
  }
end

return M
