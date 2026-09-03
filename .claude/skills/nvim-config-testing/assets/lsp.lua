--- 7. Which language server answered, and with which configuration.
---
--- `:checkhealth vim.lsp` says it in a real session; this probe says it in
--- a form a script can fail on. Two clients of the same server on one project
--- and a `root_dir` replaced by a config file are the recurring failures here,
--- and both look fine until someone counts.
---
--- Parameters:
---   before    snippet run first, when the buffer needs to be reopened
---   server    name of the expected server ('rust_analyzer')
---   clients   number of clients expected attached, default 1
---   methods   LSP methods the client must support, as
---             'textDocument/formatting'
---   settings  dotted path inside the client settings to report
---   expect    pattern the value at `settings` must match
---   wait      grace period for the deferred configuration, in ms
---   timeout   how long to wait for a client to attach, default 10000 ms
---
--- The file to open is given to the driver (`-File`), because a server only
--- attaches to a buffer of a filetype it was enabled for.
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  P.eval('before')
  local server = P.param('server')

  -- Attaching is asynchronous: the server has to start and answer `initialize`
  -- before the client exists. Polling for it is what tells "not attached" apart
  -- from "not attached yet", which no fixed wait can do.
  vim.wait(
    P.param('timeout', 10000),
    function() return #vim.lsp.get_clients({ bufnr = 0 }) > 0 end
  )
  local attached = vim.lsp.get_clients({ bufnr = 0 })

  -- When nothing attached, the answer is almost always one of these two: the
  -- server was never enabled, or its executable is not on the PATH Neovim
  -- inherited. Reporting both turns "no client" into a cause.
  if server ~= nil then
    local config = vim.lsp.config[server]
    P.info(
      ('config for %s: %s'):format(server, config ~= nil and 'present' or 'missing')
    )
    local cmd = config ~= nil and config.cmd or nil
    if type(cmd) == 'table' then
      local found = vim.fn.exepath(cmd[1])
      P.info(
        ('cmd: %s -> %s'):format(cmd[1], found ~= '' and found or 'NOT on PATH')
      )
    end
  end

  P.info(('filetype: %s'):format(vim.bo.filetype))
  if #attached == 0 then P.fail('no client attached to this buffer') end

  local matching = 0
  for _, client in ipairs(attached) do
    P.info(
      ('client %d: %s | root: %s'):format(client.id, client.name, client.root_dir)
    )
    if server == nil or client.name == server then matching = matching + 1 end
  end

  local expected = P.param('clients', 1)
  P.check(
    ('%d client(s) for %s'):format(expected, server or 'this buffer'),
    matching == expected,
    matching
  )

  local client = attached[1]
  for _, candidate in ipairs(attached) do
    if candidate.name == server then client = candidate end
  end
  if client == nil then return end

  for _, method in ipairs(P.list('methods')) do
    P.check(client.name .. ' supports ' .. method, client:supports_method(method))
  end

  local path = P.param('settings')
  if path == nil then return end
  local value = client.settings
  for _, key in ipairs(vim.split(path, '.', { plain = true })) do
    if type(value) ~= 'table' then break end
    value = value[key]
  end
  P.expect('settings.' .. path, P.param('expect'), vim.inspect(value))
end)
