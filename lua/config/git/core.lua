-- ┌──────────────────────┐
-- │ Git command plumbing │
-- └──────────────────────┘
--
-- Shared by the other modules of 'lua/config/git' and by 'lua/config/review.lua'.

local M = {}

M.patterns = {
  show_path = '^minigit://%d+/.*show %x+~*:(.*)$',
  show_commit = '^minigit://%d+/.*show (%x+~*):',
  edit_path = '^minigit://%d+/edit (.*)$',
}

--- Run asynchronously; `on_done` is scheduled (windows cannot be opened from the process watcher).
M.run = function(args, opts, on_done)
  local sys_opts = vim.tbl_extend('force', { text = true }, opts or {})
  vim.system(args, sys_opts, vim.schedule_wrap(on_done))
end

M.fail = function(out, cmd_desc)
  local msg = vim.trim(out.stderr)
  if msg == '' then msg = 'exited with code ' .. out.code end
  return cmd_desc .. ': ' .. msg
end

--- Pick a commit from the log of `path` (`nil`: the repository) for `apply`.
M.pick_commit = function(path, apply)
  local choose = function(item) apply(item:match('^%S+')) end
  MiniExtra.pickers.git_commits({ path = path }, { source = { choose = choose } })
end

M.repo_root = function() return vim.fs.root(vim.fn.getcwd(), '.git') end

--- Repository root, or a WARN; a `buf_id` prefers the root 'mini.git' resolved.
M.require_root = function(buf_id)
  local root = (buf_id ~= nil and (MiniGit.get_buf_data(buf_id) or {}).root)
    or M.repo_root()
  if root == nil then
    vim.notify('Not inside a Git repository', vim.log.levels.WARN)
  end
  return root
end

--- Path of the file a buffer holds, or a WARN and `nil`.
M.buf_path = function(buf_id)
  local path = vim.api.nvim_buf_get_name(buf_id)
  if vim.fn.filereadable(path) == 1 then return path end
  vim.notify('Buffer is not a file on disk', vim.log.levels.WARN)
end

-- HACK: paths inside a patch are relative to the repository root, but 'mini.git'
-- resolves them against the cwd (`:h MiniGit.show_diff_source()`), failing with
-- E484 below the root. Run from the root and restore after. Remove once
-- 'mini.git' resolves them itself (still needed in 'mini.nvim' f9ac12d, 2026-11-09).
M.at_repo_root = function(f, opts)
  local root = M.repo_root()
  if root == nil then return f(opts) end
  local cwd = vim.fn.getcwd()
  vim.fn.chdir(root)
  local ok, err = pcall(f, opts)
  vim.fn.chdir(cwd)
  if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
end

--- Whether `git diff <diff_args>` has changes (`--quiet`: exit 0 clean, 1 dirty).
---@param on_result fun(state: 'clean'|'dirty'|string) other strings are the error
M.has_changes = function(diff_args, root, on_result)
  local cmd = vim.list_extend({ 'git', 'diff', '--quiet' }, diff_args)
  M.run(cmd, { cwd = root }, function(out)
    if out.code == 0 then return on_result('clean') end
    if out.code == 1 then return on_result('dirty') end
    on_result(M.fail(out, '`' .. table.concat(cmd, ' ') .. '` failed'))
  end)
end

return M
