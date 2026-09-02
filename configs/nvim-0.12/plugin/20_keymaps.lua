-- ┌─────────────────┐
-- │ Custom mappings │
-- └─────────────────┘
--
-- This file contains definitions of custom general and Leader mappings.

-- General mappings ===========================================================

-- Use this section to add custom general mappings. See `:h vim.keymap.set()`.

-- An example helper to create a Normal mode mapping
local nmap = function(lhs, rhs, desc)
  -- See `:h vim.keymap.set()`
  vim.keymap.set('n', lhs, rhs, { desc = desc })
end

-- Paste linewise before/after current line
-- Usage: `yiw` to yank a word and `]p` to put it on the next line.
nmap('[p', '<Cmd>exe "iput! " . v:register<CR>', 'Paste Above')
nmap(']p', '<Cmd>exe "iput "  . v:register<CR>', 'Paste Below')

nmap('<C-S-H>', '<C-w>H', 'Move to very left')
nmap('<C-S-J>', '<C-w>J', 'Move to very bottom')
nmap('<C-S-K>', '<C-w>K', 'Move to very top')
nmap('<C-S-L>', '<C-w>L', 'Move to very right')

-- Many general mappings are created by 'mini.basics'. See 'plugin/30_mini.lua'

-- stylua: ignore start
-- The next part (until `-- stylua: ignore end`) is aligned manually for easier
-- reading. Consider preserving this or remove `-- stylua` lines to autoformat.

-- Leader mappings ============================================================

-- Neovim has the concept of a Leader key (see `:h <Leader>`). It is a configurable
-- key that is primarily used for "workflow" mappings (opposed to text editing).
-- Like "open file explorer", "create scratch buffer", "pick from buffers".
--
-- In 'plugin/10_options.lua' <Leader> is set to <Space>, i.e. press <Space>
-- whenever there is a suggestion to press <Leader>.
--
-- This config uses a "two key Leader mappings" approach: first key describes
-- semantic group, second key executes an action. Both keys are usually chosen
-- to create some kind of mnemonic.
-- Example: `<Leader>f` groups "find" type of actions; `<Leader>ff` - find files.
-- Use this section to add Leader mappings in a structural manner.
--
-- Usually if there are global and local kinds of actions, lowercase second key
-- denotes global and uppercase - local.
-- Example: `<Leader>fs` / `<Leader>fS` - find workspace/document LSP symbols.
--
-- Many of the mappings use 'mini.nvim' modules set up in 'plugin/30_mini.lua'.

-- Create a global table with information about Leader groups in certain modes.
-- This is used to provide 'mini.clue' with extra clues.
-- Add an entry if you create a new group.
Config.leader_group_clues = {
  { mode = 'n', keys = '<Leader>b', desc = '+Buffer' },
  { mode = 'n', keys = '<Leader>e', desc = '+Explore/Edit' },
  { mode = 'n', keys = '<Leader>f', desc = '+Find' },
  { mode = 'n', keys = '<Leader>g', desc = '+Git' },
  { mode = 'n', keys = '<Leader>l', desc = '+Language' },
  { mode = 'n', keys = '<Leader>m', desc = '+Map' },
  { mode = 'n', keys = '<Leader>o', desc = '+Other' },
  { mode = 'n', keys = '<Leader>s', desc = '+Session' },
  { mode = 'n', keys = '<Leader>t', desc = '+Terminal' },
  { mode = 'n', keys = '<Leader>v', desc = '+Visits' },

  { mode = 'x', keys = '<Leader>g', desc = '+Git' },
  { mode = 'x', keys = '<Leader>l', desc = '+Language' },
}

-- Helpers for a more concise `<Leader>` mappings.
-- Most of the mappings use `<Cmd>...<CR>` string as a right hand side (RHS) in
-- an attempt to be more concise yet descriptive. See `:h <Cmd>`.
-- This approach also doesn't require the underlying commands/functions to exist
-- during mapping creation: a "lazy loading" approach to improve startup time.
local nmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('n', '<Leader>' .. suffix, rhs, { desc = desc })
end
local xmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('x', '<Leader>' .. suffix, rhs, { desc = desc })
end

-- b is for 'Buffer'. Common usage:
-- - `<Leader>bs` - create scratch (temporary) buffer
-- - `<Leader>ba` - navigate to the alternative buffer
-- - `<Leader>bw` - wipeout (fully delete) current buffer
local new_scratch_buffer = function()
  vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end

