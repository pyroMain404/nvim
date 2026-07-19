-- Node deterministica per gli LSP npm (ts_ls, eslint, pyright, somesass_ls,
-- tailwindcss, html, jsonls, yamlls, bashls, dockerls, docker_compose,
-- angularls) e per prettier.
--
-- Perché: questi server sono processi che nvim lancia cercando `node` nel PATH.
-- Con fnm la node "attiva" varia (default fnm, `.node-version` del progetto con
-- --use-on-cd, versione della shell). Conseguenze indesiderate:
--   1. apri nvim in un repo con node vecchia (.node-version=16) → gli LSP girano con
--      quella node e alcuni (moderni) falliscono/degradano;
--   2. apri nvim fuori da una shell fnm (GUI/launcher/hook/headless) → `node` non è
--      nel PATH → gli LSP non partono.
-- Qui fissiamo la versione che nvim usa per gli LSP prependendo STATICAMENTE al PATH
-- la dir della versione fnm scelta: nessun `fnm env`/subprocess (niente rallentamento)
-- e indipendente dall'inizializzazione di fnm. Il PATH del progetto/terminale resta
-- libero: fissiamo solo ciò che vede nvim.
--
-- NB: NON è il "provider node" (g:node_host_prog): quello serve ai remote-plugin JS,
-- non agli LSP. Vedi :help provider-nodejs.
local M = {}

-- Versione Node fissata per gli LSP (npm bundled ~10.9.x).
M.pinned = "v22.23.1"

local is_win = vim.fn.has "win32" == 1

local function fnm_dir()
  if vim.env.FNM_DIR and vim.env.FNM_DIR ~= "" then
    return vim.fs.normalize(vim.env.FNM_DIR)
  end
  if is_win then
    return vim.fs.normalize((vim.env.APPDATA or "") .. "/fnm")
  end
  local data = vim.env.XDG_DATA_HOME or ((vim.env.HOME or "") .. "/.local/share")
  return vim.fs.normalize(data .. "/fnm")
end

-- Dir che contiene node/npm della versione fissata, o nil se non installata.
-- Windows: installation/ ; POSIX: installation/bin.
function M.node_bin()
  local base = fnm_dir() .. "/node-versions/" .. M.pinned .. "/installation"
  local bin = is_win and base or (base .. "/bin")
  return vim.fn.isdirectory(bin) == 1 and bin or nil
end

-- Prepend idempotente al PATH: la versione fissata vince sulla node della shell.
function M.setup()
  local bin = M.node_bin()
  if not bin then
    return -- non installata: nessun prepend, si degrada al node globale (vedi health)
  end
  local sep = is_win and ";" or ":"
  local path = vim.env.PATH or ""
  if not path:find(bin, 1, true) then
    vim.env.PATH = bin .. sep .. path
  end
end

-- Stato per :checkhealth user.node (segnala, non silenzia).
function M.status()
  return {
    fnm = vim.fn.executable "fnm" == 1,
    pinned = M.pinned,
    pinned_installed = M.node_bin() ~= nil,
    node = vim.fn.exepath "node",
    npm = vim.fn.exepath "npm",
  }
end

M.setup()

return M
