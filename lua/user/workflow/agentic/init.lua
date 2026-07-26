-- Integrazione agenti AI via agentic.nvim (carlos-algms): parla l'Agent Client
-- Protocol (ACP) con una CLI provider ESTERNA che il plugin NON gestisce.
-- Per Claude serve la CLI ACP `@agentclientprotocol/claude-agent-acp` installata
-- globalmente (npm/pnpm) e sul PATH: è SEPARATA dalla CLI `claude` standard e dal
-- vecchio server WebSocket MCP di claudecode.nvim. Diagnosi: `:checkhealth user.workflow.agentic`
-- (dipendenza CLI di macchina, user/agentic/health.lua) e `:checkhealth agentic`
-- (stato interno del plugin).
-- Il plugin espone una API Lua (niente ex-command tipo `:ClaudeCode…`): lazy-load
-- via `keys`, setup automatico da `opts`. Gruppo which-key `<leader>c` = "Claude"
-- (`<leader>a` è già il gruppo "Tab", vedi whichkey.lua).
--
-- NB: perché il winbar di agentic non venga calpestato da breadcrumbs.nvim, i
-- filetype Agentic* sono esclusi in user/breadcrumbs.lua (senza quello, era il
-- "collasso" degli header su CursorHold/InsertEnter).

-- Winbar della chat, formato minimale: "󰻞 <model> · <mode> · <usati/tot> · <valuta importo>".
-- I getter di usage (token/costo) tornano nil finché non arriva il primo usage
-- update e DI NUOVO dopo ogni invio (agentic chiama session_state:clear()):
-- senza memoria, token e costo sparirebbero dalla winbar a ogni messaggio finché
-- non arriva il nuovo update. Teniamo perciò l'ultimo valore noto per tabpage e
-- aggiorniamo ogni campo solo quando il suo getter restituisce un valore (sticky);
-- model/mode restano sempre validi (non dipendono dall'usage).
-- NB: agentic incastona questo testo in una stringa in formato statusline, dove
-- `%` introduce un item → un `%` letterale va raddoppiato o dà E539 e blocca
-- l'aggiornamento del winbar: escape difensivo sul valore finale.
local ICON = "󰻞"
local last_state = {}

local function chat_header(_parts, s)
  local tab = vim.api.nvim_get_current_tabpage()

  if s ~= nil then
    local c = last_state[tab] or {}
    c.model = s:get_model_name() or c.model
    c.mode = s:get_mode_name() or c.mode
    c.used = s:get_context_used() or c.used
    c.size = s:get_context_size() or c.size
    c.cost = s:get_cost_amount() or c.cost
    c.cost_raw = s:get_cost_amount_raw() or c.cost_raw
    c.currency = s:get_cost_currency() or c.currency
    last_state[tab] = c
  end

  local d = last_state[tab]
  local text

  if d == nil then
    text = ICON .. " Agentic Chat"
  else
    local segs = {}
    if d.model and d.model ~= "" then
      segs[#segs + 1] = d.model
    end
    if d.mode and d.mode ~= "" then
      segs[#segs + 1] = d.mode
    end
    if d.used and d.size then
      segs[#segs + 1] = d.used .. "/" .. d.size
    end
    if d.cost_raw and d.cost_raw ~= 0 then
      local amount = d.cost or ""
      segs[#segs + 1] = d.currency and (d.currency .. " " .. amount) or amount
    end
    text = (#segs == 0) and (ICON .. " Agentic Chat") or (ICON .. " " .. table.concat(segs, " · "))
  end

  -- escape difensivo: nessun `%` grezzo deve finire nel winbar (vedi sopra).
  return (text:gsub("%%", "%%%%"))
end

local M = {
  "carlos-algms/agentic.nvim",
  opts = {
    provider = "claude-agent-acp",
    windows = {
      position = "right",
      width = "45%",
    },
    headers = {
      chat = chat_header,
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
