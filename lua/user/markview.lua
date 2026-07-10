local M = {
  "OXY2DEV/markview.nvim",
  ft = "markdown",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
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
