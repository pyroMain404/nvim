-- ┌───────────────────────┐
-- │ LSP client behaviour  │
-- └───────────────────────┘
--
-- `setup()` in 'plugin/50_features.lua' enables client fixes that are not limited to one server.

local M = {}

-- HACK: On Windows, `fs_realpath()` returns backslashed paths, but `vim.lsp.util.rename()` splits
-- them on `/`.
-- The buffer keeps its old name, so writes use the old path.
-- The code renames with `:saveas!` without autocommands, because the write would run the
-- 'obsidian.nvim' front matter hook during the rename.
-- The defect still exists (Neovim 0.12.5, locked 2026-11-11, not retested).
local patch_rename = function()
  local lsp_rename = vim.lsp.util.rename
  vim.lsp.util.rename = function(old_fname, new_fname, opts)
    lsp_rename(old_fname, new_fname, opts)
    if vim.uv.fs_stat(old_fname) or not vim.uv.fs_stat(new_fname) then return end
    local old_norm = vim.fs.normalize(old_fname)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(buf)
      if
        vim.api.nvim_buf_is_loaded(buf)
        and vim.bo[buf].buftype == ''
        and vim.fs.normalize(name) == old_norm
      then
        vim.api.nvim_buf_call(
          buf,
          function()
            vim.cmd('noautocmd keepalt saveas! ' .. vim.fn.fnameescape(new_fname))
          end
        )
        vim.cmd('bdelete! ' .. vim.fn.bufnr(name))
      end
    end
  end
end

-- HACK: 'nvim-lspconfig' announces `rust-analyzer.showReferences` but registers only `runSingle`.
-- Reference lenses then report "does not support command".
-- The code shows the locations on the client.
-- The command is still missing (nvim-lspconfig 993d048, locked 2026-11-09, not retested).
local add_show_references = function()
  vim.lsp.commands['rust-analyzer.showReferences'] = function(command, ctx)
    local locations = command.arguments and command.arguments[3] or {}
    local encoding = vim.lsp.get_client_by_id(ctx.client_id).offset_encoding
    if #locations == 0 then
      vim.notify(command.title, vim.log.levels.INFO)
    elseif #locations == 1 then
      vim.lsp.util.show_document(locations[1], encoding, { reuse_win = true })
    else
      local items = vim.lsp.util.locations_to_items(locations, encoding)
      vim.fn.setqflist({}, ' ', { title = command.title, items = items })
      vim.cmd('copen')
    end
  end
end

-- A hover window uses a read-only markdown buffer without a server, so `K` cannot request another
-- hover.
-- Resolve the cursor word against the source document, or use `workspace/symbol`.
-- Replace the window with the new hover. Focus it so `K` can continue (`:h vim.lsp.buf.hover()`).
local word_pattern = '[%w_\128-\255]+'
local pending -- The `FileType` callback reads this ctx for the new child window.

-- Return the cursor word and its qualifier before `.` (`os` in `os.DirEntry`).
local cursor_word = function()
  local line, col =
    vim.api.nvim_get_current_line(), vim.api.nvim_win_get_cursor(0)[2] + 1
  for start, word, stop in line:gmatch('()(' .. word_pattern .. ')()') do
    if col >= start and col < stop then
      return word, line:sub(1, start - 1):match('(' .. word_pattern .. ')%.$')
    end
  end
end

-- Return text for a class without a project file, such as a JDK or jar class.
-- jdtls names it with a `jdt://` URI. Return nil if the server cannot answer.
-- `BufReadCmd` in 'plugin/40_plugins.lua' also reads this text.
M.class_file_lines = function(client, uri)
  local response =
    client:request_sync('java/classFileContents', { uri = uri }, 10000)
  if not response or response.err or type(response.result) ~= 'string' then
    return
  end
  return vim.split((response.result:gsub('\r\n', '\n')), '\n', { plain = true })
end

local document_lines = function(client, uri)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.uri_from_bufnr(buf) == uri then
      return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    end
  end
  if uri:find('^jdt://') then return M.class_file_lines(client, uri) or {} end
  local fname = vim.uri_to_fname(uri)
  return vim.fn.filereadable(fname) == 1 and vim.fn.readfile(fname) or {}
