--- 11. An autocommand is registered, and firing its event does something.
---
--- Most of what this configuration adds happens inside an autocommand, so
--- "nothing happens" usually means the autocommand is not there at all - the
--- file that registers it threw while loading, or its pattern does not match
--- this buffer. Listing them answers the first, firing the event answers the
--- second.
---
--- Parameters:
---   event     event to look at ('FileType', 'BufWinEnter'), required
---   group     restrict to one augroup, by name
---   pattern   pattern the registered autocommand must match
---   before    snippet run first, to open the buffer they belong to
---   fire      also trigger the event with `:doautocmd`, default false
---   after     snippet run after firing, to report what it changed
---   min       minimum number of matching autocommands, default 1
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  P.eval('before')

  local event = P.need('event')
  local opts = { event = event }
  local group = P.param('group')
  if group ~= nil then opts.group = group end

  local ok, list = pcall(vim.api.nvim_get_autocmds, opts)
  P.check(
    'autocommands for ' .. event .. ' can be listed',
    ok,
    not ok and list or nil
  )
  if not ok then return end

  local pattern = P.param('pattern')
  local matching = {}
  for _, autocmd in ipairs(list) do
    local text = (autocmd.group_name or '?') .. ' ' .. (autocmd.pattern or '')
    if pattern == nil or text:find(pattern) then
      table.insert(matching, text .. ' | ' .. (autocmd.desc or '<no description>'))
    end
  end

  local min = P.param('min', 1)
  P.check(
    ('at least %d autocommand(s) for %s'):format(min, event),
    #matching >= min,
    table.concat(matching, '\n')
  )

  if not P.param('fire', false) then return end
  local fired, err = pcall(vim.cmd, 'doautocmd ' .. event)
  P.check('`:doautocmd ' .. event .. '` ran', fired, not fired and err or nil)
  P.eval('after')
end)
