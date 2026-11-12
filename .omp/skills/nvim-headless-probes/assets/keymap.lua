--- 4. Check a mapping's presence, source, and effect.
---
--- "the mapping does not work" can mean a missing mapping or a buffer-local mapping that
--- overrides a global mapping.
--- It can also mean that the mapping exists but has the wrong effect.
--- `maparg()` checks the definition. Sending the keys checks the effect.
---
--- Parameters:
---   lhs: Specify the required mapping keys in `<CR>` notation.
---   mode: Specify the mode to inspect. The default is 'n'.
---   before: Run this snippet to open the mapping's buffer.
---   expect: Specify the pattern that the right-hand side or description must match.
---   press: Send the keys after checking and report the changes.
---   after: Run this snippet after the keys to report their effect.
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  P.eval('before')

  local lhs = P.need('lhs')
  local mode = P.param('mode', 'n')
  local map = vim.fn.maparg(lhs, mode, false, true)
  local exists = type(map) == 'table' and next(map) ~= nil
  P.check('`' .. lhs .. '` mapped in mode ' .. mode, exists)
  if not exists then return end

  P.info(
    ('`%s` -> %s'):format(lhs, map.rhs or (map.callback and '<Lua callback>') or '?')
  )
  P.info(
    ('buffer local: %s | description: %s'):format(map.buffer == 1, map.desc or '-')
  )
  P.expect('mapping', P.param('expect'), (map.rhs or '') .. ' ' .. (map.desc or ''))

  if not P.param('press', false) then return end
  local before = {
    win = vim.api.nvim_get_current_win(),
    buf = P.short(vim.api.nvim_buf_get_name(0)),
    cursor = vim.api.nvim_win_get_cursor(0),
  }
  P.keys(lhs)
  local after = {
    win = vim.api.nvim_get_current_win(),
    buf = P.short(vim.api.nvim_buf_get_name(0)),
    cursor = vim.api.nvim_win_get_cursor(0),
  }
  P.dump('before', before)
  P.dump('after', after)
  P.eval('after')
end)