end

-- Return the document's Tree-sitter root, or none without a parser for its filetype (Markdown,
-- plain text).
-- Without a parser, text matches can be prose, so `find_word()` finds nothing and
-- `workspace/symbol` decides.
local code_root = function(uri, lines)
  local fname = vim.uri_to_fname(uri)
  -- A `jdt://` URI carries its query after the name of the file.
  if not uri:find('^file:') then fname = fname:gsub('[?#].*', '') end
  local filetype = vim.filetype.match({ filename = fname, contents = lines })
  local lang = filetype and vim.treesitter.language.get_lang(filetype)
  if not lang or #lines == 0 then return end
  local ok, parser =
    pcall(vim.treesitter.get_string_parser, table.concat(lines, '\n'), lang)
  return ok and parser:parse()[1]:root() or nil
end

local in_comment_or_string = function(root, row, col)
  local node = root:named_descendant_for_range(row, col, row, col)
  local node_type = node and node:type() or ''
  return node_type:find('comment') ~= nil or node_type:find('string') ~= nil
end

-- Return the first 0-based `{ row, byte col }` of `word` in code, using `qual.word` if `qual`
-- exists.
-- Exclude comments and strings, such as a Javadoc `{@link FileMode}`.
local find_word = function(lines, root, word, qual)
  if not root then return end
  local pattern = '%f[%w_]'
    .. (qual and vim.pesc(qual) .. '%.' or '')
    .. '()'
    .. vim.pesc(word)
    .. '%f[^%w_]'
  for i, text in ipairs(lines) do
    local init = 1
    while true do
      local start, _, col = text:find(pattern, init)
      if not start then break end
      if not in_comment_or_string(root, i - 1, col - 1) then
        return i - 1, col - 1
      end
      init = start + 1
    end
  end
end

-- `open_floating_preview()` sizes a window from the free rows around the current cursor.
-- A one-line hover window leaves none, so the code opens the new hover from the source window,
-- where the old hover was.
-- The new hover takes the place of the old hover.
-- `index` identifies the `ctx.chain` entry for `<C-o>` or `<C-i>`.
-- Without `index`, the hover is a new entry after the current one.
local show_hover = function(ctx, uri, position, buf, index)
  ctx.client:request(
    'textDocument/hover',
    { textDocument = { uri = uri }, position = position },
    function(_, result)
      local old = vim.api.nvim_get_current_win()
      if
        vim.api.nvim_win_get_buf(old) ~= buf
        or not vim.api.nvim_win_is_valid(ctx.win)
      then
        return
      end
      local lines = result
          and result.contents
          and vim.lsp.util.convert_input_to_markdown_lines(result.contents)
        or {}
      if vim.tbl_isempty(lines) then
        return vim.notify('No information available', vim.log.levels.INFO)
      end
      local chain = ctx.chain
      if index then
        chain.index = index
      else
        for i = #chain.history, chain.index + 1, -1 do
          table.remove(chain.history, i)
        end
        table.insert(chain.history, { uri = uri, position = position })
        chain.index = #chain.history
      end
      -- The source buffer holds the chain and the new window registration.
      -- `open_floating_preview()` closes the window registered on the source buffer.
      -- Clear the registration so the old window stays open until the new one exists.
      vim.b[ctx.bufnr].lsp_floating_preview = nil
      pending = {
        client = ctx.client,
        uri = uri,
        position = position,
        bufnr = ctx.bufnr,
        win = ctx.win,
        chain = chain,
      }
      local new
      vim.api.nvim_win_call(ctx.win, function()
        _, new = vim.lsp.util.open_floating_preview(lines, 'markdown')
      end)
      pending = nil
      vim.api.nvim_set_current_win(new)
      vim.api.nvim_win_close(old, true)
    end,
    ctx.bufnr
  )
end

