-- Integrazione Claude Code (coder/claudecode.nvim): server WebSocket MCP a cui
-- si aggancia la CLI `claude` lanciata in un terminale dentro nvim.
-- Provider `native`: NON usa snacks (assente in questa config) — il terminale è
-- uno split gestito dal plugin stesso. La CLI `claude` è sul PATH (WinGet), quindi
-- nessun `terminal_cmd` custom. Gruppo which-key `<leader>c` = "Claude"
-- (`<leader>a` è già il gruppo "Tab", vedi whichkey.lua).
local M = {
  "coder/claudecode.nvim",
  -- `cmd` crea gli stub lazy: `:ClaudeCode` & co. esistono già al primo avvio,
  -- senza dover premere prima una keymap.
  cmd = {
    "ClaudeCode",
    "ClaudeCodeFocus",
    "ClaudeCodeSelectModel",
    "ClaudeCodeAdd",
    "ClaudeCodeSend",
    "ClaudeCodeTreeAdd",
    "ClaudeCodeStatus",
    "ClaudeCodeStart",
    "ClaudeCodeStop",
    "ClaudeCodeOpen",
    "ClaudeCodeClose",
    "ClaudeCodeDiffAccept",
    "ClaudeCodeDiffDeny",
    "ClaudeCodeCloseAllDiffs",
  },
  keys = {
    { "<leader>cc", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude", mode = { "n", "x" } },
    { "<leader>cf", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
    { "<leader>cr", "<cmd>ClaudeCode --resume<cr>", desc = "Resume" },
    { "<leader>cC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue" },
    { "<leader>cm", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select model" },
    { "<leader>cb", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
    { "<leader>cs", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection" },
    { "<leader>cs", "<cmd>ClaudeCodeTreeAdd<cr>", desc = "Add file (tree)", ft = { "NvimTree" } },
    -- Gestione diff
    { "<leader>ca", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
    { "<leader>cd", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
    { "<leader>cx", "<cmd>ClaudeCodeCloseAllDiffs<cr>", desc = "Close all diffs" },
  },
}

function M.config()
  require("claudecode").setup {
    terminal = {
      provider = "native", -- niente snacks: split gestito dal plugin
      split_side = "right",
      split_width_percentage = 0.35,
    },
  }
end

return M
