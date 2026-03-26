local opt = vim.opt

-- Leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Encoding
opt.fileencoding = "utf-8"

-- Clipboard
opt.clipboard = "unnamedplus"

-- Search
opt.hlsearch = true
opt.ignorecase = true
opt.smartcase = true

-- Indentation
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

-- UI
opt.number = true
opt.relativenumber = true
opt.numberwidth = 4
opt.signcolumn = "yes"
opt.cursorline = true
opt.termguicolors = true
opt.showmode = false
opt.showcmd = false
opt.ruler = false
opt.laststatus = 3
opt.cmdheight = 1
opt.pumheight = 10
opt.pumblend = 10
opt.showtabline = 1

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Wrapping
opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Files
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.undofile = true
opt.updatetime = 100
opt.timeoutlen = 300

-- Completion
opt.completeopt = { "menuone", "noselect" }

-- Misc
opt.conceallevel = 0
opt.mouse = "a"
opt.title = false
opt.shortmess:append("c")
opt.fillchars = { eob = " ", stl = " " }

-- Netrw (disabled, using snacks picker)
vim.g.netrw_banner = 0
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Keyword
vim.cmd([[set iskeyword+=-]])
vim.cmd([[set whichwrap+=<,>,[,],h,l]])
