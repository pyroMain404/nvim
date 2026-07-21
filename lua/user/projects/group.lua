-- Raggruppa i progetti "fratelli" della directory padre. Due criteri, in ordine:
--   1. un file <nome>.code-workspace / <nome>.workspace (formato VSCode) nella dir
--      padre che elenca `dir` tra le sue "folders" → gruppo = quelle cartelle
--      (copre anche fratelli con nomi non correlati, es. agent-docs + iet-ng-lib);
--   2. altrimenti l'euristica del prefisso: dalla cwd 'piano-privacy-fe' ricava
--      'piano-privacy' e include tutti i 'piano-privacy-*' (be, db, ...).
-- Usato da telescope (search_dirs), da nvim-tree (vista di gruppo a richiesta) e da
-- user/jobs (job condivisi tra i membri del gruppo).

local fs = require "user.util.fs"

local M = {}

-- Stato della vista di gruppo di nvim-tree; nil = disattiva (comportamento normale).
M.tree_parent = nil ---@type string|nil
M.tree_set = nil ---@type table<string, boolean>|nil

-- Prefisso comune: nome cartella senza l'ultimo -segmento, o nil se assente.
local function prefix_of(name)
  return name:match "^(.+)%-[^%-]+$"
end

-- Un file di workspace stile VSCode: <nome>.code-workspace o <nome>.workspace.
local function is_workspace_file(name)
  return name:match "%.code%-workspace$" ~= nil or name:match "%.workspace$" ~= nil
end

-- Cartelle membro dichiarate in un file workspace (formato VSCode:
-- { "folders": [ { "path": "..." }, ... ] }, JSONC). I path sono relativi a `base`
-- (la dir del file). Ritorna lista di path assoluti normalizzati (solo esistenti).
local function workspace_members(file, base)
  local decoded = require("user.util.jsonc").decode(fs.read_file(file))
  if type(decoded) ~= "table" or type(decoded.folders) ~= "table" then
    return {}
  end
  local members = {}
  for _, f in ipairs(decoded.folders) do
    local p = type(f) == "table" and f.path or nil
    if type(p) == "string" and p ~= "" then
      local full = fs.is_absolute(p) and vim.fs.normalize(p) or vim.fs.normalize(base .. "/" .. p)
      if vim.fn.isdirectory(full) == 1 then
        members[#members + 1] = full
      end
    end
  end
  return members
end

-- Gruppo definito da un file *.code-workspace/*.workspace nella dir padre che elenca
-- `dir` tra le sue cartelle. Ritorna parent, membri, set — o nil se nessun file
-- pertinente (si ricade sull'euristica del prefisso). Ha priorità sul prefisso:
-- copre anche fratelli con nomi non correlati (es. agent-docs + iet-ng-lib).
local function workspace_group(dir, parent)
  local ok, iter = pcall(vim.fs.dir, parent)
  if not ok then
    return nil
  end
  local files = {}
  for entry, typ in iter do
    if typ == "file" and is_workspace_file(entry) then
      files[#files + 1] = entry
    end
  end
  table.sort(files) -- determinismo se più file workspace nella stessa dir
  for _, entry in ipairs(files) do
    local members = workspace_members(parent .. "/" .. entry, parent)
    local set = {}
    for _, m in ipairs(members) do
      set[m] = true
    end
    if set[dir] then
      table.sort(members)
      return parent, members, set
    end
  end
  return nil
end

-- Ritorna: parent (assoluto normalizzato), lista membri (assoluti), set membri.
-- Priorità: un file workspace che elenca `dir`; altrimenti l'euristica del prefisso
-- (fratelli con lo stesso nome meno l'ultimo -segmento). Se nessuna delle due dà
-- fratelli, il gruppo è la sola cwd.
function M.group(dir)
  dir = vim.fs.normalize(dir or vim.fn.getcwd())
  local parent = vim.fs.dirname(dir)
  if parent and parent ~= dir then
    local wp, wm, ws = workspace_group(dir, parent)
    if wp then
      return wp, wm, ws
    end
  end
  local name = vim.fs.basename(dir)
  local prefix = prefix_of(name)
  if not prefix or not parent or parent == dir then
    return parent, { dir }, { [dir] = true }
  end
  local members, set = {}, {}
  local ok, iter = pcall(vim.fs.dir, parent)
  if ok then
    for entry, typ in iter do
      if typ == "directory" and (entry == prefix or entry:sub(1, #prefix + 1) == prefix .. "-") then
        local full = vim.fs.normalize(parent .. "/" .. entry)
        table.insert(members, full)
        set[full] = true
      end
    end
  end
  -- Fallback difensivo: garantisci sempre la presenza della cwd.
  if not set[dir] then
    table.insert(members, dir)
    set[dir] = true
  end
  table.sort(members)
  return parent, members, set
end

-- Elenco di directory per telescope `search_dirs` (sempre >= 1 elemento).
-- Path normalizzati a '/' (vim.fs.normalize).
function M.dirs()
  local _, members = M.group()
  return members
end

-- Come dirs(), ma col separatore nativo dell'OS. Serve a telescope: su Windows rg
-- ripete il separatore della dir base, e con '/' i risultati escono come 'C:/...'
-- che telescope classifica come URI (utils.is_uri) saltando path_display
-- (filename_first). Col separatore '\' i path restano 'C:\...' (non-URI) e agisce.
-- Su OS con separatore '/' e' un no-op.
function M.search_dirs()
  local sep = package.config:sub(1, 1)
  local dirs = M.dirs()
  if sep ~= "/" then
    for i, d in ipairs(dirs) do
      dirs[i] = d:gsub("/", sep)
    end
  end
  return dirs
end

-- Filtro custom di nvim-tree: ritorna true per NASCONDERE il path.
-- Nasconde solo i figli diretti della parent che non sono membri del gruppo;
-- i file dentro i progetti membri (più profondi) non vengono mai filtrati.
function M.filter(abs)
  local parent = M.tree_parent
  if not parent then
    return false
  end
  abs = vim.fs.normalize(abs)
  local prefix = parent .. "/"
  if abs:sub(1, #prefix) ~= prefix then
    return false
  end
  local rest = abs:sub(#prefix + 1)
  if rest:find "/" then
    return false -- più profondo di un figlio diretto: mostralo
  end
  return not M.tree_set[abs]
end

-- Attiva/disattiva la vista di gruppo di nvim-tree.
-- ON: root = parent, mostra solo i progetti del gruppo. OFF: torna alla cwd.
function M.toggle_tree()
  local api = require "nvim-tree.api"
  local cwd = vim.fs.normalize(vim.fn.getcwd())
  if M.tree_parent then
    M.tree_parent, M.tree_set = nil, nil
    api.tree.change_root(cwd)
    api.tree.reload()
    return
  end
  local parent, members, set = M.group(cwd)
  if #members <= 1 then
    vim.notify("Nessun progetto fratello per " .. vim.fs.basename(cwd), vim.log.levels.INFO)
    api.tree.open()
    return
  end
  M.tree_parent, M.tree_set = parent, set
  api.tree.change_root(parent)
  api.tree.open()
  api.tree.reload()
end

return M
