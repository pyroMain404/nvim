-- ┌────────────────────────────────┐
-- │ Revision as 'mini.diff' source │
-- └────────────────────────────────┘
--
-- Uses the file at some revision as reference text of 'mini.diff', so that the
-- latest commits read as if they were not committed yet.

local core = require('config.git.core')

local M = {}

-- Global revision, `nil` for the Git index; a single buffer carries its own in `vim.b.diff_ref`.
local diff_ref = nil

-- A file on disk, or a file at some commit that 'mini.git' opens (its path is in the buffer name).
local buf_git_location = function(buf_id)
  local name = vim.api.nvim_buf_get_name(buf_id)
  local path_at_commit = name:match(core.patterns.show_path)
  if path_at_commit ~= nil then
    local root = core.repo_root()
    if root == nil then return nil end
    return { cwd = root, path = path_at_commit, at_commit = true }
  end
  if vim.fn.filereadable(name) ~= 1 then return nil end
  local dir, base = vim.fn.fnamemodify(name, ':h'), vim.fn.fnamemodify(name, ':t')
  return { cwd = dir, path = base, at_commit = false }
end

-- Per-(revision, directory) set of the paths a revision has: `attach` must answer
-- synchronously, so only the first attach per pair blocks on `git ls-tree`. Cleared
-- on every `set_diff_ref()`, as a branch or commit can add files to `HEAD`.
local ls_tree_cache = {}
local ls_tree = function(rev, cwd)
  local key = rev .. '\30' .. cwd
  if ls_tree_cache[key] ~= nil then return ls_tree_cache[key] end
  local out = vim
    .system({ 'git', 'ls-tree', '-r', '--name-only', rev }, { cwd = cwd, text = true })
    :wait()
  local files = {}
  if out.code == 0 then
    for _, line in ipairs(vim.split(out.stdout, '\n', { trimempty = true })) do
      files[line] = true
    end
  end
  ls_tree_cache[key] = files
  return files
end

-- NOTE: a buffer-local 'mini.diff' config merges field by field into the global
-- one, so every field of the source is set; `apply_hunks` is the one that
-- matters, as staging happens against the index and not `rev`.
local diff_source_at = function(rev)
  local attach = function(buf_id)
    local loc = buf_git_location(buf_id)
    if loc == nil then return false end
    local files = ls_tree(rev, loc.cwd)
    if not files[loc.path] then
      -- A path the revision lacks is left to the Git source, except for a state
      -- at some commit, which is not a file: read it as fully added.
      if not loc.at_commit then return false end
      return MiniDiff.set_ref_text(buf_id, '')
    end
    local cmd = { 'git', 'show', rev .. ':./' .. loc.path }
    core.run(cmd, { cwd = loc.cwd }, function(out)
      if out.code ~= 0 then
        local cmd_desc = ('`git show %s:./%s` failed'):format(rev, loc.path)
        vim.notify(core.fail(out, cmd_desc), vim.log.levels.ERROR)
        return
      end
      MiniDiff.set_ref_text(buf_id, (out.stdout:gsub('\r\n', '\n')))
    end)
  end
  -- NOTE: `error()` and not `vim.notify()` is right here: 'mini.diff' calls this
  -- without a `pcall` when `gh` stages a hunk, so raising is the only way to refuse.
  local apply_hunks = function()
    error('Hunks are shown against ' .. rev .. '. Restore the index to apply.')
  end
  return { name = 'git-' .. rev, attach = attach, apply_hunks = apply_hunks }
end

local diff_source_git = nil

--- Revision referenced in every buffer, `nil` for the Git index.
M.get = function() return diff_ref end