nmap_leader('ba', '<Cmd>b#<CR>',                                 'Alternate')
nmap_leader('bd', '<Cmd>lua MiniBufremove.delete()<CR>',         'Delete')
nmap_leader('bD', '<Cmd>lua MiniBufremove.delete(0, true)<CR>',  'Delete!')
nmap_leader('bs', new_scratch_buffer,                            'Scratch')
nmap_leader('bw', '<Cmd>lua MiniBufremove.wipeout()<CR>',        'Wipeout')
nmap_leader('bW', '<Cmd>lua MiniBufremove.wipeout(0, true)<CR>', 'Wipeout!')

-- e is for 'Explore' and 'Edit'. Common usage:
-- - `<Leader>ed` - open explorer at current working directory
-- - `<Leader>ef` - open directory of current file (needs to be present on disk)
-- - `<Leader>ei` - edit 'init.lua'
-- - All mappings that use `edit_plugin_file` - edit 'plugin/' config files
local edit_plugin_file = function(filename)
  return string.format('<Cmd>edit %s/plugin/%s<CR>', vim.fn.stdpath('config'), filename)
end
local explore_at_file = '<Cmd>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>'
local explore_quickfix = function()
  vim.cmd(vim.fn.getqflist({ winid = true }).winid ~= 0 and 'cclose' or 'copen')
end
local explore_locations = function()
  vim.cmd(vim.fn.getloclist(0, { winid = true }).winid ~= 0 and 'lclose' or 'lopen')
end

nmap_leader('ed', '<Cmd>lua MiniFiles.open()<CR>',          'Directory')
nmap_leader('ef', explore_at_file,                          'File directory')
nmap_leader('ei', '<Cmd>edit $MYVIMRC<CR>',                 'init.lua')
nmap_leader('ek', edit_plugin_file('20_keymaps.lua'),       'Keymaps config')
nmap_leader('em', edit_plugin_file('30_mini.lua'),          'MINI config')
nmap_leader('en', '<Cmd>lua MiniNotify.show_history()<CR>', 'Notifications')
nmap_leader('eo', edit_plugin_file('10_options.lua'),       'Options config')
nmap_leader('ep', edit_plugin_file('40_plugins.lua'),       'Plugins config')
nmap_leader('eq', explore_quickfix,                         'Quickfix list')
nmap_leader('eQ', explore_locations,                        'Location list')

-- f is for 'Fuzzy Find'. Common usage:
-- - `<Leader>ff` - find files; for best performance requires `ripgrep`
-- - `<Leader>fg` - find inside files; requires `ripgrep`
-- - `<Leader>fh` - find help tag
-- - `<Leader>fr` - resume latest picker
-- - `<Leader>fv` - all visited paths; requires 'mini.visits'
--
-- All these use 'mini.pick'. See `:h MiniPick-overview` for an overview.
local pick_workspace_symbols_live = '<Cmd>Pick lsp scope="workspace_symbol_live"<CR>'

-- HACK: `:Pick ... path="%"` can not be used on Windows, as 'mini.pick' converts
-- command arguments to a table by loading them as Lua code, where backslashes of
-- an expanded path are parsed as (mostly invalid) escape sequences.
-- Call the picker directly with the path as a proper Lua value instead.
-- Remove after this is fixed upstream (still present in 'mini.nvim' 0.18.0).
local pick_buf_path = function(picker, scope)
  return function()
    local path = vim.api.nvim_buf_get_name(0)
    if path == '' then
      return vim.notify('Buffer is not a file on disk', vim.log.levels.WARN)
    end
    MiniExtra.pickers[picker]({ path = path, scope = scope })
  end
end

