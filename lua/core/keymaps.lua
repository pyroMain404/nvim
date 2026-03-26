local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Preserve C-i (separate from Tab)
map("n", "<C-i>", "<C-i>", opts)

-- Window navigation (Alt+hjkl, overridden by smart-splits when loaded)
map("n", "<M-h>", "<C-w>h", { desc = "Window left" })
map("n", "<M-j>", "<C-w>j", { desc = "Window down" })
map("n", "<M-k>", "<C-w>k", { desc = "Window up" })
map("n", "<M-l>", "<C-w>l", { desc = "Window right" })
map("n", "<M-Tab>", "<C-6>", { desc = "Alternate buffer" })

-- Centered search navigation
map("n", "n", "nzzzv", opts)
map("n", "N", "Nzzzv", opts)
map("n", "*", "*zz", opts)
map("n", "#", "#zz", opts)
map("n", "g*", "g*zz", opts)
map("n", "g#", "g#zz", opts)

-- Stay in indent mode
map("v", "<", "<gv", opts)
map("v", ">", ">gv", opts)

-- Paste without yanking in visual mode
map("x", "p", [["_dP]], opts)

-- Line start/end (Shift-H / Shift-L)
map({ "n", "o", "x" }, "<S-h>", "^", opts)
map({ "n", "o", "x" }, "<S-l>", "g_", opts)

-- Visual line movement (for wrapped lines)
map({ "n", "x" }, "j", "gj", opts)
map({ "n", "x" }, "k", "gk", opts)

-- Toggle wrap
map("n", "<leader>uw", function()
  vim.wo.wrap = not vim.wo.wrap
  vim.notify("Wrap: " .. tostring(vim.wo.wrap))
end, { desc = "Toggle wrap" })

-- Terminal escape
map("t", "<C-;>", "<C-\\><C-n>", opts)

-- Buffer navigation
map("n", "<S-Tab>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<Tab>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

-- Move lines
map("n", "<A-j>", "<cmd>m .+1<CR>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<CR>==", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search" })

-- Save
map("n", "<leader>fs", "<cmd>w<CR>", { desc = "Save file" })

-- Quit
map("n", "<leader>qq", "<cmd>qa<CR>", { desc = "Quit all" })
