return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "helix",
    spec = {
      { "<leader>a", group = "AI (Agentic)" },
      { "<leader>b", group = "Buffer" },
      { "<leader>c", group = "Code" },
      { "<leader>f", group = "Find" },
      { "<leader>g", group = "Git" },
      { "<leader>h", group = "Hunks" },
      { "<leader>o", group = "Overseer" },
      { "<leader>q", group = "Quit" },
      { "<leader>s", group = "Search/Replace" },
      { "<leader>u", group = "UI" },
      { "<leader>x", group = "Trouble" },
    },
  },
}
