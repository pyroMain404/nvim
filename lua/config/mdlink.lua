-- ┌───────────────────────────┐
-- │ Markdown link for 'path'  │
-- └───────────────────────────┘
--
-- Required by name from 'after/ftplugin/markdown.lua', as its 'includeexpr'.
--
-- Everything that looks a name up through 'path' (`gf`, `gF`, `<C-w>f`, `[f`,
-- `:find`) takes the name from the text under the cursor and, when no file has
-- it, asks 'includeexpr' for another name (`:h 'includeexpr'`). In a
-- `[label](target)` link that name is wrong twice: on the label it is a word
-- of the label, and on the target it may carry a `#anchor`. The answer here is
-- the target of the link the cursor is in, without its anchor. The cursor
-- column is a byte column of the source text, so it is right in the rendered
-- (concealed) states of `<Leader>om` too.

local M = {}

-- Name for 'path' to look up: the target of the link covering the cursor, else
-- `fname` itself, in both cases without `#anchor`. `<...>` and a trailing title
-- are handled.
M.target = function(fname)
  local line, col = vim.api.nvim_get_current_line(), vim.fn.col('.')
  local init = 1
  while true do
    local s, e, target = line:find('%b[]%(%s*([^)]-)%s*%)', init)
    if not s then break end
    if col >= s and col <= e then
      target = target:match('^<([^>]*)>') or target:match('^(%S+)')
      if target then return (target:gsub('#.*$', '')) end
      break
    end
    init = e + 1
  end
  return (fname:gsub('#.*$', ''))
end

-- Move the cursor off the concealed text of its line, so that the reading
-- state of `<Leader>om`, which keeps the cursor line concealed, never parks it
-- on characters that are not drawn: the backticks and `*` of inline markup and
-- the `[`, `](target)` of links. The ranges are the ones 'markdown_inline'
-- conceals with `(#set! conceal "")` in its 'highlights' query, so they agree
-- with what is drawn. Moving right lands after the concealed run (before it at
-- the end of the line), moving left before it. `prev` is the 1-based column
-- the cursor came from.
M.skip_hidden = function(prev)
  local ok, parser = pcall(vim.treesitter.get_parser, 0, 'markdown')
  local query = vim.treesitter.query.get('markdown_inline', 'highlights')
  if not ok or not query then return end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  local len = #vim.api.nvim_get_current_line()
  parser:parse(true)

  local runs = {}
  parser:for_each_tree(function(tree, ltree)
    if ltree:lang() ~= 'markdown_inline' then return end
    for id, node, md in query:iter_captures(tree:root(), 0, row, row + 1) do
      local conceal = (md[id] or {}).conceal or md.conceal
      local sr, sc, er, ec = node:range()
      if conceal == '' and sr == row and er == row then
        runs[#runs + 1] = { sc, ec }
      end
    end
  end)
  table.sort(runs, function(a, b) return a[1] < b[1] end)

  local s, e
  for _, run in ipairs(runs) do
    if s and run[1] <= e then
      e = math.max(e, run[2])
    else
      if s and col >= s and col < e then break end
      s, e = run[1], run[2]
    end
  end
  if not s or col < s or col >= e then return end

  local to = (col + 1 >= prev and e < len) and e or s - 1
  if to < 0 then to = e < len and e or 0 end
  vim.api.nvim_win_set_cursor(0, { row + 1, to })
end

return M
