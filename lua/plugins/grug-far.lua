return {
  "MagicDuck/grug-far.nvim",
  cmd = "GrugFar",
  opts = {},
  keys = {
    { "<leader>sr", function() require("grug-far").open() end, desc = "Search and Replace (GrugFar)" },
    {
      "<leader>sw",
      function()
        require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
      end,
      desc = "Search word under cursor",
    },
  },
}
