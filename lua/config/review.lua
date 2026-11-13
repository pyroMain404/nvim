-- ┌────────┐
-- │ Review │
-- └────────┘
-- This module opens changed files in a new tabpage arglist for review as a set.
-- 'plugin/20_keymaps.lua' loads it by name.

local git = require('config.git')
local core = require('config.git.core')

local M = {}

local reviews = {}
local last_closed = nil

vim.api.nvim_create_autocmd('TabClosed', {
  group = vim.api.nvim_create_augroup('config-review', { clear = true }),
  callback = function(args) reviews[tonumber(args.match)] = nil end,
})

-- The review asks before loading more files than this limit. Loading half a repository freezes the
-- editor.
M.max_files = 50

local confirm = function(prompt, on_yes)
  vim.ui.input({ prompt = prompt .. ' (y/n) ' }, function(answer)
    if (answer or ''):lower() == 'y' then on_yes() end
  end)
end

-- Report one summary for a batch operation.
-- The caller must pass labels: files when opening, buffers when closing.
local report = function(message, done, failed, done_label, failed_label)
  local msg = message .. ': ' .. done .. ' ' .. done_label
  local level = vim.log.levels.INFO
  if failed > 0 then
    msg = msg .. ', ' .. failed .. ' ' .. failed_label
    level = vim.log.levels.WARN
  end
  vim.notify(msg, level)
end

-- Load and list files in a new tabpage with a window-local arglist (`:h :arglocal`).
--
-- NOTE: `bufadd()` creates an unlisted, unloaded buffer. The next two calls list and load it.
--
-- NOTE: Loading a file that another Neovim edits raises an error (`:h E325`).
-- Without `pcall`, the first error stops the loop and silently omits files from the review.
--
-- NOTE: A tabpage variable records buffers that the review creates.
-- This record distinguishes them from existing buffers, which closing must keep.
--
-- NOTE: `on_open` runs before the files load, so any diff reference that it sets applies when they load.
local open_arglist = function(paths, label, on_open)
  local existing = {}
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    existing[buf_id] = true
  end

  vim.cmd('tabnew')
  local escaped = vim.tbl_map(vim.fn.fnameescape, paths)
  vim.cmd('arglocal! ' .. table.concat(escaped, ' '))
  if on_open ~= nil then on_open() end

  local opened, unloaded = {}, 0
  for _, path in ipairs(paths) do
    local buf_id = vim.fn.bufadd(path)
    vim.bo[buf_id].buflisted = true
    if not pcall(vim.fn.bufload, buf_id) then unloaded = unloaded + 1 end
    if not existing[buf_id] then table.insert(opened, buf_id) end
  end
  vim.t.review_bufs = opened
  reviews[vim.api.nvim_get_current_tabpage()] =
    { paths = paths, label = label, on_open = on_open }

  report(
    'Review ' .. label,
    #paths,
    unloaded,
    'file(s)',
    'not loaded (open elsewhere?)'
  )
end

--- Open `paths` for review. Ask first for large reviews. Show `label` after "Review".
M.open = function(paths, label, on_open)
  paths = vim.tbl_map(
    function(path) return vim.fs.normalize(vim.fn.fnamemodify(path, ':p')) end,
    paths
  )
  -- Every source can include deleted or renamed paths. These paths have no file to open.
  paths = vim.tbl_filter(function(p) return vim.fn.filereadable(p) == 1 end, paths)
  if #paths == 0 then
    return vim.notify('No file to review ' .. label, vim.log.levels.WARN)
  end
  if #paths <= M.max_files then return open_arglist(paths, label, on_open) end

  confirm(
    #paths .. ' files to review. Open them all?',
    function() open_arglist(paths, label, on_open) end
  )
end

--- Open the last review closed with `M.close()` in this Neovim session.
M.resume = function()
  if last_closed == nil then
    return vim.notify('No closed review to resume', vim.log.levels.WARN)
  end
  M.open(last_closed.paths, last_closed.label, last_closed.on_open)
end

