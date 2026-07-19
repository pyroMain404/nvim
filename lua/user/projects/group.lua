-- Raggruppa i progetti "fratelli" con nome in comune nella directory padre.
-- Es: dalla cwd 'piano-privacy-fe' ricava il prefisso 'piano-privacy' e include
-- tutti i fratelli 'piano-privacy-*' (be, db, ...), escludendo 'riesame-privacy-*'.
-- Usato da telescope (search_dirs) e da nvim-tree (vista di gruppo a richiesta).

local M = {}

-- Stato della vista di gruppo di nvim-tree; nil = disattiva (comportamento normale).
M.tree_parent = nil ---@type string|nil
M.tree_set = nil ---@type table<string, boolean>|nil

-- Prefisso comune: nome cartella senza l'ultimo -segmento, o nil se assente.
local function prefix_of(name)
  return name:match "^(.+)%-[^%-]+$"
end

-- Ritorna: parent (assoluto normalizzato), lista membri (assoluti), set membri.
-- Se la cartella non ha un -suffisso o non ha fratelli, il gruppo è la sola cwd.
function M.group(dir)
  dir = vim.fs.normalize(dir or vim.fn.getcwd())
  local parent = vim.fs.dirname(dir)
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
