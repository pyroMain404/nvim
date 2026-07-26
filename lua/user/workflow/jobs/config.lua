local M = {}

-- Configurazione dei job in background (web server, loop di compilazione, ...).
-- Vedi user/jobs/init.lua per il ciclo di vita e user/jobs/panel.lua per la UI.

-- Nome (relativo alla root del progetto) del nostro file di task locale, in JSON
-- dichiarativo. È ignorato dal versionamento: la prima volta che lo si usa/crea,
-- init.lua aggiunge `/.nvim/` al .git/info/exclude locale (idempotente), come fa
-- jdtls con `/bin/`. Leggerlo NON esegue codice: il comando parte solo al lancio.
M.local_file = ".nvim/tasks.json"

-- Task pre-configurati in Lua, sempre disponibili (o filtrati per progetto).
-- Ogni voce: { name = "...", cmd = "...", cwd = "opzionale", when = fn? }
--   * cmd  : stringa passata alla shell (vim.o.shell).
--   * cwd  : cartella di lavoro; relativa alla root del progetto se non assoluta.
--   * when : function(root) -> boolean; se presente, il task compare solo quando
--            ritorna true (es. filtro per path del progetto).
M.tasks = {
  -- Esempio (decommenta per abilitarlo ovunque):
  -- { name = "http :8000", cmd = "python -m http.server 8000" },
}

-- Interruttori dei detector (precondizione → job), oltre al nostro .nvim/tasks.json
-- e alla lista `M.tasks` qui sopra. Mettere una voce a `false` disattiva quella
-- sorgente. La struttura precondizione→job vive in user/jobs/providers.lua
-- (lista `DETECTORS`): aggiungere un tool = aggiungere una riga lì.
-- I detector "local" e "lua" non sono elencati qui: attivi di default; per
-- disattivarli basta comunque aggiungere `["local"] = false` / `lua = false`.
M.providers = {
  vscode = true, -- .vscode/tasks.json (JSONC: commenti e virgole finali tollerati)
  npm = true, -- script di package.json  →  "<pm> run <script>"
  maven = true, -- pom.xml → goal Maven (mvnw se presente); spring-boot:run se Spring Boot
}

return M
