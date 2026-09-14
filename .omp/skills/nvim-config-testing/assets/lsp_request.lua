--- 16. One LSP request, on a position named by a pattern.
---
--- The counterpart of the `lsp` probe: that one answers "which server, with
--- which configuration", this one answers "and what does it reply". They fail
--- for different reasons, and the second failure is the one that hides - a
--- server can be attached, healthy, and still answer nothing useful because a
--- library is missing from its settings or the cursor sits on a comment.
---
--- Every request needs the same three things done right, which is why they are
--- here once: the server has to be done loading (a request sent during indexing
--- comes back as "Workspace loading", which reads like a wrong answer), the
--- position has to be a real symbol (`find` puts the cursor on one instead of
--- trusting line numbers that move), and the reply has to be rendered as text
--- (`expect` cannot match a nested table).
---
--- Parameters:
---   method   LSP method, default 'textDocument/definition'. Also handled with
---            the parameters they need: hover, references, implementation,
---            typeDefinition, codeLens, codeAction
---   find     search pattern that puts the cursor on the symbol to ask about
---   line     explicit 1-based line, when no pattern fits
---   col      explicit 1-based column, or the offset inside the match
---   server   name of the client to ask, default the first one attached
---   count    number of results expected
---   expect   pattern at least one rendered result must match
---   absent   pattern no rendered result may match
---   resolve  resolve every item before rendering it (code lens are sent
---            unresolved: their `command` only exists after this)
---   ready    wait for the server to finish loading first, default true
---   before   snippet run first
---   timeout  per request, default 15000 ms
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

--- Render one reply item as a line of text, per method family.
local function render(item)
  if type(item) ~= 'table' then return tostring(item) end

  -- Location / LocationLink, from definition, references, implementation
  local uri = item.uri or item.targetUri
  if uri then
    local range = item.targetSelectionRange or item.targetRange or item.range
    return ('%s:%d:%d'):format(
      vim.fs.basename(vim.uri_to_fname(uri)),
      range.start.line + 1,
      range.start.character + 1
    )
  end

  -- CodeLens
  if item.range and (item.command or item.data) then
    local command = item.command or {}
    return ('line %d: %s [command=%s]'):format(
      item.range.start.line + 1,
      command.title or '<unresolved>',
      command.command == nil and 'nil' or ('"' .. command.command .. '"')
    )
  end

  -- CodeAction / Command
  if item.title then
    return ('%s (%s)'):format(item.title, item.kind or 'command')
  end

  return vim.inspect(item):gsub('%s+', ' ')
end

--- The request that turns an unresolved item into a usable one. A server may
--- send code lens without their `command` and fill it in only on demand, which
--- is why an unresolved lens shows no title (`:h codeLens/resolve`).
local resolvers = {
  ['textDocument/codeLens'] = 'codeLens/resolve',
  ['textDocument/codeAction'] = 'codeAction/resolve',
  ['textDocument/inlayHint'] = 'inlayHint/resolve',
  ['textDocument/documentLink'] = 'documentLink/resolve',
}

--- Parameters each method wants. Only these four shapes exist in practice.
local function params_for(method, client)
  if method:find('codeLens') then
    return { textDocument = vim.lsp.util.make_text_document_params(0) }
  end
  if method:find('codeAction') then
    local position = vim.lsp.util.make_position_params(0, client.offset_encoding)
    local diagnostics = vim.lsp.diagnostic.from(vim.diagnostic.get(0, {
      lnum = vim.api.nvim_win_get_cursor(0)[1] - 1,
    }))
    return {
      textDocument = position.textDocument,
      range = { start = position.position, ['end'] = position.position },
      context = { diagnostics = diagnostics, triggerKind = 1 },
    }
  end
  -- `references` is a position plus a context, and the context is not
  -- optional: without it `lua_ls` answers with an internal error whose
  -- traceback names its own 'provider.lua', which reads like a broken server.
  if method:find('references') then
    local position = vim.lsp.util.make_position_params(0, client.offset_encoding)
    return {
      textDocument = position.textDocument,
      position = position.position,
      context = { includeDeclaration = true },
    }
  end
  return vim.lsp.util.make_position_params(0, client.offset_encoding)
