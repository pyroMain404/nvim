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

-- stylua: ignore start
-- The next part (until `-- stylua: ignore end`) is aligned manually for easier
-- reading. Consider preserving this or remove `-- stylua` lines to autoformat.

-- General ====================================================================
vim.g.mapleader = ' ' -- Use `<Space>` as <Leader> key

vim.o.mouse       = 'a'            -- Enable mouse
vim.o.mousescroll = 'ver:25,hor:6' -- Customize mouse scroll
vim.o.switchbuf   = 'usetab'       -- Use already opened buffers when switching
vim.o.undofile    = true           -- Enable persistent undo

vim.o.shada = "'100,<50,s10,:1000,/100,@100,h" -- Limit ShaDa file (for startup)

-- UI =========================================================================
vim.o.breakindent    = true       -- Indent wrapped lines to match line start
vim.o.breakindentopt = 'list:-1'  -- Add padding for lists (if 'wrap' is set)
vim.o.colorcolumn    = '+1'       -- Draw column on the right of maximum width
vim.o.cursorline     = true       -- Enable current line highlighting
vim.o.linebreak      = true       -- Wrap lines at 'breakat' (if 'wrap' is set)
vim.o.list           = true       -- Show helpful text indicators
vim.o.number         = true       -- Show line numbers
vim.o.pumborder      = 'single'   -- Use border in popup menu
vim.o.pumheight      = 10         -- Make popup menu smaller
vim.o.pummaxwidth    = 100        -- Make popup menu not too wide
vim.o.ruler          = false      -- Don't show cursor coordinates
vim.o.shortmess      = 'CFOSWaco' -- Disable some built-in completion messages
vim.o.showmode       = false      -- Don't show mode in command line
vim.o.signcolumn     = 'yes'      -- Always show signcolumn (less flicker)
vim.o.smoothscroll   = true       -- Scroll by screen line, not by whole wrapped line
vim.o.splitbelow     = true       -- Horizontal splits will be below
vim.o.splitkeep      = 'screen'   -- Reduce scroll during window split
vim.o.splitright     = true       -- Vertical splits will be to the right
vim.o.winborder      = 'single'   -- Use border in floating windows
vim.o.wrap           = false      -- Don't visually wrap lines (toggle with \w)

vim.o.cursorlineopt  = 'screenline,number' -- Show cursor line per screen line

-- Special UI symbols. More is set via 'mini.basics' later.
vim.o.fillchars = 'eob: ,fold:╌'
vim.o.listchars = 'extends:…,nbsp:␣,precedes:…,tab:> '

-- TODO: show the innermost container of the cursor in `:h 'winbar'`: the
-- enclosing function or method, the current header in Markdown, the open tag in
-- HTML. Not a full breadcrumb chain - only the nearest one, which is the part
-- that is actually lost when scrolling inside a long body.
--
-- 'winbar' is the right tool for it: it is per window, so each split answers for
-- itself; it is filled exactly like `:h 'statusline'`, so it accepts a Lua
-- function; and it takes a line from the window frame instead of mixing into the
-- text, as virtual text would.
--
-- Two things decide whether it stays simple:
-- - Where the container comes from. Tree-sitter answers synchronously from the
--   node under the cursor (`:h vim.treesitter.get_node()`), while LSP document
--   symbols are asynchronous and need a cache to be usable here.
-- - How the interesting nodes are named per language. Instead of a table of node
--   types - which would be language specific logic in a shared file - reuse the
--   `@function.outer` and `@class.outer` captures that 'nvim-treesitter-textobjects'
--   already maintains for every language ('plugin/40_plugins.lua' installs it).
--
-- It is evaluated on every redraw, so it has to be cheap: cache per buffer and
-- cursor line, and leave 'winbar' empty where there is no container to show.

-- Folds (see `:h fold-commands`, `:h zM`, `:h zR`, `:h zA`, `:h zj`)
vim.o.foldlevel   = 10       -- Fold nothing by default; set to 0 or 1 to fold
vim.o.foldmethod  = 'indent' -- Fold based on indent level
vim.o.foldnestmax = 10       -- Limit number of fold levels
vim.o.foldtext    = ''       -- Show text under fold with its highlighting

