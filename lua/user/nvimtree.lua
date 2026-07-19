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
  -- un tree già aperto. L'API pubblica api.tree.resize() è rotta in questa
  -- versione pinnata (chiama view.configure_width, che non esiste in nvim-tree.view),
  -- quindi si richiama direttamente view.resize(): senza argomenti ricalcola la
  -- width dalla funzione configurata (columns/3).
  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      local view = require "nvim-tree.view"
      if view.is_visible() then
        view.resize()
      end
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
    },
    renderer = {
      add_trailing = false,
      group_empty = false,
      highlight_git = false,
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
            ignored = icons.git.FileIgnored,
          },
        },
      },
      special_files = { "Cargo.toml", "Makefile", "README.md", "readme.md" },
      symlink_destination = true,
    },
    update_focused_file = {
      enable = true,
      debounce_delay = 15,
      update_root = true,
      ignore_list = {},
    },

    filesystem_watchers = {
      enable = true,
      debounce_delay = 50,
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