-- `ctx` contains `{ client, uri, position, bufnr, win }`.
-- These identify the server, hover document, position, and source buffer and window that started
-- the chain.
local hover_word = function(ctx, buf)
  local word, qual = cursor_word()
  if not word then return end

  local hover_in = function(uri, lines, row, col)
    local character =
      vim.str_utfindex(lines[row + 1], ctx.client.offset_encoding, col)
    show_hover(ctx, uri, { line = row, character = character }, buf)
  end
  local scan = function(uri)
    local lines = document_lines(ctx.client, uri)
    return lines, code_root(uri, lines)
  end
  -- Show hover for the first code match in the scanned document, or return false without a match.
  -- Use `qual.word` unless `bare` permits another path (`out.println` for `PrintStream.println`).
  local hover_found = function(uri, lines, root, bare)
    local row, col = find_word(lines, root, word, not bare and qual or nil)
    if not row then return false end
    hover_in(uri, lines, row, col)
    return true
  end

  local lines, root = scan(ctx.uri)
  if hover_found(ctx.uri, lines, root) then return end

  -- The document has no match, and the server does not recognize the name.
  -- Follow the hover subject's definition to its declaring document to search there (the
  -- `PrintStream` class of `println`).
  local from_definition = function()
    ctx.client:request(
      'textDocument/definition',
      { textDocument = { uri = ctx.uri }, position = ctx.position },
      function(_, result)
        local location = result and (vim.islist(result) and result[1] or result)
        local uri = location and (location.uri or location.targetUri)
        if uri and uri ~= ctx.uri then
          local def_lines, def_root = scan(uri)
          if
            hover_found(uri, def_lines, def_root)
            or hover_found(uri, def_lines, def_root, true)
          then
            return
          end
        end
        vim.notify('No symbol `' .. word .. '` found', vim.log.levels.INFO)
      end,
      ctx.bufnr
    )
  end

  ctx.client:request('workspace/symbol', { query = word }, function(_, result)
    local suffix = qual and (qual .. '.' .. word)
    local found = vim.tbl_filter(
      function(symbol)
        return symbol.location
          and symbol.location.range
          and symbol.name:match('(' .. word_pattern .. ')$') == word
          and (
            not qual
            or (symbol.containerName or ''):match('(' .. word_pattern .. ')$') == qual
            or symbol.name:sub(-#suffix) == suffix
          )
      end,
      result or {}
    )
    if #found == 0 then
      if hover_found(ctx.uri, lines, root, true) then return end
      return from_definition()
    end
    local open = function(symbol)
      if not symbol then return end
      local uri, start = symbol.location.uri, symbol.location.range.start
      -- jdtls locates JDK or jar classes at the file start, which has no hover target.
      -- Find the declaration in the text.
      if start.line == 0 and start.character == 0 then
        local symbol_lines, symbol_root = scan(uri)
        local row, col = find_word(symbol_lines, symbol_root, word)
        if row then return hover_in(uri, symbol_lines, row, col) end
      end
      show_hover(ctx, uri, start, buf)
    end
    if #found == 1 then return open(found[1]) end
    vim.ui.select(found, {
      prompt = 'Hover',
      format_item = function(symbol)
        return (symbol.containerName or '') .. ' ' .. symbol.name
      end,
    }, open)
  end, ctx.bufnr)
end

-- `<C-o>` and `<C-i>` navigate the hover chain.
-- Each window replaces the previous window, so its jump list cannot return to earlier hovers.
local hover_jump = function(ctx, buf, step)
  local chain = ctx.chain
  local index = math.max(1, math.min(#chain.history, chain.index + step))
  if index == chain.index then return end
  local entry = chain.history[index]
  show_hover(ctx, entry.uri, entry.position, buf, index)
end

-- `gf` on a Markdown link would open the file in the floating window.
-- Close that window. Open the file in the chain's source window (`:h
-- vim.lsp.util.show_document()`).
-- `gF` also follows `#<line>` or `#<line>,<col>` fragments, which 'isfname' cannot parse; gopls
-- writes the latter.
local follow_link = function(ctx, with_line)
  local line, col =
    vim.api.nvim_get_current_line(), vim.api.nvim_win_get_cursor(0)[2] + 1
  local target
  for start, url, stop in line:gmatch('()%b[]%(([^%s)]+)%)()') do
    if col >= start and col < stop then
      target = url
      break
    end
  end
  if not target then
    return vim.notify('No link under the cursor', vim.log.levels.INFO)
  end
  if target:find('^https?://') then return vim.ui.open(target) end

  local uri, lnum, cnum = target:match('^(.*)#L?(%d+),?(%d*)$')
  uri = uri or target
  if not (uri:find('^jdt://') or uri:find('^file:')) then
    return vim.notify('Unsupported link: ' .. target, vim.log.levels.WARN)
  end
  if not vim.api.nvim_win_is_valid(ctx.win) then return end

  local float = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(ctx.win)
  vim.api.nvim_win_close(float, true)
  vim.cmd("normal! m'")
  local at = with_line
      and lnum
      and {
        line = tonumber(lnum) - 1,
        character = math.max((tonumber(cnum) or 1) - 1, 0),
      }
    or nil
  vim.lsp.util.show_document(
    { uri = uri, range = at and { start = at, ['end'] = at } or nil },
    ctx.client.offset_encoding,
    { focus = true }
  )
end

local add_hover_chain = function()
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('config-lsp-hover-chain', { clear = true }),
    pattern = 'markdown',
    callback = function(args)
      local win = vim.fn.win_findbuf(args.buf)[1]
      local source = win and vim.w[win].lsp_floating_bufnr
      if not source then return end
      local ctx = pending
      if not ctx then
        local client =
          vim.lsp.get_clients({ bufnr = source, method = 'textDocument/hover' })[1]
        -- `FileType` runs in the hover window, so find the source window.
        local source_win = vim.tbl_filter(
          function(w) return vim.api.nvim_win_get_config(w).relative == '' end,
          vim.fn.win_findbuf(source)
        )[1]
        if not client or not source_win then return end
        local cursor = vim.api.nvim_win_get_cursor(source_win)
        local line = vim.api.nvim_buf_get_lines(
          source,
          cursor[1] - 1,
          cursor[1],
          false
        )[1] or ''
        ctx = {
          client = client,
          uri = vim.uri_from_bufnr(source),
          position = {
            line = cursor[1] - 1,
            character = vim.str_utfindex(line, client.offset_encoding, cursor[2]),
          },
          bufnr = source,
          win = source_win,
        }
        ctx.chain =
          { history = { { uri = ctx.uri, position = ctx.position } }, index = 1 }
      end
      local map = function(lhs, rhs, desc)
        vim.keymap.set('n', lhs, rhs, { buf = args.buf, desc = desc })
      end
      map('K', function() hover_word(ctx, args.buf) end, 'Hover on the word')
      map(
        '<C-o>',
        function() hover_jump(ctx, args.buf, -vim.v.count1) end,
        'Previous hover'
      )
      map(
        '<C-i>',
        function() hover_jump(ctx, args.buf, vim.v.count1) end,
        'Next hover'
      )
      map(
        'gf',
        function() follow_link(ctx, false) end,
        'Open the link in the source window'
      )
      map('gF', function() follow_link(ctx, true) end, 'Open the link at its line')
    end,
  })
end

-- HACK: jdtls reports progress for every document change ('Validate documents',
-- 'Publish Diagnostics').
-- Typing in a Java buffer then fills the screen with notifications.
-- Use `content.sort` in 'plugin/30_mini.lua' to exclude these from 'mini.notify' (`:h
-- MiniNotify.config`).
-- Import and build notifications still appear (jdtls 1.61.0, locked 2026-11-01, not retested).
local noisy_progress = {
  jdtls = { 'Validate documents', 'Publish Diagnostics' },
}

M.notify_sort = function(notifications)
  local shown = vim.tbl_filter(function(notif)
    local data = notif.data or {}
    if data.source ~= 'lsp_progress' then return true end
    for _, title in ipairs(noisy_progress[data.client_name] or {}) do
      if vim.startswith(notif.msg, data.client_name .. ': ' .. title) then
        return false
      end
    end
    return true
  end, notifications)
  return MiniNotify.default_sort(shown)
end

M.setup = function()
  patch_rename()
  add_show_references()
  add_hover_chain()
  vim.lsp.codelens.enable(true)
end

return M
