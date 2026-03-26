return {
  "stevearc/overseer.nvim",
  cmd = { "OverseerRun", "OverseerToggle", "OverseerInfo" },
  opts = {
    strategy = "terminal",
    templates = { "builtin" },
    task_list = {
      direction = "bottom",
      default_detail = 1,
    },
  },
  keys = {
    { "<leader>or", "<cmd>OverseerRun<CR>", desc = "Overseer: Run task" },
    { "<leader>ot", "<cmd>OverseerToggle<CR>", desc = "Overseer: Toggle list" },
    { "<leader>oa", "<cmd>OverseerQuickAction<CR>", desc = "Overseer: Quick action" },
    { "<leader>oi", "<cmd>OverseerInfo<CR>", desc = "Overseer: Info" },
  },
}
