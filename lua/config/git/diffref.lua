-- ┌────────────────────────────────┐
-- │ Revision as 'mini.diff' source │
-- └────────────────────────────────┘
-- This module uses a file revision as the 'mini.diff' reference so recent commits appear as
-- uncommitted changes.

local core = require('config.git.core')

local M = {}

-- `diff_ref` holds the global revision. `nil` selects the Git index.
-- Each buffer can set its own revision in `vim.b.diff_ref`.
local diff_ref = nil

-- Locate a disk file or a commit file that 'mini.git' opens with its path in the buffer name.
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

-- Cache revision paths by (revision, directory). `attach` must respond synchronously.
-- Only the first attachment per pair waits for `git ls-tree`.
-- Clear the cache on every `set_diff_ref()` because a branch or commit can add files to `HEAD`.
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

-- NOTE: Buffer-local 'mini.diff' config merges into global config field by field, so set every
-- source field.
-- `apply_hunks` matters because staging uses the index, not `rev`.
local diff_source_at = function(rev)
  local attach = function(buf_id)
    local loc = buf_git_location(buf_id)
    if loc == nil then return false end
    local files = ls_tree(rev, loc.cwd)
    if not files[loc.path] then
      -- The Git source handles a path that the revision lacks.
      -- Exception: a buffer that shows a commit state is not a file, so the code reads its content
      -- as fully added.
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
  -- NOTE: 'mini.diff' calls this without `pcall` when `gh` stages a hunk.
  -- Use `error()` instead of `vim.notify()` because only an error can refuse staging.
  local apply_hunks = function()
    error('Hunks are shown against ' .. rev .. '. Restore the index to apply.')
  end
  return { name = 'git-' .. rev, attach = attach, apply_hunks = apply_hunks }
end

local diff_source_git = nil

--- Return the global reference revision, or `nil` for the Git index.
M.get = function() return diff_ref end

--- Set `rev` for all buffers (`buf_id == nil`) or one buffer (`0`: current).
--- Use `nil` to restore the Git index.
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
    -- NOTE: Restore a buffer by explicitly setting the index source.
    -- An unset source follows the global source, which can reference a revision.
    diff_source_git = diff_source_git or MiniDiff.gen_source.git()
    vim.b[buf_id].minidiff_config = { source = source or { diff_source_git } }
    bufs = { buf_id }
  end

  -- Reattach to apply reference text because the source sets it during attachment.
  -- Show the overlay wherever a revision serves as the reference.
  -- Enable commit states explicitly because 'mini.diff' enables itself only in file buffers.
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

--- Return diff statusline text for `buf_id`, or `nil` when nothing applies.
-- NOTE: `vim.b.diff_ref_index` distinguishes `@index (buf)` from a buffer that follows the global
-- reference.
-- Both have `vim.b.diff_ref == nil`.
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

-- Use the parent of `commit` when nothing has changed since it, to avoid an empty overlay.
-- NOTE: Keep the first commit because it has no parent. Its overlay stays empty.
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

--- Reference `rev`, or pick a commit from the log.
--- Restore the index if a revision already serves as the reference in `buf_id`, or globally when
--- `nil`.
-- NOTE: Resolve `0` before opening the picker because the picker becomes the current buffer.
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

--- Toggle the in-buffer overlay. `MiniDiff.toggle_overlay()` raises an error when 'mini.diff' is
--- not enabled for the buffer.
M.toggle_overlay = function()
  local buf_id = vim.api.nvim_get_current_buf()
  if MiniDiff.get_buf_data(buf_id) == nil then
    return vim.notify('mini.diff is not enabled here', vim.log.levels.WARN)
  end
  MiniDiff.toggle_overlay(buf_id)
  vim.cmd.redrawstatus({ bang = true })
end

return M