--- Close the current tabpage review. Remove its buffers. Restore the diff reference.
-- NOTE: Report buffers with unsaved changes instead of forcing deletion (`:h E89`).
-- NOTE: Read both tabpage variables before `:tabclose` changes the current tabpage.
M.close = function()
  local bufs, diff_ref = vim.t.review_bufs, vim.t.review_diff_ref
  if bufs == nil then
    return vim.notify('Not in a review tabpage', vim.log.levels.ERROR)
  end
  if #vim.api.nvim_list_tabpages() == 1 then
    local msg = 'Review is the only tabpage: nothing left to return to'
    return vim.notify(msg, vim.log.levels.WARN)
  end

  local review = reviews[vim.api.nvim_get_current_tabpage()]
  if not pcall(vim.cmd, 'tabclose') then
    return vim.notify('Could not close the review tabpage', vim.log.levels.ERROR)
  end
  if review ~= nil then last_closed = review end

  -- Schedule deletion after `:tabclose`. Immediate deletion can precede the asynchronous
  -- 'mini.git' status update and raise an error.
  vim.schedule(function()
    local kept = 0
    for _, buf_id in ipairs(bufs) do
      if vim.api.nvim_buf_is_valid(buf_id) then
        if not pcall(vim.api.nvim_buf_delete, buf_id, {}) then kept = kept + 1 end
      end
    end
    if diff_ref ~= nil and git.get_diff_ref() == diff_ref.set then
      git.set_diff_ref(nil, diff_ref.prev)
    end

    report(
      'Review closed',
      #bufs - kept,
      kept,
      'buffer(s) dropped',
      'kept (unsaved changes)'
    )
  end)
end

-- Pass paths from `git diff --name-only <diff_args>` to `M.open()`.
-- Use `fallback` instead of an empty review.
-- NOTE: Default `core.quotePath` makes Git quote non-ASCII paths.
-- These paths match no file on disk and would leave the review.
-- NOTE: Resolve a pathspec from the repository root. Name it in both messages.
local git_changed = function(diff_args, root, pathspec, label, on_open, fallback)
  local cmd = { 'git', '-c', 'core.quotePath=false', 'diff', '--name-only' }
  vim.list_extend(cmd, diff_args)
  local args = table.concat(diff_args, ' ')
  if pathspec ~= nil then
    local specs = type(pathspec) == 'string' and { pathspec } or pathspec
    vim.list_extend(cmd, { '--' })
    vim.list_extend(cmd, specs)
    local shown = '-- ' .. table.concat(specs, ' ')
    args, label = vim.trim(args .. ' ' .. shown), label .. ' ' .. shown
  end

  core.run(cmd, { cwd = root }, function(out)
    if out.code ~= 0 then
      return vim.notify(
        core.fail(out, vim.trim('git diff ' .. args)),
        vim.log.levels.ERROR
      )
    end
    local dir, paths = vim.fs.normalize(root), {}
    for _, line in
      ipairs(vim.split(out.stdout, '\n', { plain = true, trimempty = true }))
    do
      table.insert(paths, dir .. '/' .. vim.trim(line))
    end
    if #paths == 0 and fallback ~= nil then return fallback() end
    M.open(paths, label, on_open)
  end)
end

-- Set `rev` as the reference in every buffer. Record it in the tabpage for `M.close()`.
-- NOTE: A second review replaces the global reference of the first review.
-- Closing the first review keeps a reference that it did not set.
-- NOTE: `git show <rev>:<path>` cannot resolve a range such as `main...`.
-- Use its merge base to prevent silent index fallback for every file.
local reference_rev = function(rev)
  vim.t.review_diff_ref = { set = rev, prev = git.get_diff_ref() }
  git.set_diff_ref(nil, rev)
end

--- Review changes since `rev`, limited by `pathspec`. Pick from the log when `rev` is nil.
--- Use `rev` as the diff reference.
M.git = function(rev, pathspec)
  local root = git.require_root()
  if root == nil then return end
  local since = function(commit)
    local reference = function() reference_rev(commit) end
    local own = function()
      vim.notify('Nothing changed since ' .. commit .. ': reviewing what it changed')
      M.commit_only(commit, pathspec)
    end
    git_changed({ commit }, root, pathspec, 'since ' .. commit, reference, own)
  end
  if rev ~= nil then return since(rev) end

  git.pick_commit(nil, since)
end

--- Review only the changes from one commit against its parent.
-- NOTE: `<rev>^!` also works on the first commit (`:h gitrevisions`).
-- The reference stays `<rev>~`. The first commit has no parent, so its files use the index.
M.commit_only = function(rev, pathspec)
  local root = git.require_root()
  if root == nil then return end
  local only = function(commit)
    local reference = function() reference_rev(commit .. '~') end
    git_changed({ commit .. '^!' }, root, pathspec, 'in ' .. commit, reference)
  end
  if rev ~= nil then return only(rev) end

  git.pick_commit(nil, only)
end

M.unstaged = function(pathspec)
  local root = git.require_root()
  if root == nil then return end
  git_changed({}, root, pathspec, 'not staged')
end

M.staged = function(pathspec)
  local root = git.require_root()
  if root == nil then return end
  git_changed({ '--cached' }, root, pathspec, 'staged')
end

return M
