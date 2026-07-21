-- Scoperta dei task disponibili per il progetto corrente, da più sorgenti.
--
-- Struttura portante: una lista di "detector", ciascuno una coppia
--   precondizione (`when`)  →  job disponibili (`tasks`)
-- Aggiungere il supporto a un tool = aggiungere UNA riga a `DETECTORS`:
--   { source = "<etichetta>", when = has_file "<file>", tasks = <fn(root)->lista> }
--     * source : etichetta mostrata nel pannello e chiave in cfg.providers
--                (disattivabile con cfg.providers[source] = false).
--     * when   : function(root) -> boolean; la precondizione. Omessa = sempre.
--     * tasks  : function(root) -> lista di { name, cmd, cwd? }.
-- `M.collect()` scorre i detector attivi la cui precondizione è vera, unisce e
-- deduplica i task per nome (vince la prima sorgente nell'ordine di DETECTORS).

local uv = vim.uv or vim.loop
local cfg = require "user.jobs.config"
local fs = require "user.util.fs"

local M = {}

--- Root del progetto: primo antenato con `.git` (o marker di progetto), altrimenti cwd.
function M.root()
  local cwd = vim.fn.getcwd()
  local root = vim.fs and vim.fs.root and vim.fs.root(cwd, { ".git", ".vscode", "package.json", "pom.xml" })
  return vim.fs.normalize(root or cwd)
end

--- Risolve una cwd di task (eventualmente relativa) contro la root.
function M.resolve_cwd(cwd, root)
  if not cwd or cwd == "" then
    return root
  end
  if fs.is_absolute(cwd) then
    return vim.fs.normalize(cwd)
  end
  return vim.fs.normalize(root .. "/" .. cwd)
end

-- ── Helper di lettura ────────────────────────────────────────────────────────

local read_file = fs.read_file

-- Precondizione: il file (relativo alla root) esiste.
local function has_file(rel)
  return function(root)
    return uv.fs_stat(root .. "/" .. rel) ~= nil
  end
end

-- JSONC (commenti + virgole finali): stripper condiviso con user/projects (workspace).
local jsonc = require "user.util.jsonc"

local function decode_json(data, is_jsonc)
  if not data then
    return nil
  end
  if is_jsonc then
    return jsonc.decode(data)
  end
  local ok, decoded = pcall(vim.json.decode, data)
  if not ok then
    return nil
  end
  return decoded
end

-- Sostituisce le variabili vscode più comuni con la root del progetto.
local function subst(s, root)
  if type(s) ~= "string" then
    return s
  end
  return (s:gsub("%${workspaceFolder}", root):gsub("%${workspaceRoot}", root):gsub("%${cwd}", root))
end

-- ── Sorgenti di task (una funzione per sorgente, ritorna { name, cmd, cwd? }) ──

-- Il nostro formato: { "tasks": [ { "name", "cmd", "cwd"? }, ... ] }
local function tasks_local(root)
  local decoded = decode_json(read_file(root .. "/" .. cfg.local_file), true)
  if type(decoded) ~= "table" or type(decoded.tasks) ~= "table" then
    return {}
  end
  local tasks = {}
  for _, t in ipairs(decoded.tasks) do
    if type(t) == "table" and type(t.name) == "string" and type(t.cmd) == "string" then
      tasks[#tasks + 1] = { name = t.name, cmd = t.cmd, cwd = t.cwd }
    end
  end
  return tasks
end

-- Pre-config Lua (user/jobs/config.lua), con eventuale filtro `when(root)`.
local function tasks_lua(root)
  local tasks = {}
  for _, t in ipairs(cfg.tasks or {}) do
    if type(t) == "table" and type(t.name) == "string" and type(t.cmd) == "string" then
      if type(t.when) ~= "function" or t.when(root) then
        tasks[#tasks + 1] = { name = t.name, cmd = t.cmd, cwd = t.cwd }
      end
    end
  end
  return tasks
end

-- Costruisce la stringa comando da un task vscode (command + args).
local function vscode_cmd(t)
  if type(t.command) ~= "string" then
    return nil -- task compound (dependsOn) o senza comando: saltato
  end
  if type(t.args) ~= "table" then
    return t.command
  end
  local parts = { t.command }
  for _, a in ipairs(t.args) do
    if type(a) == "string" then
      parts[#parts + 1] = a
    elseif type(a) == "table" and type(a.value) == "string" then
      parts[#parts + 1] = a.value
    end
  end
  return table.concat(parts, " ")
end

-- .vscode/tasks.json (JSONC). Legge label/command/args/options.cwd.
local function tasks_vscode(root)
  local decoded = decode_json(read_file(root .. "/.vscode/tasks.json"), true)
  if type(decoded) ~= "table" or type(decoded.tasks) ~= "table" then
    return {}
  end
  local tasks = {}
  for _, t in ipairs(decoded.tasks) do
    if type(t) == "table" and type(t.label) == "string" then
      local cmd = vscode_cmd(t)
      if cmd then
        local cwd = type(t.options) == "table" and t.options.cwd or nil
        tasks[#tasks + 1] = { name = t.label, cmd = subst(cmd, root), cwd = cwd and subst(cwd, root) or nil }
      end
    end
  end
  return tasks
end

local function detect_pm(root)
  if uv.fs_stat(root .. "/pnpm-lock.yaml") then
    return "pnpm"
  elseif uv.fs_stat(root .. "/yarn.lock") then
    return "yarn"
  elseif uv.fs_stat(root .. "/bun.lockb") then
    return "bun"
  end
  return "npm"
end

-- Script di package.json → "<pm> run <script>" (pm dedotto dal lockfile).
local function tasks_npm(root)
  local decoded = decode_json(read_file(root .. "/package.json"), false)
  if type(decoded) ~= "table" or type(decoded.scripts) ~= "table" then
    return {}
  end
  local pm = detect_pm(root)
  local names = {}
  for name in pairs(decoded.scripts) do
    if type(name) == "string" then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  local tasks = {}
  for _, name in ipairs(names) do
    tasks[#tasks + 1] = { name = ("%s: %s"):format(pm, name), cmd = ("%s run %s"):format(pm, name) }
  end
  return tasks
end

-- Wrapper Maven del progetto se presente (mvnw.cmd/mvnw), altrimenti `mvn` dal PATH.
local function maven_cmd(root)
  if vim.fn.has "win32" == 1 and uv.fs_stat(root .. "/mvnw.cmd") then
    return "./mvnw.cmd"
  elseif uv.fs_stat(root .. "/mvnw") then
    return "./mvnw"
  end
  return "mvn"
end

-- Il pom.xml menziona un pattern (es. "spring-boot")? Per goal condizionali.
local function pom_has(root, pat)
  local data = read_file(root .. "/pom.xml")
  return data ~= nil and data:find(pat) ~= nil
end

-- Goal Maven utili come job. spring-boot:run compare solo se il pom usa Spring Boot.
local function tasks_maven(root)
  local mvn = maven_cmd(root)
  local tasks = {
    { name = "mvn clean", cmd = mvn .. " clean" },
    { name = "mvn compile", cmd = mvn .. " compile" },
    { name = "mvn test", cmd = mvn .. " test" },
    { name = "mvn package", cmd = mvn .. " package -DskipTests" },
    { name = "mvn verify", cmd = mvn .. " verify" },
    { name = "mvn clean install", cmd = mvn .. " clean install" },
  }
  if pom_has(root, "spring%-boot") then
    table.insert(tasks, 1, { name = "mvn spring-boot:run", cmd = mvn .. " spring-boot:run" })
  end
  return tasks
end

-- ── Detector: precondizione → job disponibili ────────────────────────────────
-- L'ordine conta per il dedup (la prima sorgente che definisce un `name` vince).
local DETECTORS = {
  { source = "local", when = has_file(cfg.local_file), tasks = tasks_local },
  { source = "lua", tasks = tasks_lua }, -- nessuna precondizione: sempre valutato
  { source = "vscode", when = has_file ".vscode/tasks.json", tasks = tasks_vscode },
  { source = "npm", when = has_file "package.json", tasks = tasks_npm },
  { source = "maven", when = has_file "pom.xml", tasks = tasks_maven },
}

-- Task di UN singolo progetto (root), uniti e deduplicati per nome (prima sorgente vince).
local function collect_one(root)
  local seen, result = {}, {}
  for _, d in ipairs(DETECTORS) do
    if cfg.providers[d.source] ~= false and (not d.when or d.when(root)) then
      for _, task in ipairs(d.tasks(root) or {}) do
        -- Nome vuoto (o solo spazi) → ignorato: scarta lo scheletro di
        -- .nvim/tasks.json non ancora compilato.
        local named = type(task.name) == "string" and vim.trim(task.name) ~= ""
        if named and type(task.cmd) == "string" and not seen[task.name] then
          task.source = d.source
          seen[task.name] = true
          result[#result + 1] = task
        end
      end
    end
  end
  return result
end

--- Le root del "gruppo": i progetti fratelli della cwd (stesso prefisso di nome, o
--- elencati in un file *.code-workspace/*.workspace). Vedi user/projects/group.lua.
--- Con un solo membro (o senza projects.group) è la sola root corrente.
function M.roots()
  local root = M.root()
  local ok, group = pcall(require, "user.projects.group")
  if not ok then
    return { root }
  end
  local _, members = group.group(root)
  if type(members) ~= "table" or #members == 0 then
    return { root }
  end
  return members
end

--- Tutti i task del progetto — o del gruppo di progetti fratelli — uniti e dedup.
--- Con più membri i nomi sono prefissati da `[nome-membro]` (job CONDIVISI tra
--- fratelli) e la cwd è risolta assoluta contro il rispettivo membro, così ogni
--- job parte nella propria cartella. Passando `root` esplicita si forza il singolo
--- progetto (usato da :checkhealth).
function M.collect(root)
  if root then
    return collect_one(root)
  end
  local roots = M.roots()
  if #roots <= 1 then
    return collect_one(roots[1] or M.root())
  end
  local seen, result = {}, {}
  for _, r in ipairs(roots) do
    local label = vim.fs.basename(r)
    for _, task in ipairs(collect_one(r)) do
      local name = ("[%s] %s"):format(label, task.name)
      if not seen[name] then
        seen[name] = true
        task.name = name
        task.cwd = M.resolve_cwd(task.cwd, r) -- assoluta: il job parte nel suo membro
        task.root = r
        result[#result + 1] = task
      end
    end
  end
  return result
end

return M
