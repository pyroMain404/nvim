local M = {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
}

function M.config()
  local pg = require "user.project_group"
  -- Cerca file/testo anche nei progetti "fratelli" col nome in comune (search_dirs).
  local function find_files_group()
    require("telescope.builtin").find_files { search_dirs = pg.dirs() }
  end
  local function live_grep_group()
    require("telescope.builtin").live_grep { search_dirs = pg.dirs() }
  end

  local wk = require "which-key"
  wk.add {
    { "<leader>bb", "<cmd>Telescope buffers previewer=false<cr>", desc = "Find" },
    { "<leader>fb", "<cmd>Telescope git_branches<cr>", desc = "Checkout branch" },
    { "<leader>fc", "<cmd>Telescope colorscheme<cr>", desc = "Colorscheme" },
    { "<leader>ff", find_files_group, desc = "Find files" },
    { "<leader>fp", "<cmd>lua require('telescope').extensions.projects.projects()<cr>", desc = "Projects" },
    { "<leader>ft", live_grep_group, desc = "Find Text" },
    { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help" },
    { "<leader>fl", "<cmd>Telescope resume<cr>", desc = "Last Search" },
    { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent File" },
  }

  local icons = require "user.icons"
  local actions = require "telescope.actions"

  require("telescope").setup {
    defaults = {
      prompt_prefix = icons.ui.Telescope .. " ",
      selection_caret = icons.ui.Forward .. " ",
      entry_prefix = "   ",
      initial_mode = "insert",
      selection_strategy = "reset",
      path_display = { "smart" },
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
