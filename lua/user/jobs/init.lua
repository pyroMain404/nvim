-- Job in background per il progetto corrente: web server, loop di compilazione,
-- avvio dell'app. Ogni job è un terminale toggleterm `hidden` avviato con
-- `Terminal:spawn()` — "background job in a buffer without a window": il processo
-- gira senza finestra, l'output resta nel buffer (ispezionabile), `on_exit`
-- aggiorna lo stato. Stessa infrastruttura di user/floatapps, nessuna dipendenza in più.
--
--   * task/lancio:   user/jobs/providers.lua  (da .nvim/tasks.json, lua, .vscode, npm)
--   * UI:            user/jobs/panel.lua       (finestra flottante sotto <leader>o)
--   * stato/health:  :checkhealth user.jobs

local uv = vim.uv or vim.loop
local providers = require "user.jobs.providers"

local M = {}

-- Registro dei job (dal più recente). Ogni record:
--   { id, name, cmd, cwd, source, term, status, code, started, finished }
-- status ∈ "running" | "done" | "failed"
M.jobs = {}
local seq = 0

-- Ravviva il pannello se aperto, così riflette subito i cambi di stato.
local function refresh_panel()
  pcall(function()
    require("user.jobs.panel").refresh()
  end)
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Jobs" })
end

-- Aggiunge `/.nvim/` al .git/info/exclude locale (idempotente), come exclude_bin
-- di jdtls: ignora il nostro file di task nel repo del progetto senza toccare il
-- .gitignore versionato del team.
local function exclude_local_dir(root)
  local git = uv.fs_stat(root .. "/.git")
  if not git or git.type ~= "directory" then
    return
  end
  local path = root .. "/.git/info/exclude"
  local f = io.open(path, "r")
  if f then
    for line in f:lines() do
      if line:match "^/?%.nvim/?$" then
        f:close()
        return
      end
    end
    f:close()
  end
  local out = io.open(path, "a")
  if out then
    out:write "/.nvim/\n"
    out:close()
  end
end

--- Numero di job attualmente in esecuzione (usato dal componente lualine).
function M.running()
  local n = 0
  for _, j in ipairs(M.jobs) do
    if j.status == "running" then
      n = n + 1
    end
  end
  return n
end

-- Keymap sul buffer del job per NASCONDERE il float senza fermare il processo.
-- Necessario perché il terminale cattura il cursore (terminal mode): senza una via
-- d'uscita esplicita si finirebbe per chiudere la finestra e rischiare di uccidere
-- il job. `term:close()` chiude solo la finestra; il buffer `hidden` resta vivo e il
-- processo continua. `<C-q>` (terminal mode) e `q` (dopo <C-\><C-n>) lo nascondono.
local hinted = false
local function set_view_keymaps(record)
  local term = record.term
  if not term or not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr) then
    return
  end
  if record._view_keymaps then
    return
  end
  record._view_keymaps = true
  local buf = term.bufnr
  local function hide()
    vim.cmd "stopinsert"
    term:close()
  end
  local o = { buffer = buf, silent = true, desc = "Job: nascondi (senza fermare)" }
  vim.keymap.set("t", "<C-q>", hide, o)
  vim.keymap.set("n", "q", hide, o)
end

--- Avvia un task { name, cmd, cwd?, source? } come job in background. Ritorna il record.
function M.launch(task)
  if type(task) ~= "table" or type(task.cmd) ~= "string" then
    return
  end
  local root = providers.root()
  local cwd = providers.resolve_cwd(task.cwd, root)

  seq = seq + 1
  local record = {
    id = seq,
    name = task.name or task.cmd,
    cmd = task.cmd,
    cwd = cwd,
    source = task.source or "ad-hoc",
    status = "running",
    started = os.time(),
  }

  local Terminal = require("toggleterm.terminal").Terminal
  record.term = Terminal:new {
    cmd = task.cmd,
    dir = cwd,
    hidden = true, -- fuori dalla lista globale di toggleterm: teniamo noi il registro
    close_on_exit = false, -- il buffer sopravvive all'uscita: output ispezionabile
    on_exit = function(_, _, code)
      record.status = (code == 0) and "done" or "failed"
      record.code = code
      record.finished = os.time()
      local msg = ("%s — %s (exit %d)"):format(record.name, record.status == "done" and "terminato" or "FALLITO", code)
      notify(msg, code == 0 and vim.log.levels.INFO or vim.log.levels.WARN)
      refresh_panel()
    end,
  }
  record.term:spawn()
  set_view_keymaps(record)

  table.insert(M.jobs, 1, record)
  notify(("avviato: %s"):format(record.name))
  refresh_panel()
  return record
