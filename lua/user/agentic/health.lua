-- :checkhealth user.agentic — dipendenze ESTERNE del plugin agentic.nvim.
-- Filosofia: SEGNALARE, non silenziare (come user.node/user.jobs). Il plugin NON
-- gestisce i binari: la CLI provider ACP va installata a mano e messa sul PATH.
-- Questo check verifica la sola dipendenza di macchina; per lo stato interno del
-- plugin (sessioni, transport, keymap) c'è il `:checkhealth agentic` nativo.
local M = {}

-- Comando CLI atteso per i provider ACP che configuriamo (default del plugin).
local PROVIDER_CMD = {
  ["claude-agent-acp"] = "claude-agent-acp",
}

function M.check()
  local h = vim.health
  h.start "user.agentic (agenti AI via ACP)"

  -- 1. Plugin installato/caricabile.
  local ok, agentic = pcall(require, "agentic")
  if not ok then
    h.error("plugin agentic.nvim non caricabile: " .. tostring(agentic), {
      "Esegui :Lazy sync per installarlo",
    })
    return
  end
  h.ok "plugin agentic.nvim caricato"

  -- 2. Provider ACP configurato (letto dalla spec user.agentic, non hardcodato qui).
  local provider = "claude-agent-acp"
  local spec_ok, spec = pcall(require, "user.agentic")
  if spec_ok and type(spec) == "table" and type(spec.opts) == "table" and spec.opts.provider then
    provider = spec.opts.provider
  end
  h.info("provider configurato: " .. provider)

  -- 3. CLI del provider sul PATH — dipendenza di macchina non gestita dal plugin.
  local cmd = PROVIDER_CMD[provider] or provider
  if vim.fn.executable(cmd) == 1 then
    h.ok(("CLI provider `%s` trovata: %s"):format(cmd, vim.fn.exepath(cmd)))
  else
    h.warn(("CLI provider `%s` non nel PATH — il pannello non partirà"):format(cmd), {
      "Installa la CLI ACP del provider (vedi doc ufficiale), es. per Claude:",
      "  npm add -g @agentclientprotocol/claude-agent-acp",
      "e assicurati che sia sul PATH da cui lanci nvim.",
    })
  end

  -- 4. Le CLI ACP sono pacchetti npm: senza node non partono.
  if vim.fn.executable "node" == 1 then
    h.ok("node presente: " .. vim.fn.exepath "node")
  else
    h.warn("`node` non nel PATH: le CLI ACP basate su npm non partiranno", {
      "Vedi :checkhealth user.node",
    })
  end

  h.info "Stato interno del plugin (sessioni, transport): :checkhealth agentic"
end

return M
