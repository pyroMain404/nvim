--- 16. Send one LSP request at a position from a pattern.
---
--- The `lsp` probe checks "which server, with which configuration". This probe checks "and what
--- does it reply".
--- A healthy attached server can return no useful answer because a library setting is missing or
--- the cursor is on a comment.
---
--- Three shared requirements apply to every request.
--- The server must finish loading; requests during indexing can return "Workspace loading"
--- instead of a useful answer.
--- The position must identify a real symbol. `find` avoids line numbers that change.
--- The reply must become text because `expect` cannot match a nested table.
---
--- Parameters:
---   method: Specify the LSP method. The default is 'textDocument/definition'.
---           The probe also supplies parameters for hover, references, implementation,
---           typeDefinition, codeLens, and codeAction.
---   find: Search with this pattern to put the cursor on the required symbol.
---   line: Use this explicit 1-based line when no pattern fits.
---   col: Specify a 1-based column or an offset within the match.
---   server: Specify the client name. The default is the first attached client.
---   count: Specify the expected result count.
---   expect: Specify the pattern that at least one rendered result must match.
---   absent: Specify the pattern that no rendered result can match.
---   resolve: Resolve each item before rendering. Unresolved code lenses have no `command`.
---   ready: Wait for the server to finish loading first. The default is true.
---   before: Run this snippet first.
---   timeout: Specify the wait limit per request. The default is 15000 ms.
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

--- Render one reply item as a text line for its method family.
local function render(item)
  if type(item) ~= 'table' then return tostring(item) end

  -- Handle Location / LocationLink results from definition, references, and implementation.
  local uri = item.uri or item.targetUri
  if uri then
    local range = item.targetSelectionRange or item.targetRange or item.range
    return ('%s:%d:%d'):format(
      vim.fs.basename(vim.uri_to_fname(uri)),
      range.start.line + 1,
      range.start.character + 1
    )
  end

  -- Handle CodeLens results.
  if item.range and (item.command or item.data) then
    local command = item.command or {}
    return ('line %d: %s [command=%s]'):format(
      item.range.start.line + 1,
      command.title or '<unresolved>',
      command.command == nil and 'nil' or ('"' .. command.command .. '"')
    )
  end

  -- Handle CodeAction / Command results.
  if item.title then
    return ('%s (%s)'):format(item.title, item.kind or 'command')
  end

  return vim.inspect(item):gsub('%s+', ' ')
end

--- These requests resolve items for use.
--- A server can send code lenses without `command` and supply it only on demand.
--- An unresolved code lens thus has no title (`:h codeLens/resolve`).
local resolvers = {
  ['textDocument/codeLens'] = 'codeLens/resolve',
  ['textDocument/codeAction'] = 'codeAction/resolve',
  ['textDocument/inlayHint'] = 'inlayHint/resolve',
  ['textDocument/documentLink'] = 'documentLink/resolve',
}

--- Supply method parameters. Only these four parameter forms occur in practice.
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
  -- `references` requires a position and context.
  -- Without context, `lua_ls` returns an internal error with 'provider.lua' in its traceback.
  -- This can look like a server defect.
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

  -- Wait before counting clients because attachment is asynchronous.
  -- An immediate count can report "no client" just before attachment.
  -- This wait supplies the entire delay in a reused session.
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

  -- Check positioning separately. An unmatched pattern leaves the cursor unchanged.
  -- The resulting empty reply can look like a server defect instead of a probe defect.
  local find = P.param('find')
  if find then
    vim.fn.cursor(1, 1)
    -- A malformed pattern raises `E54` or `E55`; this identifies a parameter error, not a
    -- configuration error.
    -- `search()` uses a Vim regexp: `(` is literal and `\(` starts a group.
    -- Other probe patterns use Lua syntax, which reverses these meanings.
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
  -- Hover returns one object. Other methods return a list.
  if result.contents ~= nil then
    local contents = result.contents
    local text = type(contents) == 'table'
        and (contents.value or vim.inspect(contents))
      or tostring(contents)
    -- Keep the parentheses because `gsub` returns the count as a second value.
    -- Without them, the table has two entries and the report incorrectly counts two results.
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
