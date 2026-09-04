--- 17. What the server actually reports about this buffer.
---
--- "No diagnostics" is the most deceiving state in this whole directory: it is
--- what a clean file looks like, what a server that never published looks like,
--- and what a buffer outside any workspace looks like. The way to tell them
--- apart is to break something on purpose (`insert`) and demand that the
--- breakage is reported, which is what this probe is for.
---
--- Timing is the other half. A server publishes more than once - an empty list
--- while it parses, the real one after - so a probe that returns on the first
--- `DiagnosticChanged` reads a half-filled state. `P.wait_diagnostics()` waits
--- for the quiet after the last publish instead of a fixed number of seconds.
---
--- Parameters:
---   before    snippet run first
---   insert    lines appended to the buffer before waiting, as a list. Keep the
---             buffer syntactically valid: many tools (`stylua`, some servers)
---             report nothing at all about a file they cannot parse
---   at        0-based line to insert at, default the end of the buffer
---   count     number of diagnostics expected
---   expect    pattern at least one message must match
---   absent    pattern no message may match - this is how a declared global
---             (`Config`) is told apart from a typo
---   severity  only look at this severity: ERROR, WARN, INFO, HINT
---   ready     wait for the server to finish loading first, default true
---   quiet     milliseconds of silence that end the wait, default 700
---   timeout   how long to wait for diagnostics at all, default 30000 ms
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
  -- A client with no root is in single file mode, and some servers publish
  -- nothing at all in it. Saying so here turns an empty report into a cause.
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
