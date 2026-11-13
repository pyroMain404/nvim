--- 9. Run `:checkhealth` in a form that a script can fail on.
---
--- A large green health report can hide one ERROR during visual inspection.
--- Parsing the report gives a low-cost regression check.
--- The health check already knows the required tools and connections, so environment failures
--- appear here first.
---
--- Parameters:
---   sections: Specify the sections to check. The default is 'config', this repository's check.
---   fail_on: Specify 'ERROR' (default) or 'WARNING'. 'WARNING' is stricter.
---   allow: Ignore lines that match these patterns for known, accepted conditions.
---
---   show: Print the complete report too. The default is false.
---   wait: Allow time for slow health checks. Start with 4000+ ms.
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