nmap_leader('f/', '<Cmd>Pick history scope="/"<CR>',            '"/" history')
nmap_leader('f:', '<Cmd>Pick history scope=":"<CR>',            '":" history')
nmap_leader('fa', '<Cmd>Pick git_hunks scope="staged"<CR>',     'Added hunks (all)')
nmap_leader('fA', pick_buf_path('git_hunks', 'staged'),         'Added hunks (buf)')
nmap_leader('fb', '<Cmd>Pick buffers<CR>',                      'Buffers')
nmap_leader('fc', '<Cmd>Pick git_commits<CR>',                  'Commits (all)')
nmap_leader('fC', pick_buf_path('git_commits'),                 'Commits (buf)')
nmap_leader('fd', '<Cmd>Pick diagnostic scope="all"<CR>',       'Diagnostic workspace')
nmap_leader('fD', '<Cmd>Pick diagnostic scope="current"<CR>',   'Diagnostic buffer')
nmap_leader('ff', '<Cmd>Pick files<CR>',                        'Files')
nmap_leader('fg', '<Cmd>Pick grep_live<CR>',                    'Grep live')
nmap_leader('fG', '<Cmd>Pick grep pattern="<cword>"<CR>',       'Grep current word')
nmap_leader('fh', '<Cmd>Pick help<CR>',                         'Help tags')
nmap_leader('fH', '<Cmd>Pick hl_groups<CR>',                    'Highlight groups')
nmap_leader('fl', '<Cmd>Pick buf_lines scope="all"<CR>',        'Lines (all)')
nmap_leader('fL', '<Cmd>Pick buf_lines scope="current"<CR>',    'Lines (buf)')
nmap_leader('fm', '<Cmd>Pick git_hunks<CR>',                    'Modified hunks (all)')
nmap_leader('fM', pick_buf_path('git_hunks'),                   'Modified hunks (buf)')
nmap_leader('fr', '<Cmd>Pick resume<CR>',                       'Resume')
nmap_leader('fR', '<Cmd>Pick lsp scope="references"<CR>',       'References (LSP)')
nmap_leader('fs', pick_workspace_symbols_live,                  'Symbols workspace (live)')
nmap_leader('fS', '<Cmd>Pick lsp scope="document_symbol"<CR>',  'Symbols document')
nmap_leader('fv', '<Cmd>Pick visit_paths cwd=""<CR>',           'Visit paths (all)')
nmap_leader('fV', '<Cmd>Pick visit_paths<CR>',                  'Visit paths (cwd)')

-- g is for 'Git'. Common usage:
-- - `<Leader>gs` - show information at cursor
-- - `<Leader>go` - toggle 'mini.diff' overlay to show in-buffer unstaged changes
-- - `<Leader>gd` - show unstaged changes as a patch in separate tabpage
-- - `<Leader>gL` - show Git log of current file
-- - `<Leader>gb` - show who last changed every line of current file
--
-- This group reads the repository, it does not manage it: changing what Git
-- stores (staging, branching, stashing, rebasing) is done in 'lazygit'
-- (`<Leader>tl`), which is a Git client already. Committing stays here because
-- writing a message is editing text. Everything else answers "what changed,
-- when, and by whom", so that the code can be read through its history.
--
-- Inside the output of these commands `gf` works on the patch paths, `<CR>`
-- shows more data about the entry at cursor, `zm` / `zr` adjust folds, and
-- `q` closes the window. See 'plugin/30_mini.lua' for how this is set up.
-- What `<CR>` opens is placed by what it is: a commit goes full width below
-- the log it was read from, a file goes into a column at the far right.
--
-- The buffer scoped commands say `-- %:p` and not `-- %`: `:Git` runs from the
-- root of the repository, while `%` expands relative to the current directory.
-- The two differ as soon as Neovim is started below the root, and Git then gets
-- a path which matches nothing and answers with an empty output.
--
-- To review already committed changes there is a `[count]` (default 1) which
-- tells how many latest commits to look at:
-- - `<Leader>gh` / `<Leader>gH` - patch of latest `[count]` commits (all/buffer)
--   in a separate tabpage. Example: `3<Leader>gh` - patch of latest 3 commits.
--
-- Reading the code as it was at some revision is done by referencing it: the
-- revision becomes the 'mini.diff' reference text, which makes every commit
-- made after it look exactly like it is not committed yet. Hunk navigation
-- (`[h` / `]h`), hunk textobject (`gh`) and overlay then work on the history.
-- - `<Leader>gr` / `<Leader>gR` - reference a revision in every buffer / in the
--   current one. Pressing it again restores the reference to the Git index.
-- - `[count]` references `HEAD~[count]`. Example: `3<Leader>gr`. Without it the
--   revision is picked from the Git log (of the current file for `<Leader>gR`),
--   which is the way to reference a commit by hash.
-- - What is referenced can be read in `Config.diff_ref` and `vim.b.diff_ref`,
--   the source that actually attached in `vim.b.minidiff_summary.source_name`.
-- - Hunks can not be applied (`gh`) while a revision is referenced: they would
--   be staged against the index, which is not what is shown.
--
-- The source providing that reference text and `Config.set_diff_ref()`, which
-- these two mappings drive, are in 'plugin/30_mini.lua' next to the 'mini.diff'
-- setup they configure.
local git_log_cmd = [[Git log --pretty=format:\%h\ \%as\ │\ \%s --topo-order]]
local git_log_buf_cmd = git_log_cmd .. ' --follow -- %:p'

