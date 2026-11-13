-- ┌─────────────────┐
-- │ Custom mappings │
-- └─────────────────┘
--
-- This file defines custom general and Leader mappings.

-- General mappings ===========================================================

local nmap = function(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { desc = desc }) end

-- Paste lines without indentation. This mapping replaces `]p` (`:h ]p`).
nmap('[p', '<Cmd>exe "iput! " . v:register<CR>', 'Paste Above')
nmap(']p', '<Cmd>exe "iput "  . v:register<CR>', 'Paste Below')

-- Paste from the system clipboard with the cursor after the text (`:h gp`, `:h gP`).
vim.keymap.set(
  { 'n', 'x' },
  'gp',
  '"+gp',
  { desc = 'Paste after, move cursor (clipboard)' }
)
vim.keymap.set(
  { 'n', 'x' },
  'gP',
  '"+gP',
  { desc = 'Paste before, move cursor (clipboard)' }
)

nmap('<C-S-H>', '<C-w>H', 'Move to very left')
nmap('<C-S-J>', '<C-w>J', 'Move to very bottom')
nmap('<C-S-K>', '<C-w>K', 'Move to very top')
nmap('<C-S-L>', '<C-w>L', 'Move to very right')

-- Toggle 'mini.completion' for the current buffer beside 'mini.basics' toggles (`\b`, `\w`, ...).
-- See `:h mini.nvim-disabling-recipes`.
nmap('\\a', function()
  vim.b.minicompletion_disable = not vim.b.minicompletion_disable
  vim.notify('Autocompletion ' .. (vim.b.minicompletion_disable and 'off' or 'on'))
end, "Toggle 'mini.completion' (buffer)")

-- This mapping swaps adjacent arguments with 'mini.ai' `a` and 'mini.operators' `gx`.
-- This mapping overrides `(` and `)` (`:h (`, `:h )`).
vim.keymap.set('n', '(', 'gxiagxila', { remap = true, desc = 'Swap arg left' })
vim.keymap.set('n', ')', 'gxiagxina', { remap = true, desc = 'Swap arg right' })

-- Search jumps refresh 'mini.map'; `zv` opens enough folds to show the match.
local map_refresh =
  '<Cmd>lua MiniMap.refresh({}, { lines = false, scrollbar = false })<CR>'
nmap('n', 'nzv' .. map_refresh, 'Next match')
nmap('N', 'Nzv' .. map_refresh, 'Previous match')
nmap('*', '*zv' .. map_refresh, 'Star')
nmap('#', '#zv' .. map_refresh, 'Hash')

-- stylua: ignore start
-- Leader mappings ============================================================

-- After `<Leader>`, the first key selects the group and the second key selects the action
-- (`:h <Leader>`).

-- Define Leader group names for 'mini.clue'.
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

-- These helpers define Leader mappings.
-- A `<Cmd>` RHS needs no loaded module at mapping time (`:h <Cmd>`).
local nmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('n', '<Leader>' .. suffix, rhs, { desc = desc })
end
local xmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('x', '<Leader>' .. suffix, rhs, { desc = desc })
end

-- b is for 'Buffer'.
nmap_leader('ba', '<Cmd>b#<CR>',                                 'Alternate')
nmap_leader('bd', '<Cmd>lua MiniBufremove.delete()<CR>',         'Delete')
nmap_leader('bD', '<Cmd>lua MiniBufremove.delete(0, true)<CR>',  'Delete!')
nmap_leader('bs', function() vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true)) end, 'Scratch')
nmap_leader('bw', '<Cmd>lua MiniBufremove.wipeout()<CR>',        'Wipeout')
nmap_leader('bW', '<Cmd>lua MiniBufremove.wipeout(0, true)<CR>', 'Wipeout!')

-- e is for 'Explore' and 'Edit'; `eg` is in 'lua/config/glance.lua'.
-- NOTE: The code resolves the config path (`:h resolve()`). The startup junction hides the root marker.
-- Without a root marker, `lua_ls` starts in single file mode without diagnostics.
local config_file = function(relative)
  local path = vim.fn.resolve(vim.fn.stdpath('config') .. '/' .. relative)
  return string.format('<Cmd>edit %s<CR>', vim.fn.fnameescape(path))
