return {
  "carlos-algms/agentic.nvim",
  event = "VeryLazy",
  opts = {
    provider = "claude-agent-acp",
  },
  keys = {
    { "<C-\\>",     function() require("agentic").toggle() end,                          mode = { "n", "v", "i" }, desc = "Agentic: Toggle chat" },
    { "<C-'>",      function() require("agentic").add_selection_or_file_to_context() end, mode = { "n", "v" },      desc = "Agentic: Add file/selection to context" },
    { "<C-,>",      function() require("agentic").new_session() end,                     mode = { "n", "v", "i" }, desc = "Agentic: New session" },
    { "<leader>ar", function() require("agentic").restore_session() end,                 mode = { "n", "v", "i" }, desc = "Agentic: Restore session" },
    { "<leader>ad", function() require("agentic").add_current_line_diagnostics() end,    mode = "n",               desc = "Agentic: Add line diagnostic" },
    { "<leader>aD", function() require("agentic").add_buffer_diagnostics() end,          mode = "n",               desc = "Agentic: Add buffer diagnostics" },
  },
}
