-- ┌─────────────────────┐
-- │ Git log and patches │
-- └─────────────────────┘
--
-- `:Git log` and `:Git diff` of 'mini.git', run only when there is output: with
-- none they open no window and say nothing, which reads like a broken mapping.

local core = require('config.git.core')

local M = {}

-- Layout shared with the blame annotation.
-- NOTE: the backslashes keep 'mini.git' from expanding `%h`, `%ad`, `%s` and the
-- `--date=format:` placeholders as file name modifiers (`:h cmdline-special`).
local git_log_cmd =
  [[Git log --pretty=format:\%h\ \%ad\ │\ \%s --date=format:\%Y-\%m-\%d\ \%H:\%M:\%S --topo-order]]

--- Git log of the repository (`buf_id == nil`) or of one file; `0` is the current buffer.
---@param buf_id integer|nil
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

-- Show `git diff <diff_args>` through 'mini.git' once `git diff --quiet` says
-- there is something to show. Outside a repository 'mini.git' would otherwise
-- print the whole usage of `git diff --no-index` for a key pressed in the wrong
-- directory. `label` names the selection after "No change to show"; `fallback`
-- runs in place of that warning.
-- NOTE: the probe costs a second run of Git, but it is `--quiet`: Git stops at
-- the first difference instead of formatting a patch.
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

--- Changes not staged yet / already staged, of the repository or of one buffer.
---@param buf_id integer|nil
M.diff_unstaged = function(buf_id) show_patch(buf_id, {}, 'not staged') end
M.diff_staged = function(buf_id) show_patch(buf_id, { '--cached' }, 'staged') end

-- The commit a patch is asked about, picked from the log (of one file when
-- `buf_id` names it) or given as `rev`.
-- NOTE: the path is resolved and `0` turned into a real buffer before the picker
-- starts: by the time `choose` runs the current buffer is the picker's. The window
-- opens safely because `show_patch()` asks Git first, landing after the picker closed.
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

--- Patch of what a commit changed by itself, against the commit before it.
-- NOTE: `<rev>^!` and not `<rev>~..<rev>`: the first commit has no parent to
-- name, while `^!` resolves against the empty tree (`:h gitrevisions`).
---@param buf_id integer|nil
---@param rev string|nil
M.diff_commit_only = function(buf_id, rev)
  local patch_of = function(id, commit)
    show_patch(id, { commit .. '^!' }, 'in ' .. commit)
  end
  pick_commit_patch(buf_id, rev, patch_of)
end

--- Patch of everything changed since a commit; when nothing has, the patch of
--- what the commit changed by itself.
---@param buf_id integer|nil
---@param rev string|nil
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
