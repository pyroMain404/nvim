return {
  "mrjones2014/smart-splits.nvim",
  lazy = false, -- Must load eagerly for Tmux @pane-is-vim detection
  opts = {
    ignored_buftypes = { "nofile", "quickfix", "prompt" },
    ignored_filetypes = { "NvimTree" },
  },
  keys = {
    -- Navigation (overrides Alt+hjkl from core keymaps)
    { "<M-h>", function() require("smart-splits").move_cursor_left() end, desc = "Move to left split" },
    { "<M-j>", function() require("smart-splits").move_cursor_down() end, desc = "Move to below split" },
    { "<M-k>", function() require("smart-splits").move_cursor_up() end, desc = "Move to above split" },
    { "<M-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move to right split" },
    -- Resizing
    { "<C-Left>", function() require("smart-splits").resize_left() end, desc = "Resize left" },
    { "<C-Down>", function() require("smart-splits").resize_down() end, desc = "Resize down" },
    { "<C-Up>", function() require("smart-splits").resize_up() end, desc = "Resize up" },
    { "<C-Right>", function() require("smart-splits").resize_right() end, desc = "Resize right" },
  },
}