local git_diff_head = function(postfix)
  return function() vim.cmd('Git diff HEAD~' .. vim.v.count1 .. (postfix or '')) end
end

-- Call `Config.set_diff_ref()` with `HEAD~[count]`, or with a commit picked from
-- the log when there is no `[count]`. Restore the Git index instead when
-- a revision is already referenced.
-- NOTE: `choose` runs while the picker is still the current buffer, hence the
-- buffer identifier resolved before starting it.
local diff_ref_toggle = function(scope)
  return function()
    local buf_id, cur_ref = nil, Config.diff_ref
    if scope == 'buf' then
      buf_id, cur_ref = vim.api.nvim_get_current_buf(), vim.b.diff_ref
    end
    if cur_ref ~= nil then return Config.set_diff_ref(nil, buf_id) end

    local count = vim.v.count
    if count > 0 then return Config.set_diff_ref('HEAD~' .. count, buf_id) end

    local path = nil
    if scope == 'buf' then
      path = vim.api.nvim_buf_get_name(0)
      if vim.fn.filereadable(path) ~= 1 then
        return vim.notify('Buffer is not a file on disk', vim.log.levels.WARN)
      end
    end
    local choose = function(item) Config.set_diff_ref(item:match('^%S+'), buf_id) end
    MiniExtra.pickers.git_commits({ path = path }, { source = { choose = choose } })
  end
end

nmap_leader('ga', '<Cmd>Git diff --cached<CR>',             'Added diff')
nmap_leader('gA', '<Cmd>Git diff --cached -- %:p<CR>',      'Added diff buffer')
nmap_leader('gb', '<Cmd>vertical Git blame -- %:p<CR>',     'Blame buffer')
nmap_leader('gc', '<Cmd>Git commit<CR>',                    'Commit')
nmap_leader('gC', '<Cmd>Git commit --amend<CR>',            'Commit amend')
nmap_leader('gd', '<Cmd>Git diff<CR>',                      'Diff')
nmap_leader('gD', '<Cmd>Git diff -- %:p<CR>',               'Diff buffer')
nmap_leader('gh', git_diff_head(),                          'HEAD~N diff')
nmap_leader('gH', git_diff_head(' -- %:p'),                 'HEAD~N diff buffer')
nmap_leader('gl', '<Cmd>' .. git_log_cmd .. '<CR>',         'Log')
nmap_leader('gL', '<Cmd>' .. git_log_buf_cmd .. '<CR>',     'Log buffer')
nmap_leader('go', '<Cmd>lua MiniDiff.toggle_overlay()<CR>', 'Toggle overlay')
nmap_leader('gr', diff_ref_toggle('all'),                   'Reference revision')
nmap_leader('gR', diff_ref_toggle('buf'),                   'Reference revision buffer')
nmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>',  'Show at cursor')

xmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>', 'Show at selection')

-- l is for 'Language'. Common usage:
-- - `<Leader>ld` - show more diagnostic details in a floating window
-- - `<Leader>lr` - perform rename via LSP
-- - `<Leader>ls` - navigate to source definition of symbol under cursor
--
-- NOTE: most LSP mappings represent a more structured way of replacing built-in
-- LSP mappings (like `:h gra` and others). This is needed because `gr` is mapped
-- by an "replace" operator in 'mini.operators' (which is more commonly used).
--
-- TODO: make `:h :make` asynchronous, and give it a mapping in this group.
-- Building and testing from here is already almost free: runtime compiler plugins
-- set `:h 'makeprg'` and `:h 'errorformat'` per language, so `:make check` fills
-- the quickfix list and `]q` walks the errors. The single flaw is that `:make`
-- blocks the interface until the command returns.
--
-- The fix is to keep everything and replace only the waiting: run the command
-- with `:h vim.system()` and feed its output to `:h setqflist()` with the buffer's
-- own 'errorformat', so compiler plugins, `:compiler` and the quickfix mappings
-- keep working untouched. Reaching for a terminal instead gives up all of that.
--
-- Worth handling when doing it: one run at a time per buffer, a way to know it is
-- still running, and `:h 'autowrite'` so a stale buffer is never compiled.
nmap_leader('la', '<Cmd>lua vim.lsp.buf.code_action()<CR>',     'Actions')
nmap_leader('ld', '<Cmd>lua vim.diagnostic.open_float()<CR>',   'Diagnostic popup')
nmap_leader('lf', '<Cmd>lua require("conform").format()<CR>',   'Format')
nmap_leader('li', '<Cmd>lua vim.lsp.buf.implementation()<CR>',  'Implementation')
nmap_leader('lh', '<Cmd>lua vim.lsp.buf.hover()<CR>',           'Hover')
nmap_leader('ll', '<Cmd>lua vim.lsp.codelens.run()<CR>',        'Lens')
nmap_leader('lr', '<Cmd>lua vim.lsp.buf.rename()<CR>',          'Rename')
nmap_leader('lR', '<Cmd>lua vim.lsp.buf.references()<CR>',      'References')
nmap_leader('ls', '<Cmd>lua vim.lsp.buf.definition()<CR>',      'Source definition')
nmap_leader('lt', '<Cmd>lua vim.lsp.buf.type_definition()<CR>', 'Type definition')

