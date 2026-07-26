-- nvim-treesitter è stato archiviato (aprile 2026). Su nvim 0.12 il motore
-- treesitter è nel core (vim.treesitter): qui usiamo tree-sitter-manager.nvim
-- (mantenuto) solo per installare i parser e abilitare l'highlight.
-- I parser finiscono in stdpath("data")/site/parser, sul runtimepath standard,
-- così anche markview/neotest/vim-illuminate/nvim-autopairs li trovano via il
-- core vim.treesitter senza dipendere più da nvim-treesitter.
-- Nota: l'indent treesitter (indent={enable=true} del vecchio setup) non è
-- coperto dal core/manager; si ricade sull'indent standard per filetype.
local M = {
  "romus204/tree-sitter-manager.nvim",
  event = { "BufReadPost", "BufNewFile" },
}

function M.config()
  require("tree-sitter-manager").setup {
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
      "go",
      "java",
      "c_sharp", -- C#/Unity (il core 0.12 mappa già il filetype cs -> lang c_sharp)
      "hlsl", -- shader Unity: .hlsl/.hlsli/.cginc/.compute (ftdetect in autocmds.lua)
      "dockerfile",
      "hcl", -- usato anche per i file .alloy (Grafana Alloy), evidenziazione approssimativa
    },
    highlight = true,
  }

  -- ShaderLab (.shader) non ha un parser treesitter dedicato: usiamo la grammatica
  -- HLSL come approssimazione (i file .shader di Unity incorporano blocchi HLSL/CG),
  -- stesso principio di .alloy -> hcl. Le mappe cs -> c_sharp e hlsl -> hlsl sono già
  -- builtin nel core 0.12, quindi non serve registrarle. L'highlight parte via
  -- l'autocmd FileType di tree-sitter-manager (highlight = true).
  vim.treesitter.language.register("hlsl", "shaderlab")
end

return M
