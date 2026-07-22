local M = {
  "nvim-tree/nvim-tree.lua",
  event = "VeryLazy",
}

-- Apri nvim-tree quando nvim viene lanciato su una directory (es. `nvim .` o
-- `nvim <cartella>`). Registrato in `init` (che lazy esegue all'avvio) e NON in
-- `config`: quest'ultimo gira su VeryLazy, cioè DOPO VimEnter, quindi l'autocmd
-- non esisterebbe ancora allo scatto. Con `hijack_netrw = false` è netrw a
-- renderizzare il buffer-directory: lo sostituiamo con un buffer vuoto e apriamo
-- il tree, così il layout resta pulito (tree + buffer vuoto) senza il doppione
-- netrw. `require("nvim-tree.api")` forza lazy a caricare il plugin (ed eseguire
-- M.config/setup) prima dell'apertura.
function M.init()
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function(data)
      if vim.fn.isdirectory(data.file) ~= 1 then
        return
      end
      vim.cmd.cd(vim.fn.fnameescape(data.file))
      vim.cmd.enew()
      if vim.api.nvim_buf_is_valid(data.buf) then
        pcall(vim.api.nvim_buf_delete, data.buf, { force = true })
      end
      require("nvim-tree.api").tree.open()
    end,
  })
end

function M.config()
  local pg = require "user.projects.group"

  local wk = require "which-key"
  wk.add {
    { "<leader>e", "<cmd>NvimTreeToggle<CR>", desc = "Explorer" },
    { "<leader>E", pg.toggle_tree, desc = "Explorer (gruppo progetti)" },
  }

  -- Al resize del terminale la funzione width NON viene rivalutata da sola per
  -- un tree già aperto. api.tree.resize() senza argomenti resetta la width ai
  -- valori di config (la nostra funzione columns/3) e riapplica; è innocuo se il
  -- tree è chiuso (il view.resize interno esce subito quando non è visibile).
  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      require("nvim-tree.api").tree.resize()
    end,
  })

  local icons = require "user.icons"

  require("nvim-tree").setup {
    hijack_netrw = false,
    sync_root_with_cwd = true,
    view = {
      relativenumber = true,
      -- larghezza = 1/3 delle colonne del terminale (rivalutata a ogni apertura)
      width = function()
        return math.floor(vim.o.columns / 3)
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