xmap_leader('lf', '<Cmd>lua require("conform").format()<CR>', 'Format selection')

-- m is for 'Map'. Common usage:
-- - `<Leader>mt` - toggle map from 'mini.map' (closed by default)
-- - `<Leader>mf` - focus on the map for fast navigation
-- - `<Leader>ms` - change map's side (if it covers something underneath)
nmap_leader('mf', '<Cmd>lua MiniMap.toggle_focus()<CR>', 'Focus (toggle)')
nmap_leader('mr', '<Cmd>lua MiniMap.refresh()<CR>',      'Refresh')
nmap_leader('ms', '<Cmd>lua MiniMap.toggle_side()<CR>',  'Side (toggle)')
nmap_leader('mt', '<Cmd>lua MiniMap.toggle()<CR>',       'Toggle')

-- o is for 'Other'. Common usage:
-- - `<Leader>oz` - toggle between "zoomed" and regular view of current buffer
-- - `<Leader>ou` - bring upstream changes of this config into the local branch
--
-- This config is a fork of 'MiniMax': the `minimax` remote is upstream and is
-- read only, so its work arrives here only through a merge. Doing it from the
-- editor keeps "am I behind upstream?" one keypress away instead of a shell
-- session, and it is the first thing to answer when something misbehaves.
--
-- Everything is left to Git itself, called asynchronously (`:h vim.system()`)
-- so the editor stays usable while fetching: Git already refuses to merge on a
-- dirty work tree and stops on conflicts, and its own message says more than a
-- reimplemented check would. The confirmation exists because the files being
-- rewritten are the ones this Neovim is running from.
-- NOTE: plugins are a separate matter, updated with `:h vim.pack.update()`.
local upstream_merge = function()
  -- `stdpath('config')` is inside the fork's repository, so `-C` finds it no
  -- matter the current directory
  local git = function(args, on_done)
    local cmd = vim.list_extend({ 'git', '-C', vim.fn.stdpath('config') }, args)
    vim.system(cmd, { text = true }, vim.schedule_wrap(on_done))
  end
  -- Which stream carries the reason depends on the subcommand ('merge' reports
  -- a conflict on stdout), so report whichever one spoke
  local is_ok = function(out)
    if out.code == 0 then return true end
    local msg = vim.trim(out.stderr) ~= '' and out.stderr or out.stdout
    vim.notify(vim.trim(msg), vim.log.levels.ERROR)
  end

  vim.notify('Fetching `minimax`...')
  git({ 'fetch', 'minimax' }, function(fetched)
    if not is_ok(fetched) then return end
    git({ 'rev-list', '--count', 'HEAD..minimax/main' }, function(counted)
      if not is_ok(counted) then return end

      local n = tonumber(vim.trim(counted.stdout))
      if n == 0 then return vim.notify('Already up to date with `minimax/main`') end

      local prompt = n .. ' new commit(s) upstream. Merge? (y/n) '
      vim.ui.input({ prompt = prompt }, function(answer)
        if (answer or ''):lower() ~= 'y' then return end
        git({ 'merge', '--no-edit', 'minimax/main' }, function(merged)
          if not is_ok(merged) then return end
          -- Reload the config files the merge changed on disk
          vim.cmd('checktime')
          vim.notify('Merged ' .. n .. ' commit(s) from `minimax/main`')
        end)
      end)
    end)
  end)
