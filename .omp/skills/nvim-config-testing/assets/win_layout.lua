--- 5. Where the windows ended up.
---
--- A layout is the one thing that cannot be judged from a description of the
--- code: the position and the size of every window are the observable fact, and
--- they are cheap to read. Sending the keys one at a time and printing the
--- layout after each is what shows the second file behaving differently from
--- the first, which is exactly where window code breaks.
---
--- Parameters:
---   before   snippet that opens the starting state ("vim.cmd('Git diff')")
---   keys     keys to send, one snapshot after each; a list, in order
---   from     'source' (default) to send every key from the window `before`
---            ended in, 'current' to send it from wherever the previous key led
---   count    number of windows expected at the end
---   ignore   pattern of buffer names to leave out of the report (floating
---            notifications and the like)
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

local ignore = P.param('ignore', 'mininotify')

local function snapshot(label)
  P.info('--- ' .. label)
  local shown = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
    if ignore == '' or not name:find(ignore) then
      local pos = vim.api.nvim_win_get_position(win)
      shown = shown + 1
      P.info(
        ('  row=%d col=%d w=%d h=%d %s'):format(
          pos[1],
          pos[2],
          vim.api.nvim_win_get_width(win),
          vim.api.nvim_win_get_height(win),
          P.short(name)
        )
      )
    end
  end
  return shown
end

P.run(function()
  P.eval('before')
  local source = vim.api.nvim_get_current_win()
  local shown = snapshot('start')

  local from_source = P.param('from', 'source') == 'source'
  for index, key in ipairs(P.list('keys')) do
    if from_source and vim.api.nvim_win_is_valid(source) then
      vim.api.nvim_set_current_win(source)
    end
    P.eval('between')
    P.keys(key)
    shown = snapshot(('after %d: %s'):format(index, key))
  end

  local count = P.param('count')
  if count ~= nil then
    P.check(('%d windows at the end'):format(count), shown == count, shown)
  end
end)