end

-- Trova un record per id.
function M.get(id)
  for _, j in ipairs(M.jobs) do
    if j.id == id then
      return j
    end
  end
end

-- Il buffer del terminale è ancora valido? (dopo uno stop+rimozione può non esserlo)
local function term_alive(record)
  local t = record.term
  return t and t.bufnr and vim.api.nvim_buf_is_valid(t.bufnr)
end

--- Mostra/nasconde il terminale di un job in un float (output live o finale).
function M.toggle_view(record)
  if not term_alive(record) then
    notify("nessun output da mostrare per " .. record.name, vim.log.levels.WARN)
    return
  end
  record.term:toggle(nil, "float")
  set_view_keymaps(record)
  if not hinted then
    hinted = true
    notify "Nel terminale del job: <C-q> nasconde la finestra senza fermarlo (o <C-\\><C-n> poi 'q')."
  end
end

--- Ferma un job in esecuzione (SIGTERM al processo); on_exit aggiorna lo stato.
function M.stop(record)
  if record.status ~= "running" then
    return
  end
  local job_id = record.term and record.term.job_id
  if job_id then
    pcall(vim.fn.jobstop, job_id)
  end
end

--- Rimuove un job dal registro (fermandolo se attivo) e ne elimina il buffer.
function M.remove(record)
  M.stop(record)
  if term_alive(record) then
    pcall(vim.api.nvim_buf_delete, record.term.bufnr, { force = true })
  end
  for i, j in ipairs(M.jobs) do
    if j.id == record.id then
      table.remove(M.jobs, i)
      break
    end
  end
  refresh_panel()
end

--- Rilancia un job con lo stesso comando (fermando prima quello vecchio).
function M.relaunch(record)
  M.remove(record)
  return M.launch { name = record.name, cmd = record.cmd, cwd = record.cwd, source = record.source }
end

--- Rimuove tutti i job non più in esecuzione.
function M.clear_finished()
  for i = #M.jobs, 1, -1 do
    local j = M.jobs[i]
    if j.status ~= "running" then
      if term_alive(j) then
        pcall(vim.api.nvim_buf_delete, j.term.bufnr, { force = true })
      end
      table.remove(M.jobs, i)
    end
  end
  refresh_panel()
end

--- Apre (creandolo da template se assente) il file di task locale del progetto.
function M.edit_local_tasks()
  local cfg = require "user.jobs.config"
  local root = providers.root()
  local path = root .. "/" .. cfg.local_file
  if not uv.fs_stat(path) then
    local dir = vim.fs.dirname(path)
    vim.fn.mkdir(dir, "p")
    exclude_local_dir(root)
    local template = [[{
  "tasks": [
    { "name": "", "cmd": "" }
  ]
}
]]
    local f = io.open(path, "w")
    if f then
      f:write(template)
      f:close()
    end
  else
    exclude_local_dir(root) -- garantisce l'esclusione anche su file preesistenti
  end
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

-- Lancio rapido: scelta di un task del progetto via vim.ui.select.
local function quick_launch()
  local tasks = providers.collect()
  if #tasks == 0 then
    notify("nessun task per questo progetto — premi <leader>oo poi 'e' per crearne uno", vim.log.levels.WARN)
    return
  end
  vim.ui.select(tasks, {
    prompt = "Lancia task:",
    format_item = function(t)
      return ("%-28s  %s  [%s]"):format(t.name, t.cmd, t.source)
    end,
  }, function(choice)
    if choice then
      M.launch(choice)
    end
  end)
end

--- Registra i keymap sotto <leader>o. Chiamata dal config di toggleterm (VeryLazy),
--- così toggleterm è già disponibile quando si preme la scorciatoia.
function M.setup()
  vim.keymap.set("n", "<leader>oo", function()
    require("user.jobs.panel").open()
  end, { desc = "Job: pannello", noremap = true, silent = true })

  vim.keymap.set("n", "<leader>or", quick_launch, { desc = "Job: lancia task", noremap = true, silent = true })
end

return M
