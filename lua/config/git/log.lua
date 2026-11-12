-- ┌─────────────────────┐
-- │ Git log and patches │
-- └─────────────────────┘
-- Run 'mini.git' `:Git log` and `:Git diff` only when output exists.
-- With no output, they open no window and show no message, which makes mappings appear broken.

local core = require('config.git.core')

local M = {}

-- Use the same layout as the blame annotation.
-- NOTE: Backslashes prevent 'mini.git' from expanding `%h`, `%ad`, `%s`, and `--date=format:`
-- placeholders
-- as file name modifiers (`:h cmdline-special`).
local git_log_cmd =
  [[Git log --pretty=format:\%h\ \%ad\ │\ \%s --date=format:\%Y-\%m-\%d\ \%H:\%M:\%S --topo-order]]

--- Show the repository log (`buf_id == nil`) or one file's log (`0`: current buffer).
M.log = function(buf_id)
  local postfix, label, path = '', 'here', nil
  if buf_id ~= nil then
    path = core.buf_path(buf_id)
    if path == nil then return end
    postfix = ' --follow -- ' .. vim.fn.fnameescape(path)
    label = vim.fn.fnamemodify(path, ':t')
  end
  local root = core.require_root(buf_id)
  if root == nil then return end
  local probe = { 'git', 'log', '--oneline', '-1' }
  if path ~= nil then vim.list_extend(probe, { '--follow', '--', path }) end
  core.run(probe, { cwd = root }, function(out)
    if out.code ~= 0 or vim.trim(out.stdout) == '' then
      return vim.notify('No commits for ' .. label, vim.log.levels.WARN)
    end
    vim.cmd(git_log_cmd .. postfix)
  end)
end

-- Show `git diff <diff_args>` only when `git diff --quiet` reports changes.
-- Outside a repository, 'mini.git' would show `git diff --no-index` usage.
-- Run `fallback` instead of the "No change to show" warning.
local show_patch = function(buf_id, diff_args, label, fallback)
  local root = core.require_root(buf_id)
  if root == nil then return end

  local probe_args, postfix = vim.deepcopy(diff_args), ''
  if buf_id ~= nil then
    local path = core.buf_path(buf_id)
    if path == nil then return end
    vim.list_extend(probe_args, { '--', path })
    postfix = ' -- ' .. vim.fn.fnameescape(path)
    label = label .. ' -- ' .. vim.fn.fnamemodify(path, ':t')
  end

  core.has_changes(probe_args, root, function(state)
    if state == 'clean' then
      if fallback ~= nil then return fallback() end
      return vim.notify('No change to show ' .. label, vim.log.levels.WARN)
    end
    if state ~= 'dirty' then return vim.notify(state, vim.log.levels.ERROR) end
    vim.cmd(vim.trim('Git diff ' .. table.concat(diff_args, ' ')) .. postfix)
  end)
end

--- Show unstaged or staged changes.
M.diff_unstaged = function(buf_id) show_patch(buf_id, {}, 'not staged') end
M.diff_staged = function(buf_id) show_patch(buf_id, { '--cached' }, 'staged') end

-- Select the patch commit from `rev` or the log picker.
-- NOTE: Resolve the path and replace `0` with a buffer id before opening the picker.
-- The picker becomes the current buffer before `choose` runs.
local pick_commit_patch = function(buf_id, rev, patch_of)
  if buf_id ~= nil then
    if core.buf_path(buf_id) == nil then return end
    buf_id = buf_id == 0 and vim.api.nvim_get_current_buf() or buf_id
  end
  local show = function(commit) patch_of(buf_id, commit) end
  if rev ~= nil then return show(rev) end

  local path = buf_id ~= nil and vim.api.nvim_buf_get_name(buf_id) or nil
  core.pick_commit(path, show)
end

--- Show only the changes from one commit.
-- NOTE: Use `<rev>^!`, not `<rev>~..<rev>`, to support the first commit (`:h gitrevisions`).
M.diff_commit_only = function(buf_id, rev)
  local patch_of = function(id, commit)
    show_patch(id, { commit .. '^!' }, 'in ' .. commit)
  end
  pick_commit_patch(buf_id, rev, patch_of)
end

--- Show all changes since a commit. If nothing changed, show only that commit's own changes.
M.diff_commit = function(buf_id, rev)
  local patch_of = function(id, commit)
    local own = function()
      vim.notify('Nothing changed since ' .. commit .. ': showing what it changed')
      M.diff_commit_only(id, commit)
    end
    show_patch(id, { commit }, 'since ' .. commit, own)
  end
  pick_commit_patch(buf_id, rev, patch_of)
end

return M
