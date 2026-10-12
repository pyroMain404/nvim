--- 4. A mapping exists, comes from where it should, and does what it promises.
---
--- Two failures hide behind "the mapping does not work", and only the first is
--- visible without pressing anything: the mapping is not there (or a buffer
--- local one shadows the global), or it is there and its effect is not the one
--- expected. `maparg()` answers the first, sending the keys answers the second.
---
--- Parameters:
---   lhs      keys of the mapping, in `<CR>` notation, required
---   mode     mode to look in, default 'n'
---   before   snippet that opens the buffer the mapping belongs to
---   expect   pattern the right hand side or the description must match
---   press    send the keys after checking, and report what changed
---   after    snippet run once the keys were sent, to report the effect
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
