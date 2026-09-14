--- 13. The folds are the ones the 'foldexpr' promises.
---
--- A fold is computed per line, so it is one of the few behaviours that can be
--- read exactly instead of being tried: `foldlevel()` says what level a line
--- got, and that is what decides whether `zm` folds by hunk, by file, or by
--- nothing at all. Reading it beats opening the file and pressing keys until
--- something collapses.
---
--- Parameters:
---   before   snippet that produces the buffer to fold ("vim.cmd('Git diff')")
---   find     text to search for, to report the levels around a known line
---   around   how many lines to report around it, default 3
---   levels   table of line offset (from the match) -> expected level, as
---            @{ '0' = 2; '1' = 3 }
---   closed   check that the line is inside a closed fold after `zM`
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
