local M = {
  "nvim-treesitter/nvim-treesitter",
  event = { "BufReadPost", "BufNewFile" },
  build = ":TSUpdate",
}

function M.config()
  require("nvim-treesitter.configs").setup {
    highlight = { enable = true },
    indent = { enable = true },
  }

  require("nvim-treesitter.install").prefer_git = false
end

return M