end
local edit_plugin_file = function(filename)
  return config_file('plugin/' .. filename)
end
local explore_quickfix = function()
  vim.cmd(vim.fn.getqflist({ winid = true }).winid ~= 0 and 'cclose' or 'copen')
end
local explore_locations = function()
  vim.cmd(vim.fn.getloclist(0, { winid = true }).winid ~= 0 and 'lclose' or 'lopen')
end

-- Open the history in its own tabpage, like the `<Leader>g` outputs.
-- `q` closes it.
local show_notification_history = function()
  -- `:tab split` keeps the current buffer and leaves no unused empty buffer (`:h :tab`).
  vim.cmd('tab split')
  MiniNotify.show_history()
  -- Neovim creates the history buffer as listed. Unlist it because `q` closes it.
  vim.bo.buflisted = false
  vim.keymap.set('n', 'q', '<Cmd>silent! close<CR>', { buffer = 0, desc = 'Close notification history' })
end

nmap_leader('ed', '<Cmd>lua MiniFiles.open()<CR>',                             'Directory')
nmap_leader('ef', '<Cmd>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>', 'File directory')
nmap_leader('eg', function() require('config.glance').open() end,              'Glance at file')
nmap_leader('ei', config_file('init.lua'),                                     'init.lua')
nmap_leader('ek', edit_plugin_file('20_keymaps.lua'),                          'Keymaps config')
nmap_leader('em', edit_plugin_file('30_mini.lua'),                             'MINI config')
nmap_leader('en', show_notification_history,                                  'Notifications')
nmap_leader('eo', edit_plugin_file('10_options.lua'),                          'Options config')
nmap_leader('ep', edit_plugin_file('40_plugins.lua'),                          'Plugins config')
nmap_leader('eq', explore_quickfix,                                            'Quickfix list')
nmap_leader('eQ', explore_locations,                                           'Location list')
nmap_leader('es', '<Cmd>lua MiniStarter.open()<CR>',                           'Start menu')

-- f is for 'Fuzzy Find' (`:h MiniPick-overview`).

-- HACK: `:Pick ... path="%"` fails on Windows because 'mini.pick' reads arguments as Lua.
-- Lua reads path backslashes as escapes. The code calls the picker directly.
-- Remove this workaround when upstream fixes it
-- (mini.nvim f9ac12d, locked 2026-11-09, not retested).
local pick_buf_path = function(picker, scope)
  return function()
    local path = vim.api.nvim_buf_get_name(0)
    if path == '' then
      return vim.notify('Buffer is not a file on disk', vim.log.levels.WARN)
    end
    MiniExtra.pickers[picker]({ path = path, scope = scope })
  end
end

nmap_leader('f/', '<Cmd>Pick history scope="/"<CR>',                 '"/" history')
nmap_leader('f:', '<Cmd>Pick history scope=":"<CR>',                 '":" history')
nmap_leader('fa', '<Cmd>Pick git_hunks scope="staged"<CR>',          'Added hunks (all)')
nmap_leader('fA', pick_buf_path('git_hunks', 'staged'),              'Added hunks (buf)')
nmap_leader('fb', '<Cmd>Pick buffers<CR>',                           'Buffers')
nmap_leader('fc', '<Cmd>Pick git_commits<CR>',                       'Commits (all)')
nmap_leader('fC', pick_buf_path('git_commits'),                      'Commits (buf)')
nmap_leader('fd', '<Cmd>Pick diagnostic scope="all"<CR>',            'Diagnostic workspace')
nmap_leader('fD', '<Cmd>Pick diagnostic scope="current"<CR>',        'Diagnostic buffer')
nmap_leader('ff', '<Cmd>Pick files<CR>',                             'Files')
nmap_leader('fg', '<Cmd>Pick grep_live<CR>',                         'Grep live')
nmap_leader('fG', '<Cmd>Pick grep pattern="<cword>"<CR>',            'Grep current word')
nmap_leader('fh', '<Cmd>Pick help<CR>',                              'Help tags')
nmap_leader('fH', '<Cmd>Pick hl_groups<CR>',                         'Highlight groups')
nmap_leader('fl', '<Cmd>Pick buf_lines scope="all"<CR>',             'Lines (all)')
nmap_leader('fL', '<Cmd>Pick buf_lines scope="current"<CR>',         'Lines (buf)')
nmap_leader('fm', '<Cmd>Pick git_hunks<CR>',                         'Modified hunks (all)')
nmap_leader('fM', pick_buf_path('git_hunks'),                        'Modified hunks (buf)')
nmap_leader('fr', '<Cmd>Pick resume<CR>',                            'Resume')
nmap_leader('fR', '<Cmd>Pick lsp scope="references"<CR>',            'References (LSP)')
nmap_leader('fs', '<Cmd>Pick lsp scope="workspace_symbol_live"<CR>', 'Symbols workspace (live)')
nmap_leader('fS', '<Cmd>Pick lsp scope="document_symbol"<CR>',       'Symbols document')
nmap_leader('ft', '<Cmd>HipatternsLoc<CR>',                          'Todo/Fixme/Hack/Note (buf)')
nmap_leader('fT', '<Cmd>HipatternsGrep<CR>',                         'Todo/Fixme/Hack/Note (all)')
nmap_leader('fv', '<Cmd>Pick visit_paths cwd=""<CR>',                'Visit paths (all)')
nmap_leader('fV', '<Cmd>Pick visit_paths<CR>',                       'Visit paths (cwd)')

