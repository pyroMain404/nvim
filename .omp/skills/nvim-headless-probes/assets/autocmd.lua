--- 11. Check that an autocommand exists and its event has an effect.
---
--- Most configuration changes use autocommands.
--- Thus, "nothing happens" usually means the autocommand is absent or its pattern excludes this buffer.
--- Registration can fail during file loading.
--- List autocommands to check registration. Trigger the event to check its effect.
---
--- Parameters:
---   event: Specify the required event ('FileType', 'BufWinEnter').
---   group: Limit the search to one named augroup.
---   pattern: Specify the pattern that the registered autocommand must match.
---   before: Run this snippet first to open the relevant buffer.
---   fire: Also trigger the event with `:doautocmd`. The default is false.
---
---   after: Run this snippet after the event to report its effect.
---   min: Specify the minimum matching autocommand count. The default is 1.
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
