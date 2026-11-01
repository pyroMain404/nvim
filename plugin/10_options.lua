-- ┌──────────────────────────┐
-- │ Built-in Neovim behavior │
-- └──────────────────────────┘
--
-- This file defines Neovim's built-in behavior. The goal is to improve overall
-- usability in a way that works best with MINI.
--
-- Here `vim.o.xxx = value` sets default value of option `xxx` to `value`.
-- See `:h 'xxx'` (replace `xxx` with actual option name).
--
-- Option values can be customized on a per buffer or window basis.
-- See 'after/ftplugin/' for common example.
--
-- Notes:
-- - Some options (like `:h 'exrc'`) need to be set before this file is sourced.
--   Set them directly at the bottom of the 'init.lua' file.
-- - Options which 'mini.basics' sets to the same value under `options.basic = true`
--   are not repeated here: it runs after this file ('plugin/30_mini.lua'), so it
--   is the one place listing them. Only the ones needing a different value stay.

-- stylua: ignore start
-- The next part (until `-- stylua: ignore end`) is aligned manually for easier
-- reading. Consider preserving this or remove `-- stylua` lines to autoformat.

-- General ====================================================================
vim.g.mapleader = ' ' -- Use `<Space>` as <Leader> key

vim.o.mousescroll = 'ver:25,hor:6' -- Customize mouse scroll
vim.o.switchbuf   = 'usetab'       -- Use already opened buffers when switching

-- Upward search for `gf`, `:find` and the glance popup. See 'lua/config/path.lua'.
vim.o.path = require('config.path').default

vim.o.shada = "'100,<50,s10,:1000,/100,@100,h" -- Limit ShaDa file (for startup)

-- Use PowerShell 7, not the Windows default `cmd.exe`, for `:!`, `:make`,
-- `system()` and the terminal - this machine's own convention (see personal
-- memory, "Ambiente": "Invocare PowerShell con `pwsh`, non Windows PowerShell
-- 5.1"). `shellquote`/`shellxquote` are cleared because `pwsh -Command`
-- parses its own argument, unlike `cmd.exe` which expects Vim to wrap it in
-- quotes (`:h 'shellxquote'`). `shellpipe`/`shellredir` route through
-- `Tee-Object`/`Out-File` with UTF8 explicitly, because PowerShell's default
-- console encoding is UTF-16LE with a BOM, which `errorformat` does not skip
-- and would otherwise corrupt every line pushed into the quickfix list.
--
-- Measured, replacing the equivalent NOTE this used to carry about
-- `cmd.exe`: unlike `cmd.exe`'s `2>&1| tee %s` (whose own exit code is
-- always `tee`'s, always 0), PowerShell's `$LastExitCode` after
-- `<command> 2>&1 | Tee-Object <file>; exit $LastExitCode` still reports the
-- external command's real exit code - `Tee-Object` is a cmdlet, not an
-- external process, so it never overwrites `$LastExitCode`. `v:shell_error`
-- is therefore trustworthy again; see the `QuickFixCmdPost` autocommand
-- below for what still does not rely on it and why.
if vim.fn.has('win32') == 1 then
  vim.o.shell = 'pwsh'
  vim.o.shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command'
  vim.o.shellredir = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode'
  vim.o.shellpipe = '2>&1 | Tee-Object %s; exit $LastExitCode'
  vim.o.shellquote = ''
  vim.o.shellxquote = ''
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

-- Special UI symbols. More is set via 'mini.basics' later.
vim.o.fillchars = 'eob: ,fold:╌'
vim.o.listchars = 'extends:…,nbsp:␣,precedes:…,tab:> '

-- 'winbar' showing the container breadcrumb under the cursor is set up below,
-- in the Autocommands section: it needs `CursorMoved` to refresh, not a
-- fixed value, so it does not belong among the plain `vim.o.xxx` lines here.

-- Folds (see `:h fold-commands`, `:h zM`, `:h zR`, `:h zA`, `:h zj`)
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

-- Spell checking (`:h 'spelllang'`, `:h 'spellfile'`, `:h zg`): `zg` adds to the
-- English file, `2zg` to the Italian one. Both live in the config's 'spell/'.
local spell_dir = vim.fn.stdpath('config') .. '/spell'
vim.o.spelllang = 'en,it'
vim.o.spellfile = spell_dir .. '/en.utf-8.add,' .. spell_dir .. '/it.utf-8.add'