end

P.run(function()
  P.eval('before')

  local method = P.param('method', 'textDocument/definition')
  local name = P.param('server')

  -- Waiting comes before looking: attaching is asynchronous, so a probe that
  -- counts clients the moment it starts reports "no client" for a server that
  -- is merely half a second away. In a reused session this is the whole delay.
  local ready, ms, note = P.wait_lsp({
    timeout = P.param('timeout', 15000) * 4,
    quiet = P.param('quiet', 1000),
  })
  local clients = vim.lsp.get_clients({ bufnr = 0, name = name })
  P.check(
    'a client is attached' .. (name and (': ' .. name) or ''),
    #clients > 0,
    note
  )
  if #clients == 0 then return end
  local client = clients[1]
  P.info(('client: %s | root: %s'):format(client.name, tostring(client.root_dir)))
  if P.param('ready', true) then
    P.check(
      ('%s finished loading'):format(client.name),
      ready,
      ('%dms - %s'):format(ms, note)
    )
  end

  -- Positioning is a check of its own: a pattern that matched nothing leaves
  -- the cursor where it was, and the empty reply that follows looks like the
  -- server's fault instead of the probe's.
  local find = P.param('find')
  if find then
    vim.fn.cursor(1, 1)
    -- A malformed pattern throws (`E54`, `E55`), and the throw belongs to the
    -- parameter, not to the configuration. Remember that `search()` reads a Vim
    -- regexp: there `(` is a literal and `\(` opens a group, the opposite of
    -- the Lua patterns the rest of these probes take.
    local ok, row = pcall(vim.fn.search, find, 'W')
    if not ok then return P.fail('`find` is not a valid Vim pattern', row) end
    P.check(('`%s` found in the buffer'):format(find), row > 0, row)
    if row == 0 then return end
    vim.fn.cursor(row, vim.fn.col('.') + P.param('col', 1) - 1)
  elseif P.param('line') then
    vim.fn.cursor(P.param('line'), P.param('col', 1))
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  P.info(
    ('cursor %d:%d on: %s'):format(
      cursor[1],
      cursor[2] + 1,
      vim.trim(vim.api.nvim_get_current_line()):sub(1, 70)
    )
  )

  local timeout = P.param('timeout', 15000)
  local reply = client:request_sync(method, params_for(method, client), timeout)
  if reply == nil then return P.fail(method .. ': no reply', 'request timed out') end
  if reply.err then
    return P.fail(method .. ' returned an error', vim.inspect(reply.err))
  end

  local result = reply.result
  if result == nil then
    P.info(method .. ': null (the server has nothing here)')
    result = {}
  end
  -- Hover replies with one object, everything else with a list.
  if result.contents ~= nil then
    local contents = result.contents
    local text = type(contents) == 'table'
        and (contents.value or vim.inspect(contents))
      or tostring(contents)
    -- The parentheses matter: `gsub` returns the count as a second value, and
    -- without them the table holds two entries and the report claims two
    -- results where there is one.
    result = { (text:gsub('\r?\n', ' ')) }
  elseif result.uri or result.targetUri then
    result = { result }
  end

  local rendered = {}
  for _, item in ipairs(result) do
    if P.param('resolve', false) and resolvers[method] and type(item) == 'table' then
      local resolved = client:request_sync(resolvers[method], item, timeout)
      item = (resolved or {}).result or item
    end
    table.insert(rendered, render(item))
  end

  P.info(('%s: %d result(s)'):format(method, #rendered))
  for i, line in ipairs(rendered) do
    P.info(('  %d. %s'):format(i, line))
  end

  local count = P.param('count')
  if count ~= nil then
    P.check(('%d result(s)'):format(count), #rendered == count, #rendered)
  end
  P.match('result', rendered)
end)
