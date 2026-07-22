-- Gestione progetti nativa, rimpiazzo di ahmedkhalf/project.nvim (abbandonato dal 2023).
-- Due funzioni che il plugin dava e qui replichiamo senza dipendenze:
--   1. auto-chdir alla root del progetto del buffer corrente (vim.fs.root sui pattern);
--   2. history dei progetti visitati su file + picker telescope (M.pick).
-- projects/group.lua (gruppi di progetti fratelli) è indipendente e resta invariato.

local M = {}

-- Marker di root: quelli che usava project.nvim, più Cargo.toml/go.mod
-- (questa config supporta Rust e Go: rust_analyzer/neotest-rust, gopls).
local PATTERNS =
  { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json", "pom.xml", "Cargo.toml", "go.mod" }
local HISTORY = vim.fs.normalize(vim.fn.stdpath "data" .. "/project_history")
local MAX = 100

local function read_history()
  local f = io.open(HISTORY, "r")
  if not f then
    return {}
  end
  local list = {}
  for line in f:lines() do
    line = vim.trim(line)
    if line ~= "" then
      list[#list + 1] = line
    end
  end
  f:close()
  return list
end

local function write_history(list)
  local f = io.open(HISTORY, "w")
  if not f then
    return
  end
  f:write(table.concat(list, "\n"))
  f:close()
end

-- Promuove `root` in cima alla history (dedup, cap a MAX).
local function record(root)
  root = vim.fs.normalize(root)
  local out = { root }
  for _, p in ipairs(read_history()) do
    if vim.fs.normalize(p) ~= root then
      out[#out + 1] = p
    end
  end
  while #out > MAX do
    out[#out] = nil
  end
  write_history(out)
end

-- Root del progetto per un buffer su file reale, o nil.
local function project_root(buf)
  if vim.bo[buf].buftype ~= "" then
    return nil
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return nil
  end
  return vim.fs.root(name, PATTERNS)
end

-- Auto-chdir globale silenzioso alla root, registrandola nella history.
local function chdir_to_root(buf)
  local root = project_root(buf)
  if not root then
    return
  end
  if vim.fs.normalize(vim.fn.getcwd()) ~= vim.fs.normalize(root) then
    vim.cmd.cd(vim.fn.fnameescape(root))
  end
  record(root)
end

function M.setup()
  local grp = vim.api.nvim_create_augroup("user_projects", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost" }, {
    group = grp,
    callback = function(ev)
      chdir_to_root(ev.buf)
    end,
  })
  -- buffer iniziale (file passato come argomento a nvim)
  vim.schedule(function()
    chdir_to_root(vim.api.nvim_get_current_buf())
  end)
  vim.keymap.set("n", "<c-p>", M.pick, { noremap = true, silent = true, desc = "Projects" })

  -- Regola on_open: aprire un file *.workspace (formato VSCode) ATTIVA quel workspace.
  -- Da lì ricerca file/testo (telescope + alpha, via group.search_dirs), nvim-tree e la
  -- cwd vedono TUTTE le cartelle del workspace, non solo il progetto sotto la cwd.
  -- Il motore generico sta in user/on_open.lua; lo stato/parse in projects/group.lua.
  local ok_on_open, on_open = pcall(require, "user.on_open")
  if ok_on_open then
    on_open.add {
      name = "workspace",
      when = function(ev)
        return require("user.projects.group").is_workspace_file(ev.name)
      end,
      action = function(ev)
        local pg = require "user.projects.group"
        local parent = pg.activate(ev.name)
        if not parent then
          vim.notify("Workspace senza cartelle valide: " .. vim.fs.basename(ev.name), vim.log.levels.WARN)
          return
        end
        local n = #pg.active.members
        -- cwd + nvim-tree sul workspace, dopo che gli altri handler d'apertura (es.
        -- l'auto-chdir qui sopra) si sono assestati, così non vengono sovrascritti.
        vim.schedule(function()
          if vim.fn.isdirectory(parent) == 1 then
            pcall(vim.cmd.cd, vim.fn.fnameescape(parent))
            record(parent)
          end
          pg.focus_tree()
          vim.notify(
            ("Workspace %s: %d progetti visibili a ricerca/alpha"):format(vim.fs.basename(ev.name), n),
            vim.log.levels.INFO
          )
        end)
      end,
    }
  end
end

-- Picker telescope dei progetti recenti (rimpiazzo di extensions.projects.projects).
-- Selezione: cd alla root + find_files in quella dir.
function M.pick()
  local existing = {}
  for _, p in ipairs(read_history()) do
    if vim.fn.isdirectory(vim.fs.normalize(p)) == 1 then
      existing[#existing + 1] = p
    end
  end
  if #existing == 0 then
    vim.notify("Nessun progetto in history", vim.log.levels.INFO)
    return
  end
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  pickers
    .new({}, {
      prompt_title = "Projects",
      finder = finders.new_table { results = existing },
      sorter = conf.generic_sorter {},
      previewer = false,
      attach_mappings = function(bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(bufnr)
          if entry then
            local dir = vim.fs.normalize(entry[1])
            vim.cmd.cd(vim.fn.fnameescape(dir))
            record(dir)
            require("telescope.builtin").find_files { cwd = dir }
          end
        end)
        return true
      end,
    })
    :find()
end

M.setup()

return M
