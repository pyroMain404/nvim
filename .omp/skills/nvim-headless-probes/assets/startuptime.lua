--- 15. Measure configuration startup time for each file.
---
--- Loading uses separate steps so the first screen appears before optional work runs.
--- Moving work from `later()` to immediate loading causes no functional failure but slows every
--- session.
--- A single manual test can miss this change. This probe measures it.
---
--- The probe starts a second Neovim with `--startuptime` because the probe itself changes the timing of its own session.
---
--- Parameters:
---   file: Specify the file to open in the measured session. The default is none.
---   budget: Specify the total time limit in milliseconds. The check fails above this limit.
---
---   top: Specify how many of the slowest entries to print. The default is 12.
---   filter: Keep report entries that match this pattern ('plugin/').
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  local log = vim.fn.tempname()
  local argv = { vim.v.progpath, '--headless', '--startuptime', log }
  local file = P.param('file')
  if file ~= nil then table.insert(argv, file) end
  vim.list_extend(argv, { '-c', 'quitall!' })

  local result = vim.system(argv, { text = true }):wait()
  P.check('the measured session ran', result.code == 0, result.stderr)

  local lines = {}
  for line in io.lines(log) do
    table.insert(lines, line)
  end
  P.check('the log has content', #lines > 0, #lines)
  if #lines == 0 then return end

  local total = 0
  local entries = {}
  -- Log lines use `clock  self+sourced  self: sourced script` or `clock  elapsed: some event`.
  -- Rank only script lines. Event times accumulate, so sorting them would put the end of startup
  -- first.
  -- Both forms include the clock value for the total.
  for _, line in ipairs(lines) do
    local clock, sourced, what =
      line:match('^(%d+%.%d+)%s+(%d+%.%d+)%s+%d+%.%d+:%s+(.+)$')
    if clock == nil then clock = line:match('^(%d+%.%d+)%s') end
    if clock ~= nil then total = math.max(total, tonumber(clock)) end
    if what ~= nil then
      table.insert(entries, { spent = tonumber(sourced), what = what })
    end
  end

  table.sort(entries, function(a, b) return a.spent > b.spent end)

  local filter = P.param('filter')
  local shown = 0
  for _, entry in ipairs(entries) do
    if shown >= P.param('top', 12) then break end
    if filter == nil or entry.what:find(filter) then
      shown = shown + 1
      P.info(('  %7.3f ms  %s'):format(entry.spent, entry.what))
    end
  end

  local budget = P.param('budget')
  if budget == nil then
    P.info(('total: %.1f ms'):format(total))
  else
    P.check(
      ('startup under %s ms'):format(budget),
      total <= budget,
      ('%.1f ms'):format(total)
    )
  end
end)
