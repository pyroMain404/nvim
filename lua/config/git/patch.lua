-- ┌───────────────────────┐
-- │ Git output navigation │
-- └───────────────────────┘
--
-- Makes the scratch buffers of `:Git` (patches, logs) and of `:Pick git_commits`
-- navigable. See `:h MiniGit.show_at_cursor()` and `:h MiniGit.diff_foldexpr()`.

local core = require('config.git.core')

local M = {}

-- Width of the output column: the one the config files are written to, never
-- more than half of the screen. `textoff` is what line numbers and signs take.
local git_column_width = 85
local fit_git_column = function(win_id)
  if not vim.api.nvim_win_is_valid(win_id) then return end
  local width = math.min(git_column_width, math.floor(0.5 * vim.o.columns))
  vim.api.nvim_win_set_width(win_id, width + vim.fn.getwininfo(win_id)[1].textoff)
end

-- `<CR>` shows a commit (full width below the log) or a file (the column at the
-- far right), and the direction is needed before the call.
-- NOTE: 'mini.git' decides which of the two from the word at cursor, so the same
-- test is repeated here.
local is_commit_at_cursor = function()
  local cword = vim.fn.expand('<cword>')
  return cword:find('^%x%x%x%x%x%x%x+$') ~= nil and cword == cword:lower()
end

-- A file state at some commit is opened to see what that commit did to it, so
-- reference the state right before it (this buffer only, as `<Leader>gR`).
-- NOTE: `<Leader>gR` there leaves no reference at all: a copy has no index entry.
local diff_ref_at_parent = function(buf_id)
  local name = vim.api.nvim_buf_get_name(buf_id)
  local commit = name:match(core.patterns.show_commit)
  if commit == nil then return end
  require('config.git.diffref').set(buf_id, commit .. '~')
end

-- Only the first file opened from a patch takes a full height column at the far
-- right; every file after it opens below the previous one, so they are all
-- read in the same column. Closing that column starts a new one.
local win_file = nil
local win_file_is_usable = function()
  return win_file ~= nil
    and vim.api.nvim_win_is_valid(win_file)
    and vim.api.nvim_win_get_tabpage(win_file) == vim.api.nvim_win_get_tabpage(0)
end

-- Move the window the entry was opened in and keep the line 'mini.git' put the
-- cursor on.
-- NOTE: the window moves before it is drawn, so its view starts at line 1 while
-- the cursor is further down; setting the position again plus `zz` fixes the drift.
local place_win = function(win_init, direction)
  local pos = vim.api.nvim_win_get_cursor(0)
  if direction ~= 'L' then
    vim.cmd('wincmd ' .. direction)
  else
    local win_id = vim.api.nvim_get_current_win()
    if win_file_is_usable() then
      local below = { vertical = false, rightbelow = true }
      vim.fn.win_splitmove(win_id, win_file, below)
    else
      vim.cmd('wincmd L')
    end
    -- NOTE: `win_splitmove()` does not follow the window it moves.
    vim.api.nvim_set_current_win(win_id)
    win_file = win_id
    fit_git_column(win_init)
  end
  pcall(vim.api.nvim_win_set_cursor, 0, pos)
  vim.cmd('normal! zz')
end

-- `MiniGit.show_diff_source()` shows a scratch copy of the file, also for the
-- "after" state of a patch against the working tree. Reuse it to resolve path
-- and line of the entry at cursor, then edit the file itself to get a fully
-- functional buffer ('mini.diff', LSP).
local show_at_cursor = function()
  local win_init = vim.api.nvim_get_current_win()
  local is_commit = is_commit_at_cursor()
  local split = is_commit and 'horizontal' or 'vertical'

  -- The first call asks for the "after" state; the retry is for the one case it
  -- can legitimately miss, a deleted file. Any other failure repeats on identical
  -- input, so the first attempt is silenced and its message replayed when no
  -- retry follows.
  local warning = nil
  local notify = vim.notify
  vim.notify = function(msg, level) warning = { msg, level } end
  core.at_repo_root(MiniGit.show_at_cursor, { target = 'after', split = split })
  vim.notify = notify

  local no_after = '(mini.git) No "after" as file was deleted'
  if vim.api.nvim_get_current_win() == win_init then
    if warning ~= nil and warning[1] ~= no_after then
      vim.notify(warning[1], warning[2])
    else
      core.at_repo_root(MiniGit.show_at_cursor, { split = split })
    end
  end
  if vim.api.nvim_get_current_win() == win_init then return end
  place_win(win_init, is_commit and 'J' or 'L')

  -- Only the working tree state is edited; a state at some commit has no file.
  -- NOTE: 'mini.git' stores the path escaped for a command and relative to the root.
  local path = vim.api.nvim_buf_get_name(0):match(core.patterns.edit_path)
  if path == nil then return diff_ref_at_parent(0) end
  -- The buffer's own root: the cwd may be another repository than the patch's.
  local root = (MiniGit.get_buf_data(0) or {}).root or core.repo_root()
  if root ~= nil then
    path = vim.fn.fnameescape(vim.fs.normalize(root)) .. '/' .. path
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]

  -- Drop the fold options inherited from the patch before the file loads: `<`
  -- reads the global value, so run afterwards it would also undo the ftplugin's.
  vim.cmd('setlocal foldmethod< foldexpr< foldlevel<')
  vim.cmd('keepalt edit ' .. path)
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
  vim.cmd('normal! zv')
end

-- A state at some commit is always shown as a copy, in the same column
local show_diff_source = function()
  local win_init = vim.api.nvim_get_current_win()
  core.at_repo_root(MiniGit.show_diff_source, { split = 'vertical' })
  if vim.api.nvim_get_current_win() == win_init then return end
  place_win(win_init, 'L')
  diff_ref_at_parent(0)
end

--- `FileType git,diff` callback: `gf` on "a/path", folds by file/hunk, and
--- `<CR>`, `gF`, `q` in the scratch buffers of 'mini.nvim'.
M.setup_buf = function()
  vim.bo.includeexpr = [[substitute(v:fname, '^[abciwo]/', '', '')]]
  local root = core.repo_root()
  if root ~= nil then
    -- Escaped because space and comma separate the entries of 'path'.
    root = vim.fn.escape(vim.fs.normalize(root), ' ,')
    vim.bo.path = root .. ',' .. require('config.path').default
  end

  -- Start at the deepest fold level: with the global 'foldlevel' of 10 the first
  -- several `zm` would do nothing. Written with the second index so that the
  -- window options do not leak into every window opened afterwards.
  vim.wo[0][0].foldmethod = 'expr'
  vim.wo[0][0].foldexpr = 'v:lua.MiniGit.diff_foldexpr()'
  vim.wo[0][0].foldlevel = 3

  -- Mapped only in scratch buffers of 'mini.nvim' ("minigit://", "miniextra://"):
  -- it would shadow useful defaults inside a regular patch or commit file.
  if not vim.api.nvim_buf_get_name(0):find('^mini%a+://') then return end
  local bmap = function(lhs, rhs, desc)
    vim.keymap.set('n', lhs, rhs, { buf = 0, desc = desc })
  end
  bmap('<CR>', show_at_cursor, 'Show at cursor')
  bmap('gF', show_diff_source, 'Show diff source')
  bmap('q', '<Cmd>silent! close<CR>', 'Close output')
end

return M
