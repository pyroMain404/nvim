-- ┌────────────┐
-- │ Formatting │
-- └────────────┘
-- This module formats changed lines against the 'mini.diff' reference, as the gutter marks show.
-- 'lua/config/toolchain.lua' selects the formatter.

local M = {}

-- NOTE: Use a real end column on an existing line. `math.huge` is not an integer.
-- 'conform.nvim' silently formats nothing with it or an empty range, so skip missing lines.
local format_range = function(from, to)
  local last = vim.api.nvim_buf_get_lines(0, to - 1, to, false)[1]
  if last == nil then
    vim.notify(
      'Skipped a hunk: the buffer changed while formatting',
      vim.log.levels.WARN
    )
    return nil, false
  end
  local err, did_edit = require('conform').format({
    range = { start = { from, 0 }, ['end'] = { to, #last } },
  })
  return err, did_edit
end

-- Require a CLI formatter or LSP fallback. Warn once (`:h conform.list_formatters_to_run()`).
local has_formatter = function(conform)
  local formatters, lsp = conform.list_formatters_to_run(0)
  if #formatters > 0 or lsp then return true end
  local ft = vim.bo.filetype == '' and '<no filetype>' or vim.bo.filetype
  vim.notify(
    'No formatter for ' .. ft .. ', and no language server to format',
    vim.log.levels.WARN
  )
  return false
end

local conform_or_notify = function()
  local ok, conform = pcall(require, 'conform')
  if ok then return conform end
  vim.notify("'conform.nvim' is not loaded yet", vim.log.levels.ERROR)
  return nil
end

M.buffer = function()
  local conform = conform_or_notify()
  if not conform then return end
  conform.format()
end

--- Format changed lines from bottom to top because formatting shifts line numbers below.
M.changed = function()
  local conform = conform_or_notify()
  if not conform then return end
  if not has_formatter(conform) then return end

  -- Without reference text, nothing is "unchanged", so format the whole buffer.
  -- Outside a repository, 'mini.diff' does not attach. Untracked files have data but no reference
  -- text or hunks.
  -- NOTE: Reference text arrives asynchronously, about 130 ms after opening the file, as measured.
  -- Wait to avoid formatting a whole tracked file.
  local data = MiniDiff.get_buf_data(0)
  if data ~= nil and data.ref_text == nil then
    local has_ref = function() return (MiniDiff.get_buf_data(0) or {}).ref_text end
    vim.wait(500, function() return has_ref() ~= nil end, 10)
    data = MiniDiff.get_buf_data(0)
  end
  if data == nil or data.ref_text == nil then
    vim.notify(
      'No diff reference here: formatted the whole buffer',
      vim.log.levels.WARN
    )
    return M.buffer()
  end

  local ranges = {}
  for _, hunk in ipairs(data.hunks) do
    -- A "delete" hunk has no buffer lines to format.
    if hunk.buf_count > 0 then
      table.insert(ranges, { hunk.buf_start, hunk.buf_start + hunk.buf_count - 1 })
    end
  end
  if #ranges == 0 then return vim.notify('No changed lines to format') end

  table.sort(ranges, function(a, b) return a[1] > b[1] end)
  local formatted, failed = 0, 0
  for _, range in ipairs(ranges) do
    local err, did_edit = format_range(range[1], range[2])
    if err ~= nil then
      failed = failed + 1
    elseif did_edit then
      formatted = formatted + 1
    end
  end
  local msg = ('Formatted %d of %d changed hunk(s)'):format(formatted, #ranges)
  if failed > 0 then
    vim.notify(msg .. (', %d failed'):format(failed), vim.log.levels.ERROR)
  else
    vim.notify(msg)
  end
end

--- Format a Visual selection.
-- HACK: `conform.format()` uses `#line - 1` with an end-exclusive `#line` for the selection end
-- column.
-- Through a `<Cmd>` mapping, it edits nothing, and the `'<`/`'>` marks are stale.
-- Read the live selection with `getpos('v')` and `getpos('.')`.
-- Format its line span with `format_range()`
-- (conform.nvim 016802d, locked 2026-11-01, not retested).
M.selection = function()
  local conform = conform_or_notify()
  if not conform then return end
  if not has_formatter(conform) then return end
  local from, to = vim.fn.getpos('v')[2], vim.fn.getpos('.')[2]
  if from > to then
    from, to = to, from
  end
  format_range(from, to)
end

return M
