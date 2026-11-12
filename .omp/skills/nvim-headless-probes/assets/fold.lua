--- 13. Check that folds agree with 'foldexpr'.
---
--- The configuration calculates a fold level for each line.
--- `foldlevel()` reports that level, which determines whether `zm` folds by hunk, by file, or not
--- at all.
--- Read the levels instead of opening the file and trying keys until a fold closes.
---
--- Parameters:
---   before: Run this snippet to create the buffer to fold ("vim.cmd('Git diff')").
---   find: Search for this text to report levels near a known line.
---   around: Specify how many nearby lines to report. The default is 3.
---   levels: Map line offsets from the match to expected levels, as
---           @{ '0' = 2; '1' = 3 }.
---   closed: Check that the line is inside a closed fold after `zM`.
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  P.eval('before')

  P.info(
    ('foldmethod=%s foldexpr=%s foldlevel=%d'):format(
      vim.wo.foldmethod,
      vim.wo.foldexpr,
      vim.wo.foldlevel
    )
  )

  local line = 1
  local find = P.param('find')
  if find ~= nil then
    vim.fn.cursor(1, 1)
    line = vim.fn.search(find, 'W')
    P.check('`' .. find .. '` found in the buffer', line > 0, line)
    if line == 0 then return end
  end

  local around = P.param('around', 3)
  local last = vim.api.nvim_buf_line_count(0)
  for offset = 0, around do
    local at = math.min(line + offset, last)
    P.info(
      ('  line %d level %s: %s'):format(
        at,
        vim.fn.foldlevel(at),
        vim.fn.getline(at):sub(1, 60)
      )
    )
  end

  for offset, level in pairs(P.param('levels', {})) do
    local at = line + tonumber(offset)
    P.check(
      ('line %d (offset %s) has fold level %s'):format(at, offset, level),
      vim.fn.foldlevel(at) == tonumber(level),
      vim.fn.foldlevel(at)
    )
  end

  if not P.param('closed', false) then return end
  vim.cmd('normal! zM')
  P.check(
    'the line is inside a closed fold after `zM`',
    vim.fn.foldclosed(line) ~= -1
  )
end)
