--- 9. `:checkhealth`, in a form a script can fail on.
---
--- Read by eye, a health check is a wall of green in which one ERROR hides
--- perfectly. Parsed, it becomes the cheapest regression test this
--- configuration has: it already knows what should be installed and what should
--- be reachable, so a change that breaks the environment fails here first.
---
--- Parameters:
---   sections  what to check, default 'config' (this repository's own check)
---   fail_on   'ERROR' (default) or 'WARNING' to be stricter
---   allow     patterns of lines to ignore, for what is known and accepted
---   show      also print the whole report, default false
---   wait      health checks are slow: 4000+ ms is a reasonable start
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  local sections = table.concat(P.list('sections', { 'config' }), ' ')
  local ok, err = pcall(vim.cmd, 'checkhealth ' .. sections)
  P.check('`:checkhealth ' .. sections .. '` ran', ok, not ok and err or nil)
  if not ok then return end

  vim.wait(2000, function() return vim.api.nvim_buf_line_count(0) > 1 end)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  P.check('the report is not empty', #lines > 1, #lines)

  local strict = P.param('fail_on', 'ERROR') == 'WARNING'
  local allow = P.list('allow')
  local bad = {}
  for _, line in ipairs(lines) do
    local flagged = line:find('ERROR') or (strict and line:find('WARNING'))
    for _, pattern in ipairs(allow) do
      if flagged and line:find(pattern) then flagged = nil end
    end
    if flagged then table.insert(bad, vim.trim(line)) end
  end

  P.check(
    'no ' .. (strict and 'ERROR or WARNING' or 'ERROR') .. ' in ' .. sections,
    #bad == 0,
    #bad > 0 and table.concat(bad, '\n') or nil
  )
  if P.param('show', false) then P.info(table.concat(lines, '\n')) end
end)
