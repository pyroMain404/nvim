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

-- Container breadcrumb in 'winbar' (`:h 'winbar'`), e.g. `Outer > method`,
-- naming the tree-sitter containers (function/method/class/struct/module
-- definitions) enclosing the cursor. Per-language node type names, verified
-- against a real buffer of each installed language with
-- `:lua print(vim.treesitter.get_parser(0,ft):parse()[1]:root():sexpr())`.
-- Value of each entry is the `:h vim.lsp.protocol.SymbolKind` name closest
-- to what the node stands for - the same vocabulary `MiniIcons.get('lsp', …)`
-- indexes below, so no separate node-type-to-icon table is needed.
local winbar_containers = {
  lua = { function_declaration = 'Function', function_definition = 'Function' },
  rust = {
    function_item = 'Function',
    impl_item = 'Interface',
    mod_item = 'Module',
    struct_item = 'Struct',
  },
  java = { method_declaration = 'Method', class_declaration = 'Class', interface_declaration = 'Interface' },
  gdscript = { function_definition = 'Function', class_definition = 'Class' },
  typescript = { function_declaration = 'Function', method_definition = 'Method', class_declaration = 'Class' },
  javascript = { function_declaration = 'Function', method_definition = 'Method', class_declaration = 'Class' },
  c = { function_definition = 'Function', struct_specifier = 'Struct' },
  cpp = {
    function_definition = 'Function',
    class_specifier = 'Class',
    struct_specifier = 'Struct',
    namespace_definition = 'Namespace',
  },
}

-- Most grammars name a container's identifier through a `name` field
-- (`function_declaration name: (identifier)`); Rust's `impl` block uses
-- `type` instead (`impl_item type: (type_identifier)`); C/C++'s
-- `function_definition` has neither - the name sits at the bottom of a
-- `declarator` chain (`function_declarator declarator: (identifier)`),
-- unwrapped by walking `field('declarator')` until it stops nesting.
local function container_label(node, bufnr)
  local target = node:field('name')[1] or node:field('type')[1]
  if target == nil then
    local d = node:field('declarator')[1]
    while d ~= nil and d:field('declarator')[1] ~= nil do
      d = d:field('declarator')[1]
    end
    target = d
  end
  -- Lua's anonymous `function_definition` (`M.foo = function() end`, the
  -- idiomatic way this very config assigns most of its own functions) has
  -- none of the fields above: its name is the `=` left-hand side instead,
  -- one level up through the `expression_list` the grammar wraps it in.
  if target == nil and node:type() == 'function_definition' then
    local assign = node:parent() and node:parent():parent()
    if assign ~= nil and assign:type() == 'assignment_statement' then
      local var_list = assign:named_child(0)
      target = var_list ~= nil and var_list:field('name')[1]
    end
  end
  if target == nil then return nil end
  return vim.treesitter.get_node_text(target, bufnr)
end

local function compute_winbar(bufnr, containers)
  -- `get_node()` answers nil against a buffer whose parser was never asked
  -- to parse yet - normally not an issue, since nvim-treesitter's own
  -- `FileType` highlighting attach (`plugin/40_plugins.lua`) parses first,
  -- but the very first `CursorMoved` can race it. Forcing the parse here is
  -- cheap: `TSParser:parse()` is itself cached and reparses only the edited
  -- range (`:h vim.treesitter.LanguageTree:parse()`).
  local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
  local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok_parser then return '' end
  parser:parse()
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr })
  if not ok or node == nil then return '' end
  local parts = {}
  while node ~= nil do
    local kind = containers[node:type()]
    if kind ~= nil then
      local label = container_label(node, bufnr)
      -- `MiniIcons` is set up in 'plugin/30_mini.lua' `now()`, well before
      -- this ever runs from a deferred autocommand.
      if label ~= nil then table.insert(parts, 1, MiniIcons.get('lsp', kind) .. ' ' .. label) end
    end
    node = node:parent()
  end
  return table.concat(parts, ' > ')
end

-- The "per-redraw caching budget" this used to be a TODO about: `'winbar'`'s
-- `%{...}` expression is evaluated on every screen redraw, far too often to
-- walk the syntax tree in. Instead `CursorMoved`/`CursorMovedI` refresh a
-- window-local cache, and only when the cursor's LINE actually changed;
-- `'winbar'` itself only ever reads the cache, never recomputes.
local winbar_cache = {} ---@type table<integer, { line: integer, text: string }>
local function refresh_winbar_cache(bufnr)
  local containers = winbar_containers[vim.bo[bufnr].filetype]
  if containers == nil then return end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local cache = winbar_cache[bufnr]
  if cache ~= nil and cache.line == line then return end
  winbar_cache[bufnr] = { line = line, text = compute_winbar(bufnr, containers) }
end
Config.new_autocmd({ 'CursorMoved', 'CursorMovedI' }, nil, function(args)
  refresh_winbar_cache(args.buf)
end, 'Cache the winbar breadcrumb on cursor line change')

Config.winbar = function()
  local cache = winbar_cache[vim.api.nvim_get_current_buf()]
  return cache ~= nil and cache.text or ''
end

-- Only for normal file buffers - not the quickfix window, a `nofile` scratch
-- buffer, a terminal, … `vim.wo[0][0]` (not plain `vim.wo`) keeps the write
-- window-local only (`:h vim.wo`), the same reason 'after/ftplugin/java.lua'
-- uses it for `foldmethod`. `%{%...%}` is `'winbar'`'s "stateful" form
-- (`:h 'statusline'`), needed to call into Lua through `v:lua`.
Config.new_autocmd({ 'BufWinEnter', 'FileType' }, nil, function(args)
  if vim.bo[args.buf].buftype ~= '' then return end
  vim.wo[0][0].winbar = '%{%v:lua.Config.winbar()%}'
  -- Without this the bar sits empty until the first cursor move, since only
  -- `CursorMoved`/`CursorMovedI` used to populate the cache above.
  refresh_winbar_cache(args.buf)
end, "Show the container breadcrumb in 'winbar'")

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
  virtual_text = {
    current_line = true,
    severity = { min = 'ERROR', max = 'ERROR' },
  },
}

-- Use `later()` to avoid sourcing `vim.diagnostic` on startup
Config.later(function() vim.diagnostic.config(diagnostic_opts) end)
-- stylua: ignore end
