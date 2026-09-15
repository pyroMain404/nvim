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

-- Paste linewise before/after current line, replacing the built-in `[p`/`]p`
-- (indent-adjusted put, `:h ]p`) with an unindented one instead.
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
  { mode = 'n', keys = '<Leader>r', desc = '+Review' },
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
-- `:h stdpath()` answers with the directory Neovim was started from, which
-- here is a junction to the config inside the repository. Opening a file
-- through it gives a path from which no root marker ('.git', '.stylua.toml')
-- is reachable, so a language server starts a second time with no root - in
-- single file mode, where `lua_ls` publishes no diagnostics at all. Resolving
-- it once, here, is what keeps every `<Leader>e` mapping on the real path and
-- on the client that is already running (`:h resolve()`).
local config_file = function(relative)
  local path = vim.fn.resolve(vim.fn.stdpath('config') .. '/' .. relative)
  return string.format('<Cmd>edit %s<CR>', vim.fn.fnameescape(path))
end
local edit_plugin_file = function(filename)
  return config_file('plugin/' .. filename)
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
nmap_leader('ei', config_file('init.lua'),                  'init.lua')
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
-- Remove after this is fixed upstream (still present in 'mini.nvim' ac5dffc,
-- 2026-09-13).
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
-- - `<Leader>gi` - show information at cursor
-- - `<Leader>go` - toggle 'mini.diff' overlay to show in-buffer unstaged changes
-- - `<Leader>gd` - show unstaged changes as a patch in separate tabpage
-- - `<Leader>gL` - show Git log of current file
-- - `<Leader>gb` - toggle who last changed the line under the cursor
--
-- This group reads the repository, it does not manage it: changing what Git
-- stores (staging, branching, stashing, rebasing) is done in 'lazygit'
-- (`<Leader>tl`), which is a Git client already. Committing stays here because
-- writing a message is editing text. Everything else answers "what changed,
-- when, and by whom", so that the code can be read through its history.
--
-- `<Leader>gb` writes who last changed the line under the cursor at the end of
-- that line, off until asked for. Blaming the whole file at once is still
-- `:vertical Git blame -- %:p`, aligned with the window it was called from.
--
-- Inside the output of these commands `gf` works on the patch paths, `<CR>`
-- shows more data about the entry at cursor, `zm` / `zr` adjust folds, and
-- `q` closes the window. See 'plugin/41_git.lua' for how this is set up.
-- What `<CR>` opens is placed by what it is: a commit goes full width below
-- the log it was read from, a file goes into a column at the far right.
--
-- Every mapping which reads the repository goes through `Config.git` rather
-- than running `:Git` itself, and the two commits are what is left of the
-- direct commands. Two answers are the reason: `:Git diff` on a working tree
-- with nothing changed opens no window and says nothing - indistinguishable
-- from a mapping which does not work - and outside a repository it answers with
-- the whole usage message of `git diff --no-index`. Both are replaced by the
-- one line the `<Leader>r` group gives, and 'plugin/41_git.lua' says how.
--
-- Those functions also take the buffer to ask about (`0` for the current one)
-- and write its path out themselves, where a command would need `-- %:p` and
-- not `-- %`: `:Git` runs from the root of the repository, while `%` expands
-- relative to the current directory. The two differ as soon as Neovim is
-- started below the root, and Git then gets a path which matches nothing and
-- answers with an empty output.
--
-- To review already committed changes the commit is picked from the Git log, by
-- subject rather than by distance from `HEAD`, and the key says which of the
-- two questions about it is being asked:
-- - `<Leader>gs` / `<Leader>gS` - patch of everything changed *since* the
--   picked commit (all/buffer), in a separate tabpage.
-- - `<Leader>gp` / `<Leader>gP` - patch of the picked commit *alone*, what it
--   changed against the commit before it, in a separate tabpage.
--
-- The list of the uppercase ones holds only the commits which touched the
-- current file. Which of the two is wanted follows from what is being read:
-- "is this file still the way that commit left it" is the first, "what did this
-- commit do" is the second, and a commit at the tip of the branch answers the
-- same in both.
--
-- Reading only the patch is not always enough: a change is also judged next to
-- the code that stayed, which means opening the files it touched. That is the
-- `<Leader>r` group below, where every diff above has its counterpart under the
-- same second key: `<Leader>rd` opens the files `<Leader>gd` shows as a patch,
-- `<Leader>ra` the ones `<Leader>ga` shows, `<Leader>rs` those of `<Leader>gs`,
-- `<Leader>rp` those of `<Leader>gp`.
--
-- Reading the code as it was at some revision is done by referencing it: the
-- revision becomes the 'mini.diff' reference text, which makes every commit
-- made after it look exactly like it is not committed yet. Hunk navigation
-- (`[h` / `]h`), hunk textobject (`gh`) and overlay then work on the history.
-- - `<Leader>gr` / `<Leader>gR` - reference a revision in every buffer / in the
--   current one. Pressing it again restores the reference to the Git index.
-- - The revision is picked from the Git log (of the current file for
--   `<Leader>gR`), the same way `<Leader>gs` picks the commit to diff against.
--   `:lua Config.git.toggle_diff_ref(nil, 'HEAD~3')` names one without picking.
-- - What is referenced can be read in `Config.git.diff_ref` and `vim.b.diff_ref`,
--   the source that actually attached in `vim.b.minidiff_summary.source_name`.
-- - Hunks can not be applied (`gh`) while a revision is referenced: they would
--   be staged against the index, which is not what is shown.
-- - A file opened at some commit from a patch (`<CR>` / `gF`) references the
--   commit before it on its own, so it is read as the change it received there.
-- - `<Leader>rs` references the commit it reviews, so the files it opens are
--   read the same way without picking that commit twice. `<Leader>rc` puts back
--   what was referenced before the review.
--
-- Everything these mappings call lives in 'plugin/41_git.lua', under
-- `Config.git`, next to the 'mini.diff' and 'mini.git' setup it configures.
-- The revision toggles and the patch of one commit are named here only to keep
-- the block below aligned.
local git_ref = '<Cmd>lua Config.git.toggle_diff_ref()<CR>'
local git_ref_buf = '<Cmd>lua Config.git.toggle_diff_ref(0)<CR>'
local git_patch = '<Cmd>lua Config.git.diff_commit_only()<CR>'
local git_patch_buf = '<Cmd>lua Config.git.diff_commit_only(0)<CR>'

