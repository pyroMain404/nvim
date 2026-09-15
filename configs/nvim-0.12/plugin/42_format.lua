-- ┌──────────────┐
-- │ Formatting   │
-- └──────────────┘
--
-- This file decides *what* gets formatted; 'plugin/40_plugins.lua' decides
-- *with which program*, in the `formatters_by_ft` of 'conform.nvim'. The two
-- are separate on purpose: adding a formatter for a language is a one line
-- change there, and never needs a line here.
--
-- The rule it implements: a format pass touches the lines that were changed,
-- not the whole file. Reformatting an untouched file is how a one line fix
-- becomes a diff nobody can review - and in a repository whose style drifted
-- over the years, or whose formatter was configured after the fact, it is also
-- how unrelated churn ends up in a commit. This is language agnostic: it is
-- the same rule for every filetype that has a formatter.
--
-- What counts as "changed" is what 'mini.diff' already knows: the hunks of the
-- buffer against its reference text, which is the Git index by default and
-- whatever revision `Config.git.set_diff_ref()` last referenced otherwise
-- (`:h MiniDiff-hunk-specification`). That is the same answer the signs in the
-- gutter give, so what gets formatted is exactly what is marked as changed -
-- and referencing another revision widens the pass along with the signs.
--
-- Reachable through `Config.format`, and nothing else of it is global:
--
-- - `Config.format.changed()` - format the changed lines of the buffer.
-- - `Config.format.buffer()` - format all of it, when that is what is wanted.
--
-- Mappings carry no logic: 'plugin/20_keymaps.lua' binds `<Leader>lf` to the
-- first and `<Leader>lF` to the second, plus `<Leader>lf` over a Visual
-- selection, which 'conform.nvim' already reads as the range to format.

Config.format = {}

-- Formatting one range at a time is what 'conform.nvim' supports (`:h
-- conform.format()`), so several hunks mean several calls. A formatter that
-- cannot format a range is not a problem: 'conform.nvim' then formats a copy of
-- the whole buffer and applies only the diffs falling inside the range, which
-- is the same result by another road.
-- The end column has to be a real column of a real line: `math.huge` is not an
-- integer, and 'conform.nvim' silently formats nothing when given one. A
-- range whose line is gone by the time this runs (the buffer changed between
-- reading `data.hunks` and this call) is skipped rather than formatted as an
-- empty range, which `range = { start = { N, 0 }, ['end'] = { N, 0 } }` would
-- silently do.
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

--- Format the lines that differ from the diff reference.
---
--- Order matters: hunks are formatted from the bottom of the buffer upwards,
--- because formatting one changes the line numbers of everything below it and
--- would leave the ranges computed before it pointing at the wrong lines.
Config.format.changed = function()
  local ok, conform = pcall(require, 'conform')
  if not ok then
    return vim.notify("'conform.nvim' is not loaded yet", vim.log.levels.ERROR)
  end
  -- `list_formatters()` only names AVAILABLE conform formatters (a declared
  -- one whose binary is missing does not count), and never counts the LSP
  -- fallback 'plugin/40_plugins.lua' configures (`lsp_format = 'fallback'`).
  -- Refusing on the first alone left a Java buffer (no CLI formatter
  -- declared, jdtls formats) and a Lua buffer without `stylua` warned and
  -- untouched by `<Leader>lf`, while `<Leader>lF` formatted them through the
  -- server - two entry points of one API disagreeing. Warn only when BOTH
  -- are absent.
  if #conform.list_formatters(0) == 0 then
    local has_lsp_formatter = #vim.lsp.get_clients({
      bufnr = 0,
      method = 'textDocument/formatting',
    }) > 0
    if not has_lsp_formatter then
      local ft = vim.bo.filetype == '' and '<no filetype>' or vim.bo.filetype
      local msg = 'No formatter for ' .. ft .. ', and no language server to format'
      return vim.notify(msg, vim.log.levels.WARN)
    end
  end

  -- Without a reference text nothing here is "unchanged", so the whole buffer
  -- is the honest answer, and the message says which one was taken. Two
  -- different states end up in it: outside a repository 'mini.diff' does not
  -- attach at all, while inside one it attaches to a file Git does not track
  -- too - and that buffer has a data table with no reference text and no hunk,
  -- which reads as "nothing changed" for a file where everything is new.
  -- NOTE: the reference text arrives asynchronously, around 130 ms after the
  -- file is opened (measured). Until it does, a tracked file looks exactly like
  -- an untracked one, and waiting for it is what keeps the first from being
  -- reformatted whole.
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
    return Config.format.buffer()
  end

  local ranges = {}
  for _, hunk in ipairs(data.hunks) do
    -- A "delete" hunk has no buffer lines of its own (`buf_count == 0`): what
    -- changed there is text that is gone, and there is nothing to format.
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

--- Format the whole buffer, for the rare time that is the intent: a file being
--- adopted into the config, or one whose reference is not worth trusting.
Config.format.buffer = function()
  local ok, conform = pcall(require, 'conform')
  if not ok then
    return vim.notify("'conform.nvim' is not loaded yet", vim.log.levels.ERROR)
  end
  conform.format()
end

-- Format a Visual selection, under the same "both absent" guard as
-- `changed()`. `conform.format()` with no explicit range reads the CURRENT
-- Visual selection itself (`:h conform.format()`), which sounds like it should
-- just work through the mapping's `<Cmd>` (`:h <Cmd>` keeps Visual mode active
-- while its body runs) - and `vim.fn.mode()` here does read 'V', confirming
-- that. It still formats nothing: 'conform.nvim's own detection computes the
-- selection's last column as `#line - 1` on top of an already end-exclusive
-- `#line`, one column short of the real line end - measured directly, a range
-- ending at that computed column edits nothing while the same range one column
-- wider edits correctly. The line's own marks ('</'>) are no workaround
-- either: they are only written when Visual mode is *left*, and `<Cmd>` never
-- leaves it, so they still hold whatever a previous selection set them to (or
-- nothing, the first time).
-- The fix reads the live selection instead, the same way 'conform.nvim' itself
-- does (`getpos('v')` for the anchor, `getpos('.')` for the cursor), and hands
-- the line span to `format_range()` - already used by `changed()`, and already
-- correct about the end column (`#last`, not `#last - 1`).
Config.format.selection = function()
  local ok, conform = pcall(require, 'conform')
  if not ok then
    return vim.notify("'conform.nvim' is not loaded yet", vim.log.levels.ERROR)
  end
  if #conform.list_formatters(0) == 0 then
    local has_lsp_formatter = #vim.lsp.get_clients({
      bufnr = 0,
      method = 'textDocument/formatting',
    }) > 0
    if not has_lsp_formatter then
      local ft = vim.bo.filetype == '' and '<no filetype>' or vim.bo.filetype
      local msg = 'No formatter for ' .. ft .. ', and no language server to format'
      return vim.notify(msg, vim.log.levels.WARN)
    end
  end
  local from, to = vim.fn.getpos('v')[2], vim.fn.getpos('.')[2]
  if from > to then
    from, to = to, from
  end
  format_range(from, to)
end
