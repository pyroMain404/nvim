-- ┌────────┐
-- │ Review │
-- └────────┘
--
-- Opens the files a change touched as the argument list of a new tabpage, to be
-- read as a set. A source is anything producing paths; Git is the first.
-- Required by name from 'plugin/20_keymaps.lua'.

local git = require('config.git')
local core = require('config.git.core')

local M = {}

-- Past this many files the review opens only after a confirmation: a commit far
-- back names half the repository, and loading it freezes the editor.
M.max_files = 50

-- Ask a yes/no question and run `on_yes` only on a clear 'y'.
local confirm = function(prompt, on_yes)
  vim.ui.input({ prompt = prompt .. ' (y/n) ' }, function(answer)
    if (answer or ''):lower() == 'y' then on_yes() end
  end)
end

-- One summary of a batch operation, WARN when something failed. The labels are
-- required: an item is a file when opening a review and a buffer when closing one.
local report = function(message, done, failed, done_label, failed_label)
  local msg = message .. ': ' .. done .. ' ' .. done_label
  local level = vim.log.levels.INFO
  if failed > 0 then
    msg = msg .. ', ' .. failed .. ' ' .. failed_label
    level = vim.log.levels.WARN
  end
  vim.notify(msg, level)
end

-- Argument list local to the window of a new tabpage (`:h :arglocal`): it starts
-- empty and the global list is left alone. The files are loaded and listed right
-- away, so the whole set is one `:bnext` away and shows in the picker and tabline.
-- NOTE: `bufadd()` creates a buffer neither listed nor loaded, hence the two calls after it.
-- NOTE: loading throws on a file another Neovim edits (`:h E325`); without the
-- `pcall` the first such file ends the loop and the review silently misses files.
-- NOTE: the buffers the review created go in a tabpage variable, as afterwards a
-- file already open is indistinguishable from one it opened, and closing must keep it.
-- NOTE: `on_open` runs before the files load, so what it sets (a diff reference)
-- is what they are loaded against.
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

  report(
    'Review ' .. label,
    #paths,
    unloaded,
    'file(s)',
    'not loaded (open elsewhere?)'
  )
end

--- Open `paths` as the review, asking first when it is a big one. `label` reads
--- after the word "Review"; `on_open` is what the source does once the tabpage exists.
---@param paths string[]
---@param label string
---@param on_open function|nil
M.open = function(paths, label, on_open)
  -- A path the change deleted or renamed away has nothing to open behind it;
  -- every source produces some, so they are dropped here.
  paths = vim.tbl_filter(function(p) return vim.fn.filereadable(p) == 1 end, paths)
  paths = vim.tbl_map(vim.fs.normalize, paths)
  if #paths == 0 then
    return vim.notify('No file to review ' .. label, vim.log.levels.WARN)
  end
  if #paths <= M.max_files then return open_arglist(paths, label, on_open) end

  confirm(
    #paths .. ' files to review. Open them all?',
    function() open_arglist(paths, label, on_open) end
  )
end

--- Close the review of the current tabpage: drop the buffers it opened (the
--- ones already open before stay) and restore the diff reference it found, unless
--- that was changed by hand meanwhile.
-- NOTE: a buffer with unsaved changes refuses to be deleted (`:h E89`) and is
-- reported, not forced.
-- NOTE: both tabpage variables are read before `:tabclose`, after which they are
-- those of whatever tabpage the closing lands in.
M.close = function()
  local bufs, diff_ref = vim.t.review_bufs, vim.t.review_diff_ref
  if bufs == nil then
    return vim.notify('Not in a review tabpage', vim.log.levels.ERROR)
  end
  if #vim.api.nvim_list_tabpages() == 1 then
    local msg = 'Review is the only tabpage: nothing left to return to'
    return vim.notify(msg, vim.log.levels.WARN)
  end

  if not pcall(vim.cmd, 'tabclose') then
    return vim.notify('Could not close the review tabpage', vim.log.levels.ERROR)
  end

  -- Scheduled: 'mini.git' updates its own status asynchronously, and deleting a
  -- buffer right after `:tabclose` can run ahead of that update and raise.
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

-- Files `git diff --name-only <diff_args>` lists, handed to `M.open()`. `label`
-- says the same in words; `fallback` runs instead of opening an empty review.
-- Asynchronous, so the callback runs once a picker has closed and a window can open.
-- NOTE: with the default `core.quotePath`, Git quotes paths holding non-ASCII
-- ("caff\303\250.lua"), which match no file on disk and would drop out of the review.
-- NOTE: a pathspec (string or list) is read from the repository root and named in
-- both messages, so a review limited to a directory that finds nothing says which.
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

-- Reference `rev` in every buffer (what `<Leader>gr` does) and record it and the
-- reference it replaces in the tabpage, for `M.close()`.
-- NOTE: the reference is global, so a second review over the first takes it over;
-- closing the first afterwards finds a reference it did not set and leaves it.
-- NOTE: a range such as `main...` is not a state `git show <rev>:<path>` resolves,
-- so every file falls back to the index silently; reference its merge base instead.
local reference_rev = function(rev)
  vim.t.review_diff_ref = { set = rev, prev = git.get_diff_ref() }
  git.set_diff_ref(nil, rev)
end

--- Review the files changed since `rev` (picked from the log when `nil`),
--- narrowed by `pathspec`. The revision becomes the diff reference. When nothing
--- changed since it, the files the commit changed by itself are reviewed.
-- NOTE: the root is resolved before the picker, so a call outside a repository
-- is refused right away.
---@param rev string|nil
---@param pathspec string|string[]|nil
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

--- Review the files a commit changed by itself, read against its parent.
-- NOTE: `<rev>^!` names the commit excluding its parents (`:h gitrevisions`) and
-- works on the first commit too; the reference stays `<rev>~`, a state, which
-- the first commit lacks, so its files fall back to the index.
---@param rev string|nil
---@param pathspec string|string[]|nil
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

--- Review the files changed and not staged yet / already staged. Neither touches
--- the diff reference.
---@param pathspec string|string[]|nil
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