nmap_leader('ga', '<Cmd>lua Config.git.diff_staged()<CR>',      'Added diff')
nmap_leader('gA', '<Cmd>lua Config.git.diff_staged(0)<CR>',     'Added diff buffer')
nmap_leader('gb', '<Cmd>lua Config.git.toggle_blame()<CR>',     'Blame line (toggle)')
nmap_leader('gc', '<Cmd>Git commit<CR>',                        'Commit')
nmap_leader('gC', '<Cmd>Git commit --amend<CR>',                'Commit amend')
nmap_leader('gd', '<Cmd>lua Config.git.diff_unstaged()<CR>',    'Diff')
nmap_leader('gD', '<Cmd>lua Config.git.diff_unstaged(0)<CR>',   'Diff buffer')
nmap_leader('gi', '<Cmd>lua MiniGit.show_at_cursor()<CR>',      'Info at cursor')
nmap_leader('gl', '<Cmd>lua Config.git.log()<CR>',              'Log')
nmap_leader('gL', '<Cmd>lua Config.git.log(0)<CR>',             'Log buffer')
nmap_leader('go', '<Cmd>lua MiniDiff.toggle_overlay()<CR>',     'Toggle overlay')
nmap_leader('gp', git_patch,                                    'Commit patch')
nmap_leader('gP', git_patch_buf,                                'Commit patch buffer')
nmap_leader('gr', git_ref,                                      'Reference revision')
nmap_leader('gR', git_ref_buf,                                  'Reference revision buffer')
nmap_leader('gs', '<Cmd>lua Config.git.diff_commit()<CR>',      'Since commit')
nmap_leader('gS', '<Cmd>lua Config.git.diff_commit(0)<CR>',     'Since commit buffer')

xmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>', 'Show at selection')

-- l is for 'Language'. Common usage:
-- - `<Leader>ld` - show more diagnostic details in a floating window
-- - `<Leader>lr` - perform rename via LSP
-- - `<Leader>ls` - navigate to source definition of symbol under cursor
-- - `<Leader>lf` - format the lines changed since the diff reference;
--   `<Leader>lF` formats the whole buffer, and over a Visual selection
--   `<Leader>lf` formats exactly that. See 'plugin/42_format.lua' for why the
--   default is the changed lines and not the file.
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
nmap_leader('lf', '<Cmd>lua Config.format.changed()<CR>',       'Format changed')
nmap_leader('lF', '<Cmd>lua Config.format.buffer()<CR>',        'Format buffer')
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
-- Being a Git operation like the others, it is written in 'plugin/41_git.lua'.
-- NOTE: plugins are a separate matter, updated with `:h vim.pack.update()`.
local git_update_config = '<Cmd>lua Config.git.update_config()<CR>'

