--- 15. What the configuration costs at startup, file by file.
---
--- The reason this configuration splits loading into steps is that the first
--- screen has to be drawn before anything optional runs. A change that moves
--- work from `later()` to the immediate part does not break anything - it just
--- makes every session slower, which nobody notices in a single test. This is
--- the check that notices.
---
--- It runs a second Neovim with `--startuptime`, because the timing of the
--- session a probe runs in is already spoiled by the probe itself.
---
--- Parameters:
---   file     file to open in the measured session, default none
---   budget   total milliseconds allowed; the check fails above it
---   top      how many slowest entries to print, default 12
---   filter   pattern of entries to keep in the report ('plugin/')
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
  -- A log line is either `clock  self+sourced  self: sourced script` or
  -- `clock  elapsed: some event`. Only the first kind is worth ranking - the
  -- second is cumulative, so sorting it would put the end of startup on top -
  -- while both carry the clock, which is what the total comes from.
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
