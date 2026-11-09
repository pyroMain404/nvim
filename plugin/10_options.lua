-- ┌──────────────────────────┐
-- │ Built-in Neovim behavior │
-- └──────────────────────────┘

-- stylua: ignore start

-- General ====================================================================
vim.g.mapleader = ' ' -- Use `<Space>` as <Leader> key

vim.o.mousescroll = 'ver:25,hor:6' -- Customize mouse scroll
vim.o.switchbuf   = 'usetab'       -- Use already opened buffers when switching

vim.o.path = require('config.path').default

vim.o.shada = "'100,<50,s10,:1000,/100,@100,h" -- Limit ShaDa file (for startup)

-- Copy to the system clipboard with OSC 52, paste from it with `win32yank.exe`.
-- HACK: the stock provider copies through a detached `win32yank.exe` whose console window
-- flashes on every yank to `+` (neovim/neovim#25928, nvim v0.12.5, locked 2026-11-06, not
-- retested). OSC 52 starts no process; pasting stays on `win32yank.exe -o`, run by
-- `system()` as in the stock provider, because Windows Terminal never answers the OSC 52
-- read query and `"+p` would wait 10 s.
local osc52 = require('vim.ui.clipboard.osc52')
local win32yank_paste = { 'win32yank.exe', '-o', '--lf' }
vim.g.clipboard = {
  name = 'OSC 52 copy, win32yank paste',
  copy = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
  paste = { ['+'] = win32yank_paste, ['*'] = win32yank_paste },
}

-- PowerShell 7 for `:!`, `:make`, `system()` and the terminal.
-- NOTE: `shellquote`/`shellxquote` are cleared (`pwsh -Command` parses its own
-- argument); `shellpipe`/`shellredir` write UTF8, UTF-16LE would corrupt quickfix.
-- `-NonInteractive`: `system('echo')` (`:checkhealth`) makes pwsh prompt for input.
if vim.fn.has('win32') == 1 then
  vim.o.shell = 'pwsh'
  vim.o.shellcmdflag = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -Command'
  vim.o.shellredir = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode'
  vim.o.shellpipe = '2>&1 | Tee-Object %s; exit $LastExitCode'
  vim.o.shellquote = ''
  vim.o.shellxquote = ''

  -- HACK: Nvim on Windows starts with `v:ctype` = 'C' when $LANG is unset, which
  -- `:checkhealth` reports as an error (nvim v0.12.6, locked 2026-11-01, not retested).
  vim.cmd.language('ctype', 'en_US.UTF-8')
end

-- UI =========================================================================
vim.o.breakindentopt = 'list:-1'  -- Add padding for lists (if 'wrap' is set)
vim.o.colorcolumn    = '+1'       -- Draw column on the right of maximum width
vim.o.list           = true       -- Show helpful text indicators
vim.o.pumborder      = 'single'   -- Use border in popup menu
vim.o.pumheight      = 10         -- Make popup menu smaller
vim.o.pummaxwidth    = 100        -- Make popup menu not too wide
vim.o.shortmess      = 'CFOSWaco' -- Disable some built-in completion messages
vim.o.smoothscroll   = true       -- Scroll by screen line, not by whole wrapped line
vim.o.winborder      = 'single'   -- Use border in floating windows

vim.o.cursorlineopt  = 'screenline,number' -- Show cursor line per screen line

vim.o.fillchars = 'eob: ,fold:╌'
vim.o.listchars = 'extends:…,nbsp:␣,precedes:…,tab:> '

vim.o.foldlevel   = 10       -- Fold nothing by default; set to 0 or 1 to fold
vim.o.foldmethod  = 'indent' -- Fold based on indent level
vim.o.foldnestmax = 10       -- Limit number of fold levels
vim.o.foldtext    = ''       -- Show text under fold with its highlighting

-- Editing ====================================================================
vim.o.expandtab     = true    -- Convert tabs to spaces
vim.o.formatoptions = 'rqnl1j'-- Improve comment editing
vim.o.shiftwidth    = 2       -- Use this number of spaces for indentation
vim.o.spelloptions  = 'camel' -- Treat camelCase word parts as separate words
vim.o.tabstop       = 2       -- Show tab as this number of spaces

-- Spell checking (`:h 'spellfile'`): `zg` adds to the English file, `2zg` to the Italian one.
local spell_dir = vim.fn.stdpath('config') .. '/spell'
vim.o.spelllang = 'en,it'
vim.o.spellfile = spell_dir .. '/en.utf-8.add,' .. spell_dir .. '/it.utf-8.add'

vim.o.iskeyword = '@,48-57,_,192-255,-' -- Treat dash as `word` textobject part

vim.o.formatlistpat = [[^\s*[0-9\-\+\*]\+[\.\)]*\s\+]]

vim.o.complete        = '.,w,b,kspell'                  -- Use less sources
vim.o.completeopt     = 'menuone,noselect,fuzzy,nosort' -- Use custom behavior
vim.o.completetimeout = 100                             -- Limit sources delay

-- Autocommands ===============================================================

-- NOTE: set on `FileType` so filetype plugins cannot override it.
Config.new_autocmd('FileType', nil, function()
  vim.cmd('setlocal formatoptions-=c formatoptions-=o')
end, "Proper 'formatoptions'")

-- Diagnostics ================================================================

local diagnostic_opts = {
  signs = { priority = 9999, severity = { min = 'WARN', max = 'ERROR' } },

  virtual_text = {
    current_line = true,
    severity = { min = 'ERROR', max = 'ERROR' },
  },
}

Config.later(function() vim.diagnostic.config(diagnostic_opts) end)
-- stylua: ignore end