-- g is for 'Git'; functions load on demand from 'lua/config/git'.

nmap_leader('ga', "<Cmd>lua require('config.git').diff_staged()<CR>",       'Added diff')
nmap_leader('gA', "<Cmd>lua require('config.git').diff_staged(0)<CR>",      'Added diff buffer')
nmap_leader('gb', "<Cmd>lua require('config.git').toggle_blame()<CR>",      'Blame line (toggle)')
nmap_leader('gc', '<Cmd>Git commit<CR>',                                    'Commit')
nmap_leader('gC', '<Cmd>Git commit --amend<CR>',                            'Commit amend')
nmap_leader('gd', "<Cmd>lua require('config.git').diff_unstaged()<CR>",     'Diff')
nmap_leader('gD', "<Cmd>lua require('config.git').diff_unstaged(0)<CR>",    'Diff buffer')
nmap_leader('gi', '<Cmd>lua MiniGit.show_at_cursor()<CR>',                  'Info at cursor')
nmap_leader('gl', "<Cmd>lua require('config.git').log()<CR>",               'Log')
nmap_leader('gL', "<Cmd>lua require('config.git').log(0)<CR>",              'Log buffer')
nmap_leader('go', "<Cmd>lua require('config.git').toggle_overlay()<CR>",    'Toggle overlay')
nmap_leader('gp', "<Cmd>lua require('config.git').diff_commit_only()<CR>",  'Commit patch')
nmap_leader('gP', "<Cmd>lua require('config.git').diff_commit_only(0)<CR>", 'Commit patch buffer')
nmap_leader('gr', "<Cmd>lua require('config.git').toggle_diff_ref()<CR>",   'Reference revision')
nmap_leader('gR', "<Cmd>lua require('config.git').toggle_diff_ref(0)<CR>",  'Reference revision buffer')
nmap_leader('gs', "<Cmd>lua require('config.git').diff_commit()<CR>",       'Since commit')
nmap_leader('gS', "<Cmd>lua require('config.git').diff_commit(0)<CR>",      'Since commit buffer')

xmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>', 'Show at selection')

-- l is for 'Language'; `lf` formats the changed lines ('lua/config/format.lua').
-- NOTE: 'mini.operators' uses `gr` to replace text.
-- LSP mappings therefore use this group instead of the default `gra` (`:h gra`).
-- `:make` stays synchronous; `:Make` ('lua/config/make.lua') is asynchronous.
nmap_leader('la', '<Cmd>lua vim.lsp.buf.code_action()<CR>',          'Actions')
nmap_leader('ld', '<Cmd>lua vim.diagnostic.open_float()<CR>',        'Diagnostic popup')
nmap_leader('lf', "<Cmd>lua require('config.format').changed()<CR>", 'Format changed')
nmap_leader('lF', "<Cmd>lua require('config.format').buffer()<CR>",  'Format buffer')
nmap_leader('li', '<Cmd>lua vim.lsp.buf.implementation()<CR>',       'Implementation')
nmap_leader('lh', '<Cmd>lua vim.lsp.buf.hover()<CR>',                'Hover')
nmap_leader('ll', '<Cmd>lua vim.lsp.codelens.run()<CR>',             'Lens')
nmap_leader('lr', '<Cmd>lua vim.lsp.buf.rename()<CR>',               'Rename')
nmap_leader('lR', '<Cmd>lua vim.lsp.buf.references()<CR>',           'References')
nmap_leader('ls', '<Cmd>lua vim.lsp.buf.definition()<CR>',           'Source definition')
nmap_leader('lt', '<Cmd>lua vim.lsp.buf.type_definition()<CR>',      'Type definition')

