-- ┌──────────────────────┐
-- │ Git command plumbing │
-- └──────────────────────┘
--
-- Shared by the other modules of 'lua/config/git' and by 'lua/config/review.lua'.

local M = {}

-- Names of the buffers 'mini.git' creates: `show <commit>:<path>` holds a file
-- at some commit, `edit <path>` the working tree file of a patch entry.
M.patterns = {
  show_path = '^minigit://%d+/.*show %x+~*:(.*)$',
  show_commit = '^minigit://%d+/.*show (%x+~*):',
  edit_path = '^minigit://%d+/edit (.*)$',
}

--- Run a command asynchronously and hand its output back on the main loop.
-- NOTE: the `vim.schedule_wrap()` is required: windows cannot be opened from
-- the process watcher, and the callbacks of this config open windows.
---@param args string[]
---@param opts table|nil `vim.system()` options; `text = true` is the default
---@param on_done fun(out: table)
M.run = function(args, opts, on_done)
  local sys_opts = vim.tbl_extend('force', { text = true }, opts or {})
  vim.system(args, sys_opts, vim.schedule_wrap(on_done))
end

--- Why a command which had to succeed did not, under the command as it was run.
---@param out table
---@param cmd_desc string
---@return string
M.fail = function(out, cmd_desc)
  local msg = vim.trim(out.stderr)
  if msg == '' then msg = 'exited with code ' .. out.code end
  return cmd_desc .. ': ' .. msg
end

--- Pick a commit from the log of `path` (`nil` for the repository) and hand its
--- hash to `apply`.
---@param path string|nil
---@param apply fun(commit: string)
M.pick_commit = function(path, apply)
  local choose = function(item) apply(item:match('^%S+')) end
  MiniExtra.pickers.git_commits({ path = path }, { source = { choose = choose } })
end

--- Root of the repository the current directory belongs to, `nil` outside one.
M.repo_root = function() return vim.fs.root(vim.fn.getcwd(), '.git') end

--- Repository root, or a WARN. A `buf_id` prefers the root 'mini.git' resolved
--- for that buffer over the one of the current directory.
---@param buf_id integer|nil
---@return string|nil
M.require_root = function(buf_id)
  local root = (buf_id ~= nil and (MiniGit.get_buf_data(buf_id) or {}).root)
    or M.repo_root()
  if root == nil then
    vim.notify('Not inside a Git repository', vim.log.levels.WARN)
  end
  return root
end

--- Path on disk of the file a buffer holds, or a WARN and `nil`.
---@param buf_id integer
---@return string|nil
M.buf_path = function(buf_id)
  local path = vim.api.nvim_buf_get_name(buf_id)
  if vim.fn.filereadable(path) == 1 then return path end
  vim.notify('Buffer is not a file on disk', vim.log.levels.WARN)
end

-- HACK: paths inside a patch are relative to the repository root, while
-- 'mini.git' resolves them against the current directory
-- (`:h MiniGit.show_diff_source()`), so showing a patch entry fails with E484
-- whenever Neovim runs below the root. Run those calls from the root and
-- restore the directory after. Remove once 'mini.git' resolves the paths
-- itself (still needed in 'mini.nvim' ac5dffc, 2026-09-13).
---@param f function
---@param opts table
M.at_repo_root = function(f, opts)
  local root = M.repo_root()
  if root == nil then return f(opts) end
  local cwd = vim.fn.getcwd()
  vim.fn.chdir(root)
  local ok, err = pcall(f, opts)
  vim.fn.chdir(cwd)
  if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
end

--- Whether `git diff <diff_args>` has anything to show, asked with `--quiet`
--- (exit 0 clean, 1 dirty, above that Git failed).
---@param diff_args string[] everything after `git diff --quiet`, pathspec included
---@param root string
---@param on_result fun(state: 'clean'|'dirty'|string) a string other than the two is the error message
M.has_changes = function(diff_args, root, on_result)
  local cmd = vim.list_extend({ 'git', 'diff', '--quiet' }, diff_args)
  M.run(cmd, { cwd = root }, function(out)
    if out.code == 0 then return on_result('clean') end
    if out.code == 1 then return on_result('dirty') end
    on_result(M.fail(out, '`' .. table.concat(cmd, ' ') .. '` failed'))
  end)
end

return M
