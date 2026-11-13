--- 5. Check the final window positions.
---
--- A code description cannot prove a layout. Each window's position and size give direct evidence
--- at low cost.
--- The probe sends the keys one at a time and prints the layout after each key.
--- This shows differences between the first and second files, where window code often fails.
---
--- Parameters:
---   before: Run this snippet to open the initial state ("vim.cmd('Git diff')").
---   keys: Send this list in order and take one snapshot after each key.
---   from: Use 'source' (default) to send every key from the window that `before` selected.
---         Use 'current' to send each key from the window that the previous key selected.
---   count: Specify the expected final window count.
---   ignore: Exclude buffer names that match this pattern, such as floating notifications.
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