xmap_leader('lf', "<Cmd>lua require('config.format').selection()<CR>", 'Format selection')

-- m is for 'Map'.
nmap_leader('mf', '<Cmd>lua MiniMap.toggle_focus()<CR>', 'Focus (toggle)')
nmap_leader('mr', '<Cmd>lua MiniMap.refresh()<CR>',      'Refresh')
nmap_leader('ms', '<Cmd>lua MiniMap.toggle_side()<CR>',  'Side (toggle)')
nmap_leader('mt', '<Cmd>lua MiniMap.toggle()<CR>',       'Toggle')

-- o is for 'Other'.

nmap_leader('or', '<Cmd>lua MiniMisc.resize_window()<CR>',   'Resize to default width')
nmap_leader('ot', '<Cmd>lua MiniTrailspace.trim()<CR>',      'Trim trailspace')
nmap_leader('oy', '<Cmd>let @+ = expand("%:p")<CR>', 'Copy full file path')
nmap_leader('oz', '<Cmd>lua MiniMisc.zoom()<CR>',            'Zoom toggle')

-- r is for 'Review'; functions live in 'lua/config/review.lua'.

nmap_leader('ra', "<Cmd>lua require('config.review').staged()<CR>",      'Added files')
nmap_leader('rc', "<Cmd>lua require('config.review').close()<CR>",       'Close review')
nmap_leader('rd', "<Cmd>lua require('config.review').unstaged()<CR>",    'Diff files')
nmap_leader('rp', "<Cmd>lua require('config.review').commit_only()<CR>", 'Commit files')
nmap_leader('rs', "<Cmd>lua require('config.review').git()<CR>",         'Since commit files')

-- s is for 'Session'.

nmap_leader('sd', '<Cmd>lua MiniSessions.select("delete")<CR>',                                   'Delete')
nmap_leader('sn', '<Cmd>lua vim.ui.input({ prompt = "Session name: " }, MiniSessions.write)<CR>', 'New')
nmap_leader('sr', '<Cmd>lua MiniSessions.select("read")<CR>',                                     'Read')
nmap_leader('sR', '<Cmd>lua MiniSessions.restart()<CR>',                                          'Restart')
nmap_leader('sw', '<Cmd>lua MiniSessions.write()<CR>',                                            'Write current')

-- t is for 'Terminal'; lazygit lives in 'lua/config/git/lazygit.lua'.
nmap_leader('tl', "<Cmd>lua require('config.git').lazygit()<CR>", 'Lazygit')
nmap_leader('tT', '<Cmd>horizontal term<CR>',                     'Terminal (horizontal)')
nmap_leader('tt', '<Cmd>vertical term<CR>',                       'Terminal (vertical)')

-- v is for 'Visits'.
local make_pick_core = function(cwd, desc)
  return function()
    local sort_latest = MiniVisits.gen_sort.default({ recency_weight = 1 })
    MiniExtra.pickers.visit_paths({ cwd = cwd, filter = 'core', sort = sort_latest }, { source = { name = desc } })
  end
end

nmap_leader('vc', make_pick_core('',  'Core visits (all)'),       'Core visits (all)')
nmap_leader('vC', make_pick_core(nil, 'Core visits (cwd)'),       'Core visits (cwd)')
nmap_leader('vv', '<Cmd>lua MiniVisits.add_label("core")<CR>',    'Add "core" label')
nmap_leader('vV', '<Cmd>lua MiniVisits.remove_label("core")<CR>', 'Remove "core" label')
nmap_leader('vl', '<Cmd>lua MiniVisits.add_label()<CR>',          'Add label')
nmap_leader('vL', '<Cmd>lua MiniVisits.remove_label()<CR>',       'Remove label')
-- stylua: ignore end