vim.o.iskeyword = '@,48-57,_,192-255,-' -- Treat dash as `word` textobject part

-- Pattern for a start of numbered list (used in `gw`). This reads as
-- "Start of list item is: at least one special character (digit, -, +, *)
-- possibly followed by punctuation (. or `)`) followed by at least one space".
vim.o.formatlistpat = [[^\s*[0-9\-\+\*]\+[\.\)]*\s\+]]

-- Built-in completion
vim.o.complete        = '.,w,b,kspell'                  -- Use less sources
vim.o.completeopt     = 'menuone,noselect,fuzzy,nosort' -- Use custom behavior
vim.o.completetimeout = 100                             -- Limit sources delay

-- Autocommands ===============================================================

-- Don't auto-wrap comments and don't insert comment leader after hitting 'o'.
-- Do on `FileType` to always override these changes from filetype plugins.
Config.new_autocmd('FileType', nil, function()
  vim.cmd('setlocal formatoptions-=c formatoptions-=o')
end, "Proper 'formatoptions'")

-- `:make`/`:lmake` run synchronously and leave the result to be read off the
-- (location) list - useful once inside it, silent the moment the command
-- returns control. This is language agnostic on purpose: every `:compiler`
-- plugin ('java.lua', 'maven.vim' through it, `gcc`, `cargo`, …) already
-- populates the same two lists the same way, so one autocommand answers for
-- all of them instead of each ftplugin reporting for itself.
--
-- NOTE: `v:shell_error` became trustworthy again once the shell switched to
-- `pwsh` above (`2>&1 | Tee-Object %s; exit $LastExitCode` correctly carries
-- the compiled program's real exit code, unlike `cmd.exe`'s `2>&1| tee %s`,
-- whose pipeline exit code was always `tee`'s - always 0). Measured:
-- `:make` on `pwsh -Command exit 1` now reports "shell returned 1", where it
-- used to leave `v:shell_error` at 0. Still not relied on here, on purpose:
-- it answers "did the shell's own pipeline fail", not "did the build fail" -
-- a `:compiler` plugin whose `errorformat` matches nothing on a real failure
-- (measured on Gradle, 'after/ftplugin/java.lua''s own TODO) exits non-zero
-- from the correct step and would still need this counting to notice an
-- empty quickfix list is not the same thing as a clean build. Counting only
-- the `E`-type entries `errorformat` recognized stays the one signal that
-- covers both failure shapes, and the one already proven on Maven.
Config.new_autocmd('QuickFixCmdPost', { 'make', 'lmake' }, function(args)
  local list = args.match == 'lmake' and vim.fn.getloclist(0) or vim.fn.getqflist()
  local typed = function(t)
    return #vim.tbl_filter(function(item)
      return item.valid == 1 and item.type:upper() == t
    end, list)
  end
  local errors, warnings = typed('E'), typed('W')
  if errors > 0 then
    vim.notify(
      ('Build failed: %d error%s'):format(errors, errors == 1 and '' or 's'),
      vim.log.levels.ERROR
    )
  else
    local message = 'Build succeeded'
    if warnings > 0 then
      message = message .. (' (%d warning%s)'):format(warnings, warnings == 1 and '' or 's')
    end
    vim.notify(message, vim.log.levels.INFO)
  end
end, 'Report the outcome of :make/:lmake')

-- `:Make`/`:LMake`: the same `'makeprg'`/`'errorformat'` contract as
-- `:make`/`:lmake`, run asynchronously through `vim.system()` instead of
-- blocking Neovim for the length of the build. Reuses the `QuickFixCmdPost`
-- autocommand above for the success/failure report instead of repeating it -
-- `doautocmd` fires it exactly as `:make` itself would.
--
-- `vim.fn.expandcmd()` expands the same `%`/`#`/environment-variable forms
-- `:make` expands in `'makeprg'` (`:h 'makeprg'`, `:h expandcmd()`); `$*` is
-- NOT one of them, so it is substituted by hand, the same convention
-- `'makeprg'` itself documents: replaced if present, appended otherwise.
local function build_make_cmd(args)
  local prg = vim.fn.expandcmd(vim.o.makeprg)
  local extra = table.concat(args, ' ')
  if prg:find('$*', 1, true) then
    prg = prg:gsub('%$%*', (extra:gsub('%%', '%%%%')))
  elseif extra ~= '' then
    prg = prg .. ' ' .. extra
  end
  return prg
end

-- Run the built command through the CONFIGURED shell (`'shell'`/
-- `'shellcmdflag'`, `pwsh` above) exactly like `:make` does, rather than
-- assuming a POSIX-style split - `vim.system()` takes an argv list and never
-- goes through `:h 'shell'` itself.
local function shell_argv(cmd)
  local argv = { vim.o.shell }
  vim.list_extend(argv, vim.split(vim.o.shellcmdflag, ' ', { plain = true }))
  table.insert(argv, cmd)
  return argv
end

-- One run at a time: a second `:Make` while one is in flight WARNS and
-- refuses rather than cancelling and restarting, on purpose - a build that
-- gets killed halfway writes a partial object file just as often as it
-- writes nothing, and "wait for the first one" is the simpler contract to
-- reason about from a mapping.
local make_job = nil
local function run_make(args, is_loc)
  if make_job ~= nil then
    return vim.notify('A `:Make`/`:LMake` run is already in progress', vim.log.levels.WARN)
  end
  local cmd = build_make_cmd(args)
  vim.notify('Build started: ' .. cmd, vim.log.levels.INFO)
  make_job = vim.system(shell_argv(cmd), { cwd = vim.fn.getcwd(), text = true }, function(out)
    make_job = nil
    vim.schedule(function()
      local lines =
        vim.split((out.stdout or '') .. (out.stderr or ''), '\n', { trimempty = true })
      local opts = { lines = lines, efm = vim.o.errorformat, title = 'Make' }
      if is_loc then
        vim.fn.setloclist(0, {}, ' ', opts)
      else
        vim.fn.setqflist({}, ' ', opts)
      end
      vim.cmd('doautocmd <nomodeline> QuickFixCmdPost ' .. (is_loc and 'lmake' or 'make'))
    end)
  end)
end

vim.api.nvim_create_user_command('Make', function(cmdopts)
  run_make(cmdopts.fargs, false)
end, { nargs = '*', desc = 'Async :make - same makeprg/errorformat, non-blocking' })

vim.api.nvim_create_user_command('LMake', function(cmdopts)
  run_make(cmdopts.fargs, true)
end, { nargs = '*', desc = 'Async :lmake - same makeprg/errorformat, non-blocking' })

-- There are other autocommands created by 'mini.basics'. See 'plugin/30_mini.lua'.

-- HACK: on Windows `vim.lsp.util.rename()` (used by LSP file renames, 'obsidian.nvim'
-- and `:Obsidian rename`) looks for the buffers of the renamed file by splitting
-- the `fs_realpath()` result, which has backslashes, on `/`; no buffer ever
-- matches, so the buffer keeps the old name and is written back at the old path.
-- After the file has moved, give such a buffer the new name the way upstream does
-- (`:saveas!`, which keeps the buffer number), without autocommands: the write
-- would run the front matter hook of 'obsidian.nvim' in the middle of its rename.
-- Files only, not directories. Still present in Neovim 0.12.5; delete after an
-- update that fixes it.
local lsp_rename = vim.lsp.util.rename
vim.lsp.util.rename = function(old_fname, new_fname, opts)
  lsp_rename(old_fname, new_fname, opts)
  if vim.uv.fs_stat(old_fname) or not vim.uv.fs_stat(new_fname) then
    return
  end
  local old_norm = vim.fs.normalize(old_fname)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if
      vim.api.nvim_buf_is_loaded(buf)
      and vim.bo[buf].buftype == ''
      and vim.fs.normalize(name) == old_norm
    then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd('noautocmd keepalt saveas! ' .. vim.fn.fnameescape(new_fname))
      end)
      vim.cmd('bdelete! ' .. vim.fn.bufnr(name))
    end
  end
end

-- Diagnostics ================================================================

-- Neovim has built-in support for showing diagnostic messages. This configures
-- a more conservative display while still being useful.
-- See `:h vim.diagnostic` and `:h vim.diagnostic.config()`.
local diagnostic_opts = {
  -- Show signs on top of any other sign, but only for warnings and errors
  signs = { priority = 9999, severity = { min = 'WARN', max = 'ERROR' } },

  -- Show more details immediately for errors on the current line
  virtual_text = {
    current_line = true,
    severity = { min = 'ERROR', max = 'ERROR' },
  },
}

-- Use `later()` to avoid sourcing `vim.diagnostic` on startup
Config.later(function() vim.diagnostic.config(diagnostic_opts) end)
-- stylua: ignore end
