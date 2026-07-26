local M = {
  "nvim-tree/nvim-tree.lua",
  event = "VeryLazy",
}

-- Con netrw disabilitato (vedi options.lua) e `hijack_netrw = true`, è nvim-tree
-- stesso a dirottare i buffer-directory (hijack_directories) e ad aprirsi al
-- loro posto quando nvim è lanciato su una cartella (es. `nvim .`). Il suo
-- autocmd BufEnter viene però registrato dentro setup(), che gira su VeryLazy =
-- DOPO che il buffer-directory di avvio è già stato entrato: troppo tardi. Quindi
-- quando l'argomento è una directory forziamo il caricamento del plugin qui in
-- `init` (che lazy esegue durante il sourcing di init.lua, PRIMA che l'argomento
-- venga aperto), così l'hijack nativo scatta da sé — nessuna apertura manuale.
function M.init()
  local arg = vim.fn.argv(0)
  if type(arg) == "string" and arg ~= "" and vim.fn.isdirectory(arg) == 1 then
    require("lazy").load { plugins = { "nvim-tree.lua" } }
  end
end

function M.config()
  local pg = require "user.files.projects.group"

  local wk = require "which-key"
  wk.add {
    { "<leader>e", "<cmd>NvimTreeToggle<CR>", desc = "Explorer" },
    { "<leader>E", pg.toggle_tree, desc = "Explorer (gruppo progetti)" },
  }

  -- Al resize del terminale la funzione width NON viene rivalutata da sola per
  -- un tree già aperto. api.tree.resize() senza argomenti resetta la width ai
  -- valori di config (la nostra funzione, vedi sotto) e riapplica; è innocuo se
  -- il tree è chiuso (il view.resize interno esce subito quando non è visibile).
  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      require("nvim-tree.api").tree.resize()
    end,
  })

  -- Numero di finestre-editor AFFIANCATE (split verticali) nella tab corrente,
  -- escluso il tree. Cammina l'albero di winlayout(): un nodo "row" dispone i
  -- figli fianco a fianco (:vsplit) → si sommano; un "col" li impila (:split) →
  -- contano come una sola colonna, quindi si prende il massimo. Le finestre
  -- flottanti non compaiono in winlayout. Serve a stringere il tree quando lo
  -- spazio orizzontale è già diviso tra più window.
  local function side_by_side_editors(node)
    node = node or vim.fn.winlayout()
    local kind = node[1]
    if kind == "leaf" then
      local buf = vim.api.nvim_win_get_buf(node[2])
      return vim.bo[buf].filetype == "NvimTree" and 0 or 1
    end
    local total = 0
    for _, child in ipairs(node[2]) do
      local n = side_by_side_editors(child)
      total = kind == "row" and (total + n) or math.max(total, n)
    end
    return total
  end

  local icons = require "user.core.icons"

  require("nvim-tree").setup {
    hijack_netrw = true, -- serve a hijack_directories per aprirsi sui buffer-cartella
    sync_root_with_cwd = true,
    view = {
      relativenumber = true,
      -- Larghezza rivalutata a ogni apertura/resize: 1/5 delle colonne quando ci
      -- sono più finestre-editor affiancate (lo spazio orizzontale è già diviso),
      -- 1/3 altrimenti (tree + singola finestra).
      width = function()
        local divisor = side_by_side_editors() > 1 and 5 or 3
        return math.floor(vim.o.columns / divisor)
      end,
    },
    -- Filtro attivo solo nella vista di gruppo (<leader>eg): nasconde i fratelli
    -- non membri del gruppo. Inattivo (ritorna false) nel resto dei casi.
    filters = {
      custom = pg.filter,
      dotfiles = false, -- mostra i dotfile (default, reso esplicito)
      git_ignored = false, -- mostra anche i file in .gitignore (default: nascosti)
    },
    renderer = {
      add_trailing = false,
      group_empty = false,
      -- Il NOME riflette lo stato git: gli ignorati diventano grigi
      -- (NvimTreeGitFileIgnoredHL -> Comment). Tocca solo i file con stato git,
      -- i puliti restano col colore di default.
      highlight_git = "name",
      full_name = false,
      highlight_opened_files = "none",
      root_folder_label = ":t",
      indent_width = 2,
      indent_markers = {
        enable = false,
        inline_arrows = true,
        icons = {
          corner = "└",
          edge = "│",
          item = "│",
          none = " ",
        },
      },
      icons = {
        git_placement = "before",
        padding = " ",
        symlink_arrow = " ➛ ",
        glyphs = {
          default = icons.ui.Text,
          symlink = icons.ui.FileSymlink,
          bookmark = icons.ui.BookMark,
          folder = {
            arrow_closed = icons.ui.ChevronRight,
            arrow_open = icons.ui.ChevronShortDown,
            default = icons.ui.Folder,
            open = icons.ui.FolderOpen,
            empty = icons.ui.EmptyFolder,
            empty_open = icons.ui.EmptyFolderOpen,
            symlink = icons.ui.FolderSymlink,
            symlink_open = icons.ui.FolderOpen,
          },
          git = {
            unstaged = icons.git.FileUnstaged,
            staged = icons.git.FileStaged,
            unmerged = icons.git.FileUnmerged,
            renamed = icons.git.FileRenamed,
            untracked = icons.git.FileUntracked,
            deleted = icons.git.FileDeleted,
            ignored = "", -- niente icona-prefisso per gli ignorati: bastano grigi (vedi highlight_git)
          },
        },
      },
      special_files = { "Cargo.toml", "Makefile", "README.md", "readme.md" },
      symlink_destination = true,
    },
    -- L'albero NON deve cambiare stato all'apertura di un file: update_focused_file
    -- ri-espande/ri-rootta ad ogni BufEnter ("uncollapsing folders recursively" +
    -- update_root), richiudendo le sottodir aperte a mano. Disabilitato: lo stato
    -- espanso/chiuso resta quello scelto dall'utente. Il re-root al CAMBIO PROGETTO
    -- resta comunque, gestito da sync_root_with_cwd = true (scatta solo su DirChanged,
    -- cioe' quando la cwd cambia = quando l'auto-chdir di user/projects passa progetto).
    update_focused_file = {
      enable = false,
    },

    filesystem_watchers = {
      enable = true,
      debounce_delay = 50,
      -- Alla cancellazione Windows genera una raffica di eventi rename sulla
      -- directory-genitore osservata (ReadDirectoryChangesW "cascades events out
      -- of order", vedi la gestione EPERM in nvim-tree/watcher.lua). Se restano
      -- sotto i 50ms l'uno dall'altro il debounce non flusha mai e il contatore
      -- per-directory supera il default (1000), disarmando il watcher a ogni
      -- delete. E' un burst TRANSITORIO (finisce e torna il silenzio), non un
      -- flusso illimitato tipo rust-analyzer che inonda %TEMP%: alzare la soglia
      -- tollera il rumore benigno senza perdere la protezione contro i runaway.
      max_events = 5000,
      -- sostituisce i default: vanno ripetuti oltre alle aggiunte
      ignore_dirs = {
        "/.ccls-cache",
        "/build",
        "/node_modules",
        "/target",
        "/Temp/rust-analyzer", -- dir temporanee di rust-analyzer in %TEMP%
      },
    },

    diagnostics = {
      enable = true,
      show_on_dirs = false,
      show_on_open_dirs = true,
      debounce_delay = 50,
      severity = {
        min = vim.diagnostic.severity.HINT,
        max = vim.diagnostic.severity.ERROR,
      },
      icons = {
        hint = icons.diagnostics.BoldHint,
        info = icons.diagnostics.BoldInformation,
        warning = icons.diagnostics.BoldWarning,
        error = icons.diagnostics.BoldError,
      },
    },
  }
end

return M
