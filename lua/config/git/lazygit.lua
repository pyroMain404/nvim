-- ┌─────────┐
-- │ Lazygit │
-- └─────────┘
-- 'lazygit' handles staging, branching, and other changes to Git data.
-- The other modules in 'lua/config/git' only read the repository.

local M = {}

--- Show 'lazygit' in a floating window. Reload changed files when it exits.
M.open = function()
  if vim.fn.executable('lazygit') ~= 1 then
    return vim.notify('`lazygit` is not available', vim.log.levels.WARN)
  end

  -- Cover most of the editor but keep some surrounding context visible.
  local height = math.floor(0.9 * vim.o.lines)
  local width = math.floor(0.9 * vim.o.columns)
  local win_config = {
    relative = 'editor',
    height = height,
    width = width,
    row = math.floor(0.5 * (vim.o.lines - height)),
    col = math.floor(0.5 * (vim.o.columns - width)),
    title = ' lazygit ',
    title_pos = 'center',
  }
  local buf_id = vim.api.nvim_create_buf(false, true)
  local win_id = vim.api.nvim_open_win(buf_id, true, win_config)

  local on_exit = vim.schedule_wrap(function()
    pcall(vim.api.nvim_win_close, win_id, true)
    pcall(vim.api.nvim_buf_delete, buf_id, { force = true })
    -- Reload buffers that 'lazygit' changed through checkout, discard, stash, or other operations.
    vim.cmd('checktime')
  end)

  -- This job runs in the current directory, which 'mini.misc' keeps at the project root.
  local job_id = vim.fn.jobstart({ 'lazygit' }, { term = true, on_exit = on_exit })
  if job_id <= 0 then
    pcall(vim.api.nvim_win_close, win_id, true)
    pcall(vim.api.nvim_buf_delete, buf_id, { force = true })
    return vim.notify('Could not start `lazygit`', vim.log.levels.ERROR)
  end
  vim.cmd('startinsert')
end

return M
