-- Elenco centralizzato dei server LSP gestiti da mason-lspconfig, condiviso da
-- mason.lua (ensure_installed) e lspconfig.lua (vim.lsp.config). Alcuni pacchetti
-- Mason delegano la build a un toolchain di sistema (es. gopls richiede il
-- compilatore Go): se manca, mason-lspconfig ritenterebbe l'installazione ad
-- ogni avvio fallendo sempre. Per evitarlo, il server viene escluso finché il
-- prerequisito non compare nel PATH: nessun errore, nessun retry inutile, e
-- torna disponibile in automatico al riavvio successivo all'installazione del
-- prerequisito.
local M = {}

-- requires = eseguibile richiesto sul PATH per installare/eseguire il server
-- (nil = nessun prerequisito esterno, Mason scarica un binario precompilato)
local all_servers = {
  { name = "lua_ls" },
  { name = "cssls" },
  { name = "html" },
  { name = "ts_ls" },
  { name = "eslint" },
  { name = "pyright" },
  { name = "bashls" },
  { name = "jsonls" },
  { name = "yamlls" },
  { name = "rust_analyzer" },
  { name = "clangd" },
  { name = "gopls", requires = "go" },
  { name = "dockerls", requires = "npm" },
  { name = "docker_compose_language_service", requires = "npm" },
  { name = "helm_ls" },
}

--- @return string[] servers, string[] skipped (descrizioni leggibili)
function M.resolve()
  local servers, skipped = {}, {}
  for _, s in ipairs(all_servers) do
    if not s.requires or vim.fn.executable(s.requires) == 1 then
      table.insert(servers, s.name)
    else
      table.insert(skipped, ("%s (richiede '%s' nel PATH)"):format(s.name, s.requires))
    end
  end
  return servers, skipped
end

--- Notifica una sola volta per sessione l'elenco dei server saltati per
--- prerequisiti mancanti (mason.lua e lspconfig.lua chiamano entrambi resolve()).
function M.warn_skipped(skipped)
  if #skipped == 0 or vim.g.__lsp_servers_warned then
    return
  end
  vim.g.__lsp_servers_warned = true
  vim.notify(
    "LSP non installati per prerequisiti mancanti:\n- " .. table.concat(skipped, "\n- "),
    vim.log.levels.WARN,
    { title = "mason-lspconfig" }
  )
end

return M
