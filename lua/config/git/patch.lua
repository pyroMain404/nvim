-- ┌───────────────────────┐
-- │ Git output navigation │
-- └───────────────────────┘
-- This module enables navigation in scratch buffers from `:Git` (patches, logs)
-- and `:Pick git_commits`.
-- See `:h MiniGit.show_at_cursor()` and `:h MiniGit.diff_foldexpr()`.

local core = require('config.git.core')

local M = {}

local git_column_width = 85
local fit_git_column = function(win_id)
  if not vim.api.nvim_win_is_valid(win_id) then return end
  local width = math.min(git_column_width, math.floor(0.5 * vim.o.columns))
  vim.api.nvim_win_set_width(win_id, width + vim.fn.getwininfo(win_id)[1].textoff)
end

-- `<CR>` shows a commit (full width below the log) or a file (far-right column).
-- NOTE: Repeat the test because 'mini.git' decides from the word under the cursor.
local is_commit_at_cursor = function()
  local cword = vim.fn.expand('<cword>')
  return cword:find('^%x%x%x%x%x%x%x+$') ~= nil and cword == cword:lower()
end

-- NOTE: `<Leader>gR` leaves no reference here because a copy has no index entry.
local diff_ref_at_parent = function(buf_id)
  local name = vim.api.nvim_buf_get_name(buf_id)
  local commit = name:match(core.patterns.show_commit)
  if commit == nil then return end
  require('config.git.diffref').set(buf_id, commit .. '~')
end

-- Open the first file from a patch in the far-right column. Open later files below it.
-- Start a new column if the previous column closes.
local win_file = nil
local win_file_is_usable = function()
  return win_file ~= nil
    and vim.api.nvim_win_is_valid(win_file)
    and vim.api.nvim_win_get_tabpage(win_file) == vim.api.nvim_win_get_tabpage(0)
end

-- NOTE: The window moves before drawing, so its view starts at line 1.
-- Set the position again. Center it with `zz`.
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

-- `MiniGit.show_diff_source()` shows a scratch copy. Use it to resolve the path and line.
-- Then edit the file itself for a functional buffer with 'mini.diff' and LSP.
local show_at_cursor = function()
  local win_init = vim.api.nvim_get_current_win()
  local is_commit = is_commit_at_cursor()
  local split = is_commit and 'horizontal' or 'vertical'

  -- The first call requests the "after" state. Retry only for a deleted file.
  -- Other failures repeat with identical input. Suppress the first warning and replay it when no
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

  -- NOTE: 'mini.git' stores the path escaped for a command and relative to the root.
  local path = vim.api.nvim_buf_get_name(0):match(core.patterns.edit_path)
  if path == nil then return diff_ref_at_parent(0) end
  -- Use the buffer's root because the cwd can belong to a different repository from the patch.
  local root = (MiniGit.get_buf_data(0) or {}).root or core.repo_root()
  if root ~= nil then
    path = vim.fn.fnameescape(vim.fs.normalize(root)) .. '/' .. path
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]

  -- Clear inherited patch fold options before loading the file.
  -- `<` reads global values, so running later would also undo the ftplugin settings.
  vim.cmd('setlocal foldmethod< foldexpr< foldlevel<')
  vim.cmd('keepalt edit ' .. path)
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
  vim.cmd('normal! zv')
end

local show_diff_source = function()
  local win_init = vim.api.nvim_get_current_win()
  core.at_repo_root(MiniGit.show_diff_source, { split = 'vertical' })
  if vim.api.nvim_get_current_win() == win_init then return end
  place_win(win_init, 'L')
  diff_ref_at_parent(0)
end

--- Configure `gf`, folds, and scratch-buffer mappings in the `FileType git,diff` callback.
M.setup_buf = function()
  vim.bo.includeexpr = [[substitute(v:fname, '^[abciwo]/', '', '')]]
  local root = core.repo_root()
  if root ~= nil then
    -- Escape spaces and commas because they separate 'path' entries.
    root = vim.fn.escape(vim.fs.normalize(root), ' ,')
    vim.bo.path = root .. ',' .. require('config.path').default
  end

  -- Start at the deepest fold level. The global 'foldlevel' of 10 makes the first `zm` do nothing.
  -- Use the second index to keep window options local.
  vim.wo[0][0].foldmethod = 'expr'
  vim.wo[0][0].foldexpr = 'v:lua.MiniGit.diff_foldexpr()'
  vim.wo[0][0].foldlevel = 3

  -- Map only in 'mini.nvim' scratch buffers ("minigit://", "miniextra://").
  -- These mappings would hide useful defaults in regular patch or commit files.
  if not vim.api.nvim_buf_get_name(0):find('^mini%a+://') then return end
  local bmap = function(lhs, rhs, desc)
    vim.keymap.set('n', lhs, rhs, { buf = 0, desc = desc })
  end
  bmap('<CR>', show_at_cursor, 'Show at cursor')
  bmap('gF', show_diff_source, 'Show diff source')
  bmap('q', '<Cmd>silent! close<CR>', 'Close output')
end

return M
