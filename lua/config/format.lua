-- ┌────────────┐
-- │ Formatting │
-- └────────────┘
--
-- Decides what gets formatted: the lines changed against the 'mini.diff'
-- reference text (the Git index, or the revision `set_diff_ref()` referenced),
-- the same hunks the gutter signs mark. Which program formats is declared in
-- 'plugin/40_plugins.lua'. Required by name from 'plugin/20_keymaps.lua'.

local M = {}

-- Formatting one range at a time is what 'conform.nvim' supports
-- (`:h conform.format()`), so several hunks mean several calls.
-- NOTE: the end column has to be a real column of a real line: `math.huge` is not
-- an integer and 'conform.nvim' silently formats nothing. A line gone by now is
-- skipped, as an empty range would silently do the same.
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

-- Whether a format pass has anything to run: a CLI formatter or the LSP fallback
-- (`:h conform.list_formatters_to_run()`). Warns once, so callers only `return`.
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

-- An unloaded plugin degrades the feature, it does not abort the caller.
local conform_or_notify = function()
  local ok, conform = pcall(require, 'conform')
  if ok then return conform end
  vim.notify("'conform.nvim' is not loaded yet", vim.log.levels.ERROR)
  return nil
end

--- Format the whole buffer, for a file being adopted or one whose reference is
--- not worth trusting.
M.buffer = function()
  local conform = conform_or_notify()
  if not conform then return end
  conform.format()
end

--- Format the lines that differ from the diff reference, bottom-up: formatting a
--- hunk changes the line numbers of everything below it.
M.changed = function()
  local conform = conform_or_notify()
  if not conform then return end
  if not has_formatter(conform) then return end

  -- Without a reference text nothing is "unchanged", so the whole buffer is the
  -- honest answer: outside a repository 'mini.diff' does not attach, and a file
  -- Git does not track has data with no reference text and no hunk.
  -- NOTE: the reference text arrives asynchronously, around 130 ms after the file
  -- opens (measured); waiting keeps a tracked file from being reformatted whole.
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
    -- A "delete" hunk has no buffer lines: there is nothing to format.
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
-- HACK: `conform.format()` reads the selection itself but computes its last
-- column as `#line - 1` on top of an end-exclusive `#line`, so it edits nothing
-- through a `<Cmd>` mapping, where the `'<`/`'>` marks are stale too. Read the
-- live selection (`getpos('v')`, `getpos('.')`) and format the line span with
-- `format_range()` (conform.nvim 016802d, locked 2026-11-01, not retested).
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