-- Editing ====================================================================
vim.o.autoindent    = true    -- Use auto indent
vim.o.expandtab     = true    -- Convert tabs to spaces
vim.o.formatoptions = 'rqnl1j'-- Improve comment editing
vim.o.ignorecase    = true    -- Ignore case during search
vim.o.incsearch     = true    -- Show search matches while typing
vim.o.infercase     = true    -- Infer case in built-in completion
vim.o.shiftwidth    = 2       -- Use this number of spaces for indentation
vim.o.smartcase     = true    -- Respect case if search pattern has upper case
vim.o.smartindent   = true    -- Make indenting smart
vim.o.spelloptions  = 'camel' -- Treat camelCase word parts as separate words
vim.o.tabstop       = 2       -- Show tab as this number of spaces
vim.o.virtualedit   = 'block' -- Allow going past end of line in blockwise mode

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
local f = function() vim.cmd('setlocal formatoptions-=c formatoptions-=o') end
Config.new_autocmd('FileType', nil, f, "Proper 'formatoptions'")

-- `:make`/`:lmake` run synchronously and leave the result to be read off the
-- (location) list - useful once inside it, silent the moment the command
-- returns control. This is language agnostic on purpose: every `:compiler`
-- plugin ('java.lua', 'maven.vim' through it, `gcc`, `cargo`, …) already
-- populates the same two lists the same way, so one autocommand answers for
-- all of them instead of each ftplugin reporting for itself.
--
-- NOTE: `v:shell_error` is NOT the ground truth on this machine, the
-- opposite of what `:h v:shell_error` suggests. `'shellpipe'` here is
-- `2>&1| tee %s` (`cmd.exe`, so the compiler's exit code is piped into
-- `tee`, and cmd's pipeline exit code is `tee`'s - always 0. Measured:
-- `:make` on a command that exits 1 still leaves `v:shell_error` at 0.
-- Counting only the `E`-type entries `errorformat` recognized is the
-- reliable half of the signal, and the one already proven on Maven (the
-- case that asked for this). It still reads a build as green when the
-- `errorformat` matches nothing at all on a real failure - measured on
-- Gradle, 'after/ftplugin/java.lua''s own TODO - the same gap `v:shell_error`
-- would have closed anywhere else.
Config.new_autocmd('QuickFixCmdPost', { 'make', 'lmake' }, function(args)
  local list = args.match == 'lmake' and vim.fn.getloclist(0) or vim.fn.getqflist()
  local errors, warnings = 0, 0
  for _, item in ipairs(list) do
    if item.valid == 1 then
      local t = item.type:upper()
      if t == 'E' then
        errors = errors + 1
      elseif t == 'W' then
        warnings = warnings + 1
      end
    end
  end
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

-- There are other autocommands created by 'mini.basics'. See 'plugin/30_mini.lua'.

-- Diagnostics ================================================================

-- Neovim has built-in support for showing diagnostic messages. This configures
-- a more conservative display while still being useful.
-- See `:h vim.diagnostic` and `:h vim.diagnostic.config()`.
local diagnostic_opts = {
  -- Show signs on top of any other sign, but only for warnings and errors
  signs = { priority = 9999, severity = { min = 'WARN', max = 'ERROR' } },

  -- Show all diagnostics as underline (for their messages type `<Leader>ld`)
  underline = { severity = { min = 'HINT', max = 'ERROR' } },

  -- Show more details immediately for errors on the current line
  virtual_lines = false,
  virtual_text = {
    current_line = true,
    severity = { min = 'ERROR', max = 'ERROR' },
  },

  -- Don't update diagnostics when typing
  update_in_insert = false,
}

-- Use `later()` to avoid sourcing `vim.diagnostic` on startup
Config.later(function() vim.diagnostic.config(diagnostic_opts) end)
-- stylua: ignore end
