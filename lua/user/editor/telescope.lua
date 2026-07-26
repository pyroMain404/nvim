local M = {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
}

function M.config()
  local pg = require "user.files.projects.group"
  -- Cerca file/testo anche nei progetti "fratelli" col nome in comune (search_dirs).
  -- search_dirs() usa il separatore nativo: senza, su Windows i path escono come
  -- 'C:/...' e telescope li tratta come URI, saltando filename_first (vedi group.lua).
  local function find_files_group()
    require("telescope.builtin").find_files { search_dirs = pg.search_dirs() }
  end
  local function live_grep_group()
    require("telescope.builtin").live_grep { search_dirs = pg.search_dirs() }
  end

  local wk = require "which-key"
  wk.add {
    { "<leader>bb", "<cmd>Telescope buffers previewer=false<cr>", desc = "Find" },
    { "<leader>fb", "<cmd>Telescope git_branches<cr>", desc = "Checkout branch" },
    { "<leader>fc", "<cmd>Telescope colorscheme<cr>", desc = "Colorscheme" },
    { "<leader>ff", find_files_group, desc = "Find files" },
    { "<leader>fp", "<cmd>lua require('user.files.projects').pick()<cr>", desc = "Projects" },
    { "<leader>ft", live_grep_group, desc = "Find Text" },
    { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help" },
    { "<leader>fl", "<cmd>Telescope resume<cr>", desc = "Last Search" },
    { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent File" },
  }

  local icons = require "user.core.icons"
  local actions = require "telescope.actions"

  -- oldfiles puo' contenere path salvati con '/' (es. 'C:/...') che telescope vede
  -- come URI (utils.is_uri), saltando path_display/filename_first. Normalizziamo al
  -- separatore nativo prima di costruire la entry, cosi' agiscono su tutti i recenti.
  local sep = package.config:sub(1, 1)
  local oldfiles_maker = (function()
    local base = require("telescope.make_entry").gen_from_file {}
    if sep == "/" then
      return base
    end
    return function(line)
      return base((line:gsub("/", sep)))
    end
  end)()

  require("telescope").setup {
    defaults = {
      prompt_prefix = icons.ui.Telescope .. " ",
      selection_caret = icons.ui.Forward .. " ",
      entry_prefix = "   ",
      initial_mode = "insert",
      selection_strategy = "reset",
      path_display = { "filename_first" },
      color_devicons = true,
      vimgrep_arguments = {
        "rg",
        "--color=never",
        "--no-heading",
        "--with-filename",
        "--line-number",
        "--column",
        "--smart-case",
        "--hidden",
        "--glob=!.git/",
      },

      mappings = {
        i = {
          ["<C-n>"] = actions.cycle_history_next,
          ["<C-p>"] = actions.cycle_history_prev,

          ["<C-j>"] = actions.move_selection_next,
          ["<C-k>"] = actions.move_selection_previous,
        },
        n = {
          ["<esc>"] = actions.close,
          ["j"] = actions.move_selection_next,
          ["k"] = actions.move_selection_previous,
          ["<C-j>"] = actions.move_selection_next,
          ["<C-k>"] = actions.move_selection_previous,
          ["q"] = actions.close,
        },
      },
    },
    pickers = {
      live_grep = {
        theme = "dropdown",
      },

      grep_string = {
        theme = "dropdown",
      },

      find_files = {
        theme = "dropdown",
        previewer = false,
      },

      oldfiles = {
        entry_maker = oldfiles_maker,
        initial_mode = "normal",
      },

      buffers = {
        theme = "dropdown",
        previewer = false,
        initial_mode = "normal",
        mappings = {
          i = {
            ["<C-d>"] = actions.delete_buffer,
          },
          n = {
            ["dd"] = actions.delete_buffer,
          },
        },
      },

      planets = {
        show_pluto = true,
        show_moon = true,
      },

      colorscheme = {
        enable_preview = true,
      },

      lsp_references = {
        theme = "dropdown",
        initial_mode = "normal",
      },

      lsp_definitions = {
        theme = "dropdown",
        initial_mode = "normal",
      },

      lsp_declarations = {
        theme = "dropdown",
        initial_mode = "normal",
      },

      lsp_implementations = {
        theme = "dropdown",
        initial_mode = "normal",
      },
    },
  }
end

return M
