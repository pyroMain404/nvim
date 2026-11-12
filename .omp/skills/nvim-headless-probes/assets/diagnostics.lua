--- 17. Check the diagnostics that the server reports for this buffer.
---
--- "No diagnostics" can mean a clean file, a server that published nothing, or a buffer outside
--- all workspaces.
--- Use `insert` to add a defect. Require a diagnostic for that defect to distinguish these
--- states.
---
--- A server can publish an empty list during parsing and a complete list later.
--- The first `DiagnosticChanged` can thus give incomplete results.
--- `P.wait_diagnostics()` waits for silence after the last publication, not a fixed delay.
---
--- Parameters:
---   before: Run this snippet first.
---   insert: Append this list of lines before waiting. Keep the buffer syntactically valid.
---           Many tools (`stylua`, some servers) report nothing for files they cannot parse.
---   at: Specify the 0-based insertion line. The default is the buffer end.
---   count: Specify the expected diagnostic count.
---   expect: Specify the pattern that at least one message must match.
---   absent: Specify the pattern that no message can match.
---           This distinguishes a declared global (`Config`) from a typing error.
---   severity: Check only this severity: ERROR, WARN, INFO, HINT.
---   ready: Wait for the server to finish loading first. The default is true.
---   quiet: Specify the silence period that ends the wait. The default is 700 ms.
---   timeout: Specify the diagnostic wait limit. The default is 30000 ms.
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

local names = { 'ERROR', 'WARN', 'INFO', 'HINT' }

P.run(function()
  P.eval('before')

  local ready, ms, note = P.wait_lsp({
    timeout = P.param('timeout', 30000),
    quiet = P.param('quiet_lsp', 1000),
  })
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  P.info(
    ('clients: %d%s'):format(
      #clients,
      clients[1]
          and (' | ' .. clients[1].name .. ' root: ' .. tostring(clients[1].root_dir))
        or ''
    )
  )
  -- A client without a root uses single file mode. Some servers publish nothing in this mode.
  -- Report the missing root to explain an empty diagnostic report.
  if clients[1] and clients[1].root_dir == nil then
    P.info('this client has no root_dir: single file mode')
  end

  if P.param('ready', true) then
    P.check('the server finished loading', ready, ('%dms - %s'):format(ms, note))
  end

  local insert = P.list('insert')
  if #insert > 0 then
    local at = P.param('at', vim.api.nvim_buf_line_count(0))
    vim.api.nvim_buf_set_lines(0, at, at, false, insert)
    P.info(('inserted %d line(s) at %d'):format(#insert, at))
  end

  local all, ms = P.wait_diagnostics({
    timeout = P.param('timeout', 30000),
    quiet = P.param('quiet', 700),
  })
  P.info(('settled after %dms'):format(ms))

  local severity = P.param('severity')
  local items = {}
  for _, d in ipairs(all) do
    local name = names[d.severity] or '?'
    if severity == nil or name == severity then
      table.insert(
        items,
        ('line %d [%s] %s (%s)'):format(
          d.lnum + 1,
          name,
          tostring(d.message):gsub('\r?\n', ' '),
          tostring(d.source)
        )
      )
    end
  end

  P.info(
    ('%d diagnostic(s)%s'):format(#items, severity and (' of ' .. severity) or '')
  )
  for i, line in ipairs(items) do
    P.info(('  %d. %s'):format(i, line))
  end

  local count = P.param('count')
  if count ~= nil then
    P.check(('%d diagnostic(s)'):format(count), #items == count, #items)
  end
  P.match('message', items)
end)
