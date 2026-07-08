local M = {
  "nvim-treesitter/nvim-treesitter",
  branch = "master", -- il branch "main" è il rewrite senza nvim-treesitter.configs
  event = { "BufReadPost", "BufNewFile" },
  build = ":TSUpdate",
}

function M.config()
  require("nvim-treesitter.configs").setup {
    ensure_installed = {
      "lua",
      "markdown",
      "markdown_inline",
      "bash",
      "python",
      "json",
      "yaml",
      "javascript",
      "typescript",
      "tsx",
      "html",
      "css",
      "rust",
      "toml",
      "c",
      "cpp",
    },
    highlight = { enable = true },
    indent = { enable = true },
  }
end

return M
