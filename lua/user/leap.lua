local M = {
  "ggandor/leap.nvim",
  opts = {
    special_keys = {
      prev_target = "<bs>",
      prev_group = "<bs>"
    }
  },
  event = "VeryLazy",
  keys = {
    { "s",  "<Plug>(leap-forward-to)",  mode = { "n", "x", "o" }, desc = "Leap forward" },
    { "S",  "<Plug>(leap-backward-to)", mode = { "n", "x", "o" }, desc = "Leap backward" },
    { "gs", "<Plug>(leap-from-window)", mode = { "n", "x", "o" }, desc = "Leap from window" },
  }
}

function M.config()
  -- require("leap").create_default_mappings()
  require('leap.user').set_repeat_keys('<cr>', '<bs>')
end

return M