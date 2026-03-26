return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    -- Modules enabled at startup
    bigfile = { enabled = true },
    quickfile = { enabled = true },
    notifier = { enabled = true, timeout = 3000 },
    statuscolumn = { enabled = true },
    words = { enabled = true },

    -- Dashboard
    dashboard = {
      enabled = true,
      preset = {
        keys = {
          { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.picker.files()" },
          { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.picker.grep()" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.picker.recent()" },
          { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.picker.files({ cwd = vim.fn.stdpath('config') })" },
          { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
    },

    -- Picker (replaces telescope/fzf-lua)
    picker = { enabled = true },

    -- Input (used by avante.nvim)
    input = { enabled = true },

    -- Indent guides
    indent = {
      enabled = true,
      animate = { enabled = false },
    },

    -- Scroll animation
    scroll = {
      enabled = true,
      animate = { duration = { step = 15, total = 150 } },
    },
  },
  keys = {
    -- Picker
    { "<leader>ff", function() Snacks.picker.files() end, desc = "Find files" },
    { "<leader>fg", function() Snacks.picker.grep() end, desc = "Grep" },
    { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>fh", function() Snacks.picker.help() end, desc = "Help" },
    { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent files" },
    { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Config files" },
    { "<leader>fw", function() Snacks.picker.grep_word() end, desc = "Grep word", mode = { "n", "x" } },

    -- LSP Picker
    { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Go to definition" },
    { "gr", function() Snacks.picker.lsp_references() end, desc = "References" },
    { "gI", function() Snacks.picker.lsp_implementations() end, desc = "Implementations" },
    { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Type definitions" },
    { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "LSP symbols" },

    -- Git
    { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git log" },
    { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git status" },

    -- Notifications
    { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss notifications" },

    -- Terminal
    { "<C-/>", function() Snacks.terminal() end, desc = "Toggle terminal" },

    -- Explorer
    { "<leader>e", function() Snacks.explorer() end, desc = "File explorer" },
  },
}
