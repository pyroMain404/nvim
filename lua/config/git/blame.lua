-- ┌───────────────┐
-- │ Blame of line │
-- └───────────────┘
-- This module shows the last author at the end of the cursor line.
-- `toggle()` enables it to avoid running `git` on every cursor pause.

-- NOTE: `git blame` reads the disk file. Hide annotations in modified buffers because line numbers
-- could identify the wrong commit.

local core = require('config.git.core')

local M = {}

local ns = vim.api.nvim_create_namespace('custom-config-blame')
local enabled = false
local timer = nil
local last = {}

local clear = function(buf_id)
  if not vim.api.nvim_buf_is_valid(buf_id) then return end
  vim.api.nvim_buf_clear_namespace(buf_id, ns, 0, -1)
end

local show = function(buf_id, lnum)
  -- The timer can outlive the buffer. `MiniGit.get_buf_data()` raises an error for invalid ids.
  if not vim.api.nvim_buf_is_valid(buf_id) then return end
  local root = (MiniGit.get_buf_data(buf_id) or {}).root
  if root == nil or vim.bo[buf_id].modified then return end

  local range = lnum .. ',' .. lnum
  local path = vim.api.nvim_buf_get_name(buf_id)
  local cmd = { 'git', 'blame', '--porcelain', '-L', range, '--', path }
  core.run(cmd, { cwd = root }, function(out)
    -- Ignore results for a line that the cursor has left.
    local is_current = last.buf_id == buf_id and last.lnum == lnum
    if out.code ~= 0 or not is_current then return end

    -- Git reports uncommitted lines with an all-zero hash.
    local text = 'Not committed yet'
    if out.stdout:find('^0+ ') == nil then
      local author = out.stdout:match('\nauthor ([^\n]*)') or '?'
      local summary = out.stdout:match('\nsummary ([^\n]*)') or '?'
      local time = tonumber(out.stdout:match('\nauthor%-time (%d+)'))
      local date = time ~= nil and os.date('%Y-%m-%d', time) or '?'
      text = author .. ' │ ' .. date .. ' │ ' .. summary
    end
    -- NOTE: "combine" keeps the 'Comment' foreground over the cursorline background.
    -- The leading space separates the annotation from the source line.
    local opts = {
      virt_text = { { ' ' .. text, 'Comment' } },
      virt_text_pos = 'eol',
      hl_mode = 'combine',
    }
    pcall(vim.api.nvim_buf_set_extmark, buf_id, ns, lnum - 1, 0, opts)
  end)
end

--- Wait for the cursor to stop before showing blame. Holding `j` would otherwise start `git` for
--- each line.
M.track = function()
  if not enabled then return end
  local buf_id, lnum = vim.api.nvim_get_current_buf(), vim.fn.line('.')
  local tick = vim.b[buf_id].changedtick
  local is_same = last.buf_id == buf_id and last.lnum == lnum
  if is_same and last.tick == tick then return end
  -- Clear the previous buffer annotation so it does not remain visible in another split.
  if last.buf_id ~= nil then clear(last.buf_id) end
  last = { buf_id = buf_id, lnum = lnum, tick = tick }

  clear(buf_id)
  timer:stop()
  timer:start(150, 0, vim.schedule_wrap(function() show(buf_id, lnum) end))
end

M.toggle = function()
  enabled = not enabled
  last = {}
  if enabled then
    timer = vim.uv.new_timer()
    M.track()
  else
    timer:stop()
    timer:close()
    timer = nil
    vim.tbl_map(clear, vim.api.nvim_list_bufs())
  end
  vim.notify('Blame line: ' .. (enabled and 'on' or 'off'))
end

--- Align `:vertical Git blame` output with its source window.
--- Make both windows scroll together (`:h MiniGit-examples`).
M.align = function(au_data)
  if au_data.data.git_subcommand ~= 'blame' then return end
  local win_src = au_data.data.win_source
  vim.wo[0][0].wrap = false
  vim.fn.winrestview({ topline = vim.fn.line('w0', win_src) })
  vim.api.nvim_win_set_cursor(0, { vim.fn.line('.', win_src), 0 })
  -- Use the second index (window id) for window-local writes (`:h vim.wo`).
  -- Plain `vim.wo` would bind every window opened later.
  vim.wo[win_src].scrollbind = true
  vim.wo[0][0].scrollbind = true
end

return M
