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

-- Keep reading-state motions off hidden source text: renderer extmarks and
-- Markdown highlight captures both conceal it, including multiline ranges.
-- Merge their row-clipped runs before landing after a run when moving right,
-- or before it when moving left / at end of line. A fully hidden line has one
-- cursor anchor at column zero. `prev` is the previous 1-based byte column.
M.skip_hidden = function(prev)
  local level = vim.wo.conceallevel
  if level < 2 then return end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  local line = vim.api.nvim_get_current_line()
  local len = #line
  local runs = {}
  local function add_range(sr, sc, er, ec)
    if sr > row or er < row then return end
    local s = sr == row and sc or 0
    local e = er == row and ec or len
    s, e = math.max(0, s), math.min(len, e)
    if s < e then runs[#runs + 1] = { s, e } end
  end
  local function is_hidden(conceal)
    return conceal == '' or (level == 3 and conceal ~= nil)
  end

  local renderer = package.loaded['render-markdown.core.ui']
  if renderer then
    local marks = vim.api.nvim_buf_get_extmarks(
      0,
      renderer.ns,
      { row, 0 },
      { row, -1 },
      { details = true, overlap = true }
    )
    for _, mark in ipairs(marks) do
      local details = mark[4]
      local er = details.end_row or mark[2]
      local ec = details.end_col or len
      if details.conceal_lines ~= nil then
        if mark[2] == row or er > row or (er == row and ec > 0) then
          runs[#runs + 1] = { 0, len }
        end
      elseif is_hidden(details.conceal) then
        add_range(mark[2], mark[3], er, ec == -1 and len or ec)
      end
    end
  end

  local ok, parser = pcall(vim.treesitter.get_parser, 0, 'markdown')
  if ok then
    parser:parse(true)
    parser:for_each_tree(function(tree, ltree)
      local lang = ltree:lang()
      if lang ~= 'markdown' and lang ~= 'markdown_inline' then return end
      local query = vim.treesitter.query.get(lang, 'highlights')
      if not query then return end
      for id, node, md in query:iter_captures(tree:root(), 0, row, row + 1) do
        local capture = md[id] or {}
        if is_hidden(md.conceal or capture.conceal) then
          local range = vim.treesitter.get_range(node, 0, capture)
          add_range(range[1], range[2], range[4], range[5])
        end
      end
    end)
  end
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
  while to > 0 and line:byte(to + 1) >= 128 and line:byte(to + 1) < 192 do
    to = to - 1
  end
  vim.api.nvim_win_set_cursor(0, { row + 1, to })
end

return M
