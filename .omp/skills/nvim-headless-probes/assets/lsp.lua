--- 7. Check the language server and its configuration.
---
--- `:checkhealth vim.lsp` reports this in an interactive session. This probe makes the results
--- available to script checks.
--- Recurring failures include duplicate clients for one project and a configuration file that
--- replaces `root_dir`.
--- Both can look correct until a check counts clients or inspects the root.
---
--- Parameters:
---   before: Run this snippet first when the buffer needs to open again.
---   server: Specify the expected server name ('rust_analyzer').
---   clients: Specify the expected attached client count. The default is 1.
---   methods: Specify required LSP methods, such as 'textDocument/formatting'.
---   settings: Report this dotted path in the client settings.
---   expect: Specify the pattern that the value at `settings` must match.
---   wait: Specify the deferred configuration grace period, in ms.
---   timeout: Specify the attachment wait limit. The default is 10000 ms.
---   ready: Wait for loading to finish before reading capabilities. The default is false.
---          Servers such as `jdtls` register capabilities dynamically, not in the `initialize`
---   reply.
---          Before project import, `methods` reports false for definition, rename, and
---   formatting.
---          This can look like a configuration failure.
---
--- Give the file to open to the driver (`-File`).
--- A server attaches only to buffers with a filetype for which the configuration enables it.
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  P.eval('before')
  local server = P.param('server')

  -- Attachment is asynchronous: the server must start and answer `initialize` before the client
  -- exists.
  -- Polling distinguishes "not attached" from "not attached yet"; a fixed wait cannot.
  vim.wait(
    P.param('timeout', 10000),
    function() return #vim.lsp.get_clients({ bufnr = 0 }) > 0 end
  )
  local attached = vim.lsp.get_clients({ bufnr = 0 })

  -- The server registers a capability through `client/registerCapability` only after its first
  -- project pass.
  if P.param('ready', false) and #attached > 0 then
    local idle, ms, note = P.wait_lsp({ timeout = P.param('timeout', 10000) })
    P.check('the server finished loading', idle, ('%dms - %s'):format(ms, note))
  end

  -- Absent clients usually mean the server is not enabled or Neovim's inherited PATH lacks its
  -- executable.
  -- Report both conditions to help explain "no client".
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
