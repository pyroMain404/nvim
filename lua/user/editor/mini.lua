-- mini.nvim (branch stable): monorepo dei moduli mini.*.
-- Qui usiamo mini.comment come rimpiazzo di Comment.nvim (fermo dal 2024).
-- Neovim ha gc/gcc nativi dalla 0.10, ma mini.comment mantiene l'integrazione
-- context-aware (JSX/TSX...) via nvim-ts-context-commentstring.
local M = {
  "echasnovski/mini.nvim",
  branch = "stable",
  lazy = false,
  dependencies = {
    {
      "JoosepAlviste/nvim-ts-context-commentstring",
      event = "VeryLazy",
    },
  },
}

function M.config()
  -- context-commentstring: nessun autocmd, commentstring calcolato on-demand
  -- dall'hook di mini.comment (custom_commentstring qui sotto).
  vim.g.skip_ts_context_commentstring_module = true
  ---@diagnostic disable-next-line: missing-fields
  require("ts_context_commentstring").setup { enable_autocmd = false }

  require("mini.comment").setup {
    options = {
      -- Commento context-aware: usa il commentstring calcolato da treesitter
      -- (es. // vs {/* */} in un file JSX), con fallback al buffer.
      custom_commentstring = function()
        return require("ts_context_commentstring").calculate_commentstring()
          or vim.bo.commentstring
      end,
    },
    mappings = {
      comment = "gc", -- operatore (gc{motion})
      comment_line = "<leader>/", -- toggle riga corrente (come prima)
      comment_visual = "<leader>/", -- toggle selezione (come prima)
      textobject = "gc",
    },
  }

  local wk = require "which-key"
  wk.add {
    { "<leader>/", desc = "Comment" },
    { "<leader>/", desc = "Comment", mode = "v" },
  }
end

return M
