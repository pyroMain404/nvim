-- ┌───────────────┐
-- │ Blame of line │
-- └───────────────┘
--
-- Who last changed the line under the cursor, written at its end. Off until
-- `toggle()`, so that no `git` runs on every pause of the cursor.
-- NOTE: `git blame` reads the file from disk, so nothing is shown while the
-- buffer is modified: line numbers would credit lines to the wrong commit.

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
  -- The buffer can have been wiped while the timer waited, and
  -- `MiniGit.get_buf_data()` raises on an invalid id.
  if not vim.api.nvim_buf_is_valid(buf_id) then return end
  local root = (MiniGit.get_buf_data(buf_id) or {}).root
  if root == nil or vim.bo[buf_id].modified then return end

  local range = lnum .. ',' .. lnum
  local path = vim.api.nvim_buf_get_name(buf_id)
  local cmd = { 'git', 'blame', '--porcelain', '-L', range, '--', path }
  core.run(cmd, { cwd = root }, function(out)
    -- An answer for a line the cursor has left is of no interest anymore
    local is_current = last.buf_id == buf_id and last.lnum == lnum
    if out.code ~= 0 or not is_current then return end

    -- A line not committed yet is reported with a hash of only zeros
    local text = 'Not committed yet'
    if out.stdout:find('^0+ ') == nil then
      local author = out.stdout:match('\nauthor ([^\n]*)') or '?'
      local summary = out.stdout:match('\nsummary ([^\n]*)') or '?'
      local time = tonumber(out.stdout:match('\nauthor%-time (%d+)'))
      local date = time ~= nil and os.date('%Y-%m-%d', time) or '?'
      text = author .. ' │ ' .. date .. ' │ ' .. summary
    end
    -- NOTE: "combine" keeps the foreground of 'Comment' over the cursorline
    -- background; the leading space keeps the text apart from the line it follows.
    local opts = {
      virt_text = { { ' ' .. text, 'Comment' } },
      virt_text_pos = 'eol',
      hl_mode = 'combine',
    }
    pcall(vim.api.nvim_buf_set_extmark, buf_id, ns, lnum - 1, 0, opts)
  end)
end

--- Blame a line only once the cursor rests on it: holding `j` would otherwise
--- start a `git` process for every line passed through.
M.track = function()
  if not enabled then return end
  local buf_id, lnum = vim.api.nvim_get_current_buf(), vim.fn.line('.')
  local tick = vim.b[buf_id].changedtick
  local is_same = last.buf_id == buf_id and last.lnum == lnum
  if is_same and last.tick == tick then return end
  -- Left as it is, the annotation of the previous buffer stays readable in
  -- whatever split still shows it.
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

--- Align the output of `:vertical Git blame` with the window it was called from
--- and make both scroll together (`:h MiniGit-examples`).
M.align = function(au_data)
  if au_data.data.git_subcommand ~= 'blame' then return end
  local win_src = au_data.data.win_source
  vim.wo[0][0].wrap = false
  vim.fn.winrestview({ topline = vim.fn.line('w0', win_src) })
  vim.api.nvim_win_set_cursor(0, { vim.fn.line('.', win_src), 0 })
  -- Written per window (second index, window id), as plain `vim.wo` would bind
  -- every window opened afterwards (`:h vim.wo`).
  vim.wo[win_src].scrollbind = true
  vim.wo[0][0].scrollbind = true
end

return M