--- Reference `rev` in every buffer (`buf_id == nil`) or one (`0`: current); `nil` restores the Git index.
M.set = function(buf_id, rev)
  ls_tree_cache = {}
  local source = rev ~= nil and diff_source_at(rev) or nil
  local bufs = vim.api.nvim_list_bufs()
  if buf_id == nil then
    diff_ref, MiniDiff.config.source = rev, source
  else
    buf_id = buf_id == 0 and vim.api.nvim_get_current_buf() or buf_id
    vim.b[buf_id].diff_ref = rev
    vim.b[buf_id].diff_ref_index = rev == nil
    -- NOTE: a per-buffer restore must write the index source explicitly; left
    -- unset, the buffer follows the global source, which may be a revision.
    diff_source_git = diff_source_git or MiniDiff.gen_source.git()
    vim.b[buf_id].minidiff_config = { source = source or { diff_source_git } }
    bufs = { buf_id }
  end

  -- Reference text is set while the source attaches, so reattach to apply it.
  -- The overlay is shown wherever a revision is referenced. 'mini.diff' enables
  -- itself only in file buffers, so a state at some commit is enabled by hand.
  local force_enable = buf_id ~= nil and rev ~= nil
  for _, id in ipairs(bufs) do
    local is_enabled = MiniDiff.get_buf_data(id) ~= nil
    if is_enabled then MiniDiff.disable(id) end
    if is_enabled or force_enable then
      MiniDiff.enable(id)
      local data = MiniDiff.get_buf_data(id)
      local has_rev = (vim.b[id].diff_ref or diff_ref) ~= nil
      local show_overlay = has_rev and data ~= nil and not data.overlay
      if show_overlay then MiniDiff.toggle_overlay(id) end
    end
  end

  local suffix = buf_id ~= nil and ' (buffer)' or ''
  vim.notify('Diff reference' .. suffix .. ': ' .. (rev or 'Git index'))
  vim.cmd.redrawstatus({ bang = true })
end

--- What the statusline says about the diff of `buf_id`, `nil` when nothing.
-- NOTE: `vim.b.diff_ref_index` tells `@index (buf)` from a buffer following the
-- global reference: both have `vim.b.diff_ref == nil`.
M.label = function(buf_id)
  local data = _G.MiniDiff ~= nil and MiniDiff.get_buf_data(buf_id) or nil
  if data == nil then return nil end

  local label
  if vim.b[buf_id].diff_ref ~= nil then
    label = '@' .. vim.b[buf_id].diff_ref .. ' (buf)'
  elseif diff_ref ~= nil and vim.b[buf_id].diff_ref_index then
    label = '@index (buf)'
  elseif diff_ref ~= nil then
    label = '@' .. diff_ref
  elseif data.overlay then
    label = '@index'
  else
    return nil
  end
  return data.overlay and label or (label .. ' (off)')
end

-- The revision to reference once `commit` is chosen: its parent when nothing
-- changed since it, which would show an empty overlay.
-- NOTE: the first commit has no parent, so it is kept and the overlay stays empty.
local reference_for = function(buf_id, commit, on_done)
  local root = core.require_root(buf_id)
  if root == nil then return end
  local diff_args = { commit }
  if buf_id ~= nil then
    local path = core.buf_path(buf_id)
    if path == nil then return end
    vim.list_extend(diff_args, { '--', path })
  end
  core.has_changes(diff_args, root, function(state)
    if state == 'dirty' then return on_done(commit) end
    if state ~= 'clean' then return vim.notify(state, vim.log.levels.ERROR) end
    local parent = commit .. '~'
    local probe =
      { 'git', 'rev-parse', '--verify', '--quiet', parent .. '^{commit}' }
    core.run(probe, { cwd = root }, function(p)
      if p.code ~= 0 then
        vim.notify('Nothing changed since ' .. commit .. ', which has no parent')
        return on_done(commit)
      end
      vim.notify('Nothing changed since ' .. commit .. ': referencing its parent')
      on_done(parent)
    end)
  end)
end

--- Reference `rev`, or a commit picked from the log; restore the index when a
--- revision is already referenced (in `buf_id`, or everywhere when `nil`).
-- NOTE: `0` is resolved before the picker starts: by the time a commit is
-- chosen, the current buffer is the picker.
M.toggle = function(buf_id, rev)
  local cur_ref = diff_ref
  if buf_id ~= nil then
    buf_id = buf_id == 0 and vim.api.nvim_get_current_buf() or buf_id
    cur_ref = vim.b[buf_id].diff_ref
  end
  if cur_ref ~= nil then return M.set(buf_id, nil) end

  local apply = function(commit)
    reference_for(buf_id, commit, function(target) M.set(buf_id, target) end)
  end
  if rev ~= nil then return apply(rev) end

  local path = nil
  if buf_id ~= nil then
    path = core.buf_path(buf_id)
    if path == nil then return end
  end
  core.pick_commit(path, apply)
end

--- Turn the in-buffer overlay on and off; `MiniDiff.toggle_overlay()` raises on
--- a buffer where 'mini.diff' is not enabled.
M.toggle_overlay = function()
  local buf_id = vim.api.nvim_get_current_buf()
  if MiniDiff.get_buf_data(buf_id) == nil then
    return vim.notify('mini.diff is not enabled here', vim.log.levels.WARN)
  end
  MiniDiff.toggle_overlay(buf_id)
  vim.cmd.redrawstatus({ bang = true })
end

return M
