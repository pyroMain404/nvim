-- Integrazione agenti AI via agentic.nvim (carlos-algms): parla l'Agent Client
-- Protocol (ACP) con una CLI provider ESTERNA che il plugin NON gestisce.
-- Per Claude serve la CLI ACP `@agentclientprotocol/claude-agent-acp` installata
-- globalmente (npm/pnpm) e sul PATH: è SEPARATA dalla CLI `claude` standard e dal
-- vecchio server WebSocket MCP di claudecode.nvim. Diagnosi: `:checkhealth user.agentic`
-- (dipendenza CLI di macchina, user/agentic/health.lua) e `:checkhealth agentic`
-- (stato interno del plugin).
-- Il plugin espone una API Lua (niente ex-command tipo `:ClaudeCode…`): lazy-load
-- via `keys`, setup automatico da `opts`. Gruppo which-key `<leader>c` = "Claude"
-- (`<leader>a` è già il gruppo "Tab", vedi whichkey.lua).
local M = {
  "carlos-algms/agentic.nvim",
  opts = {
    provider = "claude-agent-acp",
    windows = {
      position = "right",
      width = "45%",
    },
  },
  keys = {
    { "<leader>cc", function() require("agentic").toggle() end, desc = "Toggle Claude", mode = { "n", "x" } },
    { "<leader>cf", function() require("agentic").open() end, desc = "Focus Claude" },
    { "<leader>cn", function() require("agentic").new_session() end, desc = "New session" },
    { "<leader>cr", function() require("agentic").restore_session() end, desc = "Restore session" },
    { "<leader>cp", function() require("agentic").switch_provider() end, desc = "Switch provider" },
    { "<leader>cb", function() require("agentic").add_file() end, desc = "Add current file" },
    { "<leader>cs", function() require("agentic").add_selection() end, mode = "v", desc = "Add selection" },
    { "<leader>cd", function() require("agentic").add_buffer_diagnostics() end, desc = "Add diagnostics" },
    { "<leader>cS", function() require("agentic").stop_generation() end, desc = "Stop generation" },
  },
}

return M
