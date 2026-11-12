-- ┌──────────────────────────┐
-- │ Built-in Neovim behavior │
-- └──────────────────────────┘

-- stylua: ignore start

-- General ====================================================================
vim.g.mapleader = ' ' -- Use `<Space>` as the <Leader> key.

vim.o.mousescroll = 'ver:25,hor:6' -- Set mouse scroll distances.
vim.o.switchbuf   = 'usetab'       -- Use open buffers when switching.

vim.o.path = require('config.path').default

vim.o.shada = "'100,<50,s10,:1000,/100,@100,h" -- Limit the ShaDa file for startup.

-- Copy to the system clipboard with OSC 52.
-- Paste from it with `win32yank.exe`.

-- HACK: The stock provider copies through a detached `win32yank.exe`.
-- Its console window flashes on each yank to `+`
-- (neovim/neovim#25928, nvim v0.12.5, locked 2026-11-06, not retested).
--
-- OSC 52 starts no process.
-- `system()` runs `win32yank.exe -o` for paste, as in the stock provider.
-- Windows Terminal never answers the OSC 52 read query, so `"+p` would wait 10 s.
local osc52 = require('vim.ui.clipboard.osc52')
local win32yank_paste = { 'win32yank.exe', '-o', '--lf' }
vim.g.clipboard = {
  name = 'OSC 52 copy, win32yank paste',
  copy = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
  paste = { ['+'] = win32yank_paste, ['*'] = win32yank_paste },
}

-- Use PowerShell 7 for `:!`, `:make`, `system()` and the terminal.
-- NOTE: `pwsh -Command` parses its own argument, so clear `shellquote` and `shellxquote`.
-- `shellpipe` and `shellredir` write UTF8 because UTF-16LE corrupts quickfix.
-- Use `-NonInteractive` because `system('echo')` (`:checkhealth`) makes pwsh request input.
if vim.fn.has('win32') == 1 then
  vim.o.shell = 'pwsh'
  vim.o.shellcmdflag = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -Command'
  vim.o.shellredir = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode'
  vim.o.shellpipe = '2>&1 | Tee-Object %s; exit $LastExitCode'
  vim.o.shellquote = ''
  vim.o.shellxquote = ''

  -- HACK: Nvim on Windows starts with `v:ctype` = 'C' when $LANG is unset.
  -- `:checkhealth` reports an error (nvim v0.12.6, locked 2026-11-01, not retested).
  vim.cmd.language('ctype', 'en_US.UTF-8')
end

-- UI =========================================================================
vim.o.breakindentopt = 'list:-1'  -- Add padding for lists if 'wrap' is set.
vim.o.colorcolumn    = '+1'       -- Draw a column after the maximum width.
vim.o.list           = true       -- Show text indicators.
vim.o.pumborder      = 'single'   -- Use a border in the popup menu.
vim.o.pumheight      = 10         -- Limit the popup menu height.
vim.o.pummaxwidth    = 100        -- Limit the popup menu width.
vim.o.shortmess      = 'CFOSWaco' -- Disable some built-in completion messages.
vim.o.smoothscroll   = true       -- Scroll by screen line, not by whole wrapped line.
vim.o.winborder      = 'single'   -- Use a border in floating windows.

vim.o.cursorlineopt  = 'screenline,number' -- Show the cursor line per screen line.

vim.o.fillchars = 'eob: ,fold:╌'
vim.o.listchars = 'extends:…,nbsp:␣,precedes:…,tab:> '

vim.o.foldlevel   = 10       -- Keep folds open by default. Set `foldlevel` to 0 or 1 to close folds.
vim.o.foldmethod  = 'indent' -- Fold by indentation level.
vim.o.foldnestmax = 10       -- Limit the number of fold levels.
vim.o.foldtext    = ''       -- Show the fold text with its highlighting.

-- Editing ====================================================================
vim.o.expandtab     = true    -- Convert tabs to spaces.
vim.o.formatoptions = 'rqnl1j'-- Improve comment editing.
vim.o.shiftwidth    = 2       -- Use this number of spaces for indentation.
vim.o.spelloptions  = 'camel' -- Treat camelCase word parts as separate words.
vim.o.tabstop       = 2       -- Show a tab as this number of spaces.

-- `zg` adds to the English spell file; `2zg` adds to the Italian file (`:h 'spellfile'`).
local spell_dir = vim.fn.stdpath('config') .. '/spell'
vim.o.spelllang = 'en,it'
vim.o.spellfile = spell_dir .. '/en.utf-8.add,' .. spell_dir .. '/it.utf-8.add'

vim.o.iskeyword = '@,48-57,_,192-255,-' -- Treat a dash as part of the `word` textobject.

vim.o.formatlistpat = [[^\s*[0-9\-\+\*]\+[\.\)]*\s\+]]

vim.o.complete        = '.,w,b,kspell'                  -- Use fewer sources.
vim.o.completeopt     = 'menuone,noselect,fuzzy,nosort' -- Use custom completion behavior.
vim.o.completetimeout = 100                             -- Limit the source delay.

-- Autocommands ===============================================================

-- NOTE: Set this on `FileType` so filetype plugins cannot override it.
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