end

nmap_leader('or', '<Cmd>lua MiniMisc.resize_window()<CR>', 'Resize to default width')
nmap_leader('ot', '<Cmd>lua MiniTrailspace.trim()<CR>',    'Trim trailspace')
nmap_leader('ou', upstream_merge,                          'Update from upstream')
nmap_leader('oz', '<Cmd>lua MiniMisc.zoom()<CR>',          'Zoom toggle')

-- s is for 'Session'. Common usage:
-- - `<Leader>sn` - start new session
-- - `<Leader>sr` - read previously started session
-- - `<Leader>sR` - restart Neovim preserving current session
local session_new = 'vim.ui.input({ prompt = "Session name: " }, MiniSessions.write)'

nmap_leader('sd', '<Cmd>lua MiniSessions.select("delete")<CR>', 'Delete')
nmap_leader('sn', '<Cmd>lua ' .. session_new .. '<CR>',         'New')
nmap_leader('sr', '<Cmd>lua MiniSessions.select("read")<CR>',   'Read')
nmap_leader('sR', '<Cmd>lua MiniSessions.restart()<CR>',        'Restart')
nmap_leader('sw', '<Cmd>lua MiniSessions.write()<CR>',          'Write current')

-- t is for 'Terminal'. Common usage:
-- - `<Leader>tt` / `<Leader>tT` - terminal in vertical/horizontal split
-- - `<Leader>tl` - 'lazygit' in a centered floating window. Quit it as usual
--   (`q`) to close the window and reload files it changed on disk.
local term_lazygit = function()
  if vim.fn.executable('lazygit') ~= 1 then
    return vim.notify('`lazygit` is not available', vim.log.levels.WARN)
  end

  -- Cover most of the editor while keeping some context visible around.
  -- Border comes from `:h 'winborder'` set in 'plugin/10_options.lua'.
  local height = math.floor(0.9 * vim.o.lines)
  local width = math.floor(0.9 * vim.o.columns)
  local win_config = {
    relative = 'editor',
    height = height,
    width = width,
    row = math.floor(0.5 * (vim.o.lines - height)),
    col = math.floor(0.5 * (vim.o.columns - width)),
    title = ' lazygit ',
    title_pos = 'center',
  }
  local buf_id = vim.api.nvim_create_buf(false, true)
  local win_id = vim.api.nvim_open_win(buf_id, true, win_config)

  local on_exit = vim.schedule_wrap(function()
    pcall(vim.api.nvim_win_close, win_id, true)
    pcall(vim.api.nvim_buf_delete, buf_id, { force = true })
    -- Reload buffers changed by 'lazygit' (checkout, discard, stash, ...)
    vim.cmd('checktime')
  end)

  -- Runs in current directory, which 'mini.misc' keeps at the project root
  vim.fn.jobstart('lazygit', { term = true, on_exit = on_exit })
  vim.cmd('startinsert')
end

nmap_leader('tl', term_lazygit,               'Lazygit')
nmap_leader('tT', '<Cmd>horizontal term<CR>', 'Terminal (horizontal)')
nmap_leader('tt', '<Cmd>vertical term<CR>',   'Terminal (vertical)')

-- v is for 'Visits'. Common usage:
-- - `<Leader>vv` - add    "core" label to current file.
-- - `<Leader>vV` - remove "core" label to current file.
-- - `<Leader>vc` - pick among all files with "core" label.
local make_pick_core = function(cwd, desc)
  return function()
    local sort_latest = MiniVisits.gen_sort.default({ recency_weight = 1 })
    local local_opts = { cwd = cwd, filter = 'core', sort = sort_latest }
    MiniExtra.pickers.visit_paths(local_opts, { source = { name = desc } })
  end
end

nmap_leader('vc', make_pick_core('',  'Core visits (all)'),       'Core visits (all)')
nmap_leader('vC', make_pick_core(nil, 'Core visits (cwd)'),       'Core visits (cwd)')
nmap_leader('vv', '<Cmd>lua MiniVisits.add_label("core")<CR>',    'Add "core" label')
nmap_leader('vV', '<Cmd>lua MiniVisits.remove_label("core")<CR>', 'Remove "core" label')
nmap_leader('vl', '<Cmd>lua MiniVisits.add_label()<CR>',          'Add label')
nmap_leader('vL', '<Cmd>lua MiniVisits.remove_label()<CR>',       'Remove label')
-- stylua: ignore end
