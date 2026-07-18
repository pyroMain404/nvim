-- :checkhealth user.node — stato dell'ambiente Node per gli LSP npm.
-- Filosofia: SEGNALARE, non silenziare. Se manca fnm o la versione fissata, WARNING
-- (mai ERROR fatale): la config degrada al node globale, ma vogliamo saperlo.
local M = {}

function M.check()
  local h = vim.health
  h.start "user.node (Node per gli LSP npm)"

  local ok, node = pcall(require, "user.node")
  if not ok then
    h.error("modulo user.node non caricato: " .. tostring(node))
    return
  end
  local s = node.status()

  if s.fnm then
    h.ok "fnm presente nel PATH"
  else
    h.warn("fnm non nel PATH — si usa il node globale, se presente", {
      "Per gestire più versioni Node: winget install Schniz.fnm",
    })
  end

  if s.pinned_installed then
    h.ok(("versione fissata %s installata e prepesa al PATH di nvim"):format(s.pinned))
  else
    h.warn(("versione fissata %s non installata: gli LSP npm useranno il node globale"):format(s.pinned), {
      ("fnm install %s"):format(s.pinned),
    })
  end

  if s.node ~= "" then
    h.ok("node risolto: " .. s.node)
  else
    h.warn("nessun `node` nel PATH: gli LSP npm (ts_ls, eslint, pyright, ...) non partiranno", {
      "Apri nvim da una shell con fnm attivo, oppure installa la versione fissata",
    })
  end

  if s.npm ~= "" then
    h.ok("npm risolto: " .. s.npm)
  else
    h.warn "nessun `npm` nel PATH"
  end
end

return M
