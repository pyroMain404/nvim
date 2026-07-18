-- Finestra flottante che elenca i job attivi/finiti e i task disponibili del
-- progetto, con i comandi per gestirli. Aperta con <leader>oo.
--
-- Tasti nel pannello:
--   <CR>  su un task → lancialo;  su un job → mostra/nascondi il suo terminale
--   t     mostra/nascondi il terminale del job
--   r     rilancia il job
--   d     ferma e rimuove il job dal registro
--   c     rimuovi tutti i job finiti
--   e     apri/crea .nvim/tasks.json del progetto
--   R     aggiorna la lista
--   q / <Esc>  chiudi

local jobs = require "user.jobs"
local providers = require "user.jobs.providers"

local M = {}

local state = { win = nil, buf = nil, lines_map = {} }
local NS = vim.api.nvim_create_namespace "user_jobs_panel"

local ICON = { running = "▶", done = "✔", failed = "✖" }
local HL = { running = "DiagnosticOk", done = "Comment", failed = "DiagnosticError" }

local function is_open()
  return state.win and vim.api.nvim_win_is_valid(state.win)
end

local function uptime(record)
  local finish = record.finished or os.time()
  local secs = math.max(0, finish - (record.started or finish))
  if secs < 60 then
    return ("%ds"):format(secs)
  elseif secs < 3600 then
    return ("%dm%02ds"):format(math.floor(secs / 60), secs % 60)
  end
  return ("%dh%02dm"):format(math.floor(secs / 3600), math.floor(secs / 60) % 60)
end

-- Costruisce le righe del buffer e la mappa riga→azione. Ritorna lines, highlights.
local function render_lines()
  local lines, hls, map = {}, {}, {}
  local function add(text, hl, item)
    lines[#lines + 1] = text
    map[#lines] = item
    if hl then
      hls[#hls + 1] = { line = #lines - 1, hl = hl }
    end
  end

  add("  Job in background", "Title")
  add("", nil)

  if #jobs.jobs == 0 then
    add("  (nessun job avviato)", "Comment")
  else
    for _, j in ipairs(jobs.jobs) do
      local icon = ICON[j.status] or "•"
      local suffix = j.status == "running" and ("up " .. uptime(j))
        or (("exit %d · %s"):format(j.code or 0, uptime(j)))
      add(("  %s %-24s %s   %s"):format(icon, j.name, j.cmd, suffix), HL[j.status], { job = j })
    end
  end

  add("", nil)
  add("  Task disponibili", "Title")
  add("", nil)
  local tasks = providers.collect()
  if #tasks == 0 then
    add("  (nessun task — premi 'e' per creare .nvim/tasks.json)", "Comment")
  else
    for _, t in ipairs(tasks) do
      add(("  · %-24s %s   [%s]"):format(t.name, t.cmd, t.source), nil, { task = t })
    end
  end

  add("", nil)
  add("  <CR> lancia/mostra · t terminale · r rilancia · d rimuovi · c pulisci · e edit · R refresh · q chiudi", "Comment")
  add("  (nel terminale del job: <C-q> nasconde la finestra senza fermarlo)", "Comment")

  return lines, hls, map
end

local function paint()
  if not is_open() then
    return
  end
  local lines, hls, map = render_lines()
  state.lines_map = map
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)
  for _, h in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(state.buf, NS, h.hl, h.line, 0, -1)
  end
end

-- Aggiorna il pannello se aperto (chiamata da user/jobs/init dopo i cambi di stato).
function M.refresh()
  paint()
end

local function item_under_cursor()
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  return state.lines_map[row]
end

local function on_enter()
  local item = item_under_cursor()
  if not item then
    return
  end
  if item.task then
    jobs.launch(item.task)
  elseif item.job then
    M.close()
    jobs.toggle_view(item.job)
  end
end

local function act(fn)
  return function()
    local item = item_under_cursor()
    if item and item.job then
      fn(item.job)
    end
  end
end

function M.close()
  if is_open() then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

function M.open()
  if is_open() then
    vim.api.nvim_set_current_win(state.win)
    paint()
    return
  end

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].filetype = "jobs-panel"

  local width = math.min(110, math.floor(vim.o.columns * 0.8))
  local height = math.min(24, math.floor(vim.o.lines * 0.7))
  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Jobs ",
    title_pos = "center",
  })
  vim.wo[state.win].cursorline = true

  local function map(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buffer = state.buf, nowait = true, silent = true })
  end
  map("<CR>", on_enter)
  map("t", act(jobs.toggle_view))
  map("r", act(function(j)
    jobs.relaunch(j)
  end))
  map("d", act(jobs.remove))
  map("x", act(jobs.remove))
  map("c", function()
    jobs.clear_finished()
  end)
  map("e", function()
    M.close()
    jobs.edit_local_tasks()
  end)
  map("R", paint)
  map("q", M.close)
  map("<Esc>", M.close)

  paint()
end

return M
