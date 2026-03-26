return {
  "cbochs/grapple.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  cmd = "Grapple",
  opts = {
    scope = "git_branch", -- Separate tagged files per git branch
  },
  keys = {
    { "<leader>m", "<cmd>Grapple toggle<CR>", desc = "Grapple: Toggle tag" },
    { "<leader>M", "<cmd>Grapple toggle_tags<CR>", desc = "Grapple: Open tags" },
    { "<leader>1", "<cmd>Grapple select index=1<CR>", desc = "Grapple: File 1" },
    { "<leader>2", "<cmd>Grapple select index=2<CR>", desc = "Grapple: File 2" },
    { "<leader>3", "<cmd>Grapple select index=3<CR>", desc = "Grapple: File 3" },
    { "<leader>4", "<cmd>Grapple select index=4<CR>", desc = "Grapple: File 4" },
    { "<leader>5", "<cmd>Grapple select index=5<CR>", desc = "Grapple: File 5" },
  },
}