nmap_leader('or', '<Cmd>lua MiniMisc.resize_window()<CR>', 'Resize to default width')
nmap_leader('ot', '<Cmd>lua MiniTrailspace.trim()<CR>',    'Trim trailspace')
nmap_leader('ou', git_update_config,                       'Update from upstream')
nmap_leader('oz', '<Cmd>lua MiniMisc.zoom()<CR>',          'Zoom toggle')

-- r is for 'Review'. Common usage:
-- - `<Leader>rd` - open the files changed and not staged yet
-- - `<Leader>ra` - open the files already staged
-- - `<Leader>rs` - open the files changed since a commit picked from the Git
--   log, read against it
-- - `<Leader>rp` - open the files that commit changed by itself
-- - `<Leader>rc` - close the review and drop the buffers it opened
--
-- This group opens files in order to read them, and its unit is the set of
-- them: the argument list (`:h argument-list`) of a new tabpage, with every one
-- loaded. `:next` / `:previous` walk the review, `:args` shows where it stands,
-- `:argdo` runs something over all of it, `:first` starts it over. That list is
-- local to the tabpage (`:h :arglocal`), so the files Neovim was started with
-- are left as they are.
--
-- What the group has in common is that, not where the files came from - which
-- is why it is not part of `<Leader>g` although Git is its only source today.
-- The second key names the set being read, and it is the key that set has in
-- `<Leader>g`, which shows the same one as a patch: `<Leader>rd` reads what
-- `<Leader>gd` shows, `<Leader>ra` what `<Leader>ga` shows, `<Leader>rs` what
-- `<Leader>gs` shows, `<Leader>rp` what `<Leader>gp` shows. Reading a change as
-- a patch and reading it in its files
-- are then the same two keys with the first one changed, and nothing has to be
-- remembered twice. A set produced by something which is not Git gets a key
-- here too, named after whatever names it, rather than a home in the group of
-- whatever produced it. There is no uppercase counterpart to any of them: the
-- review of a single file is that file, and opening it needs no group.
--
-- NOTE: a file Git does not track yet is in none of these, `git diff` being
-- about what Git already knows - the same blind spot the patches have.
--
-- `<Leader>rs` picks the commit from the Git log and reviews everything changed
-- since it, `<Leader>rp` the files that commit changed by itself. Another Git
-- command defines another review, from the command line:
-- `:lua Config.review.git('main...')` is the branch being written against the
-- point it left the one it will be merged into, and a second argument narrows
-- the review to a part of the tree (`:lua Config.review.git('main', 'configs/')`).
-- The same argument narrows the other three (`:lua Config.review.staged('*.md')`).
--
-- That commit is also referenced, which is `<Leader>gr` pressed on the same
-- one: every buffer - of the review and not - then holds the change it received
-- since then, walked with `[h` / `]h` and read in place with the overlay, and
-- nothing is picked twice. `<Leader>rp` references the commit before the picked
-- one instead, so what is shown in the files is what that commit did, which is
-- the review it opens. `<Leader>rc` puts the previous reference back,
-- unless it was changed by hand in the meantime: what a review is read against
-- ends with it.
--
-- The other two set no reference - the Git index is what they are read against
-- already - and a review named from the command line references its revision
-- like `<Leader>rs` does, `main...` and the other ranges excepted: there is no
-- single state to show a file at, and they fall back to the index.
--
-- `<Leader>rc` ends the review: the tabpage closes and the buffers it opened go
-- with it, while the ones that were already open stay. `:tabclose` does half of
-- that - the files remain listed, and 'mini.tabline' shows every listed buffer.
-- Which only matters once there are many: for a review of five files, deleting
-- them one by one with `<Leader>bd` is the same thing.
--
-- Everything these mappings call lives in 'plugin/43_review.lua', under
-- `Config.review`.

nmap_leader('ra', '<Cmd>lua Config.review.staged()<CR>',       'Added files')
nmap_leader('rc', '<Cmd>lua Config.review.close()<CR>',        'Close review')
nmap_leader('rd', '<Cmd>lua Config.review.unstaged()<CR>',     'Diff files')
nmap_leader('rp', '<Cmd>lua Config.review.commit_only()<CR>',  'Commit files')
nmap_leader('rs', '<Cmd>lua Config.review.git()<CR>',          'Since commit files')

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
--   (`q`) to close the window and reload files it changed on disk. It is the
--   Git client of this config, so it is set up in 'plugin/41_git.lua'.
nmap_leader('tl', '<Cmd>lua Config.git.lazygit()<CR>', 'Lazygit')
nmap_leader('tT', '<Cmd>horizontal term<CR>',          'Terminal (horizontal)')
nmap_leader('tt', '<Cmd>vertical term<CR>',            'Terminal (vertical)')

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
