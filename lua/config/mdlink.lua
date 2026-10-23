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

-- Whether the source text at byte `col` (0-based) opens a footnote `[^name]`.
local starts_footnote = function(line, col) return line:sub(col + 1, col + 2) == '[^' end

-- 'render-markdown.nvim' draws a footnote reference as inline virtual text
-- anchored where the hidden source starts, so a cursor resting on that source
-- is drawn after the mark and seems to jump over it. Anchor the text at the end
-- of the hidden range instead: the cursor on its first byte is then drawn at
-- the start of the mark. For the `on.render` and `on.clear` hooks of the plugin
-- (`:h render-markdown-setup`). The plugin's extmark keeps only the conceal;
-- the text is rebuilt from the source on every render, as the plugin does
-- (`render/common/footnote.lua`: icon, prefix, name, suffix, `link.highlight`;
-- `superscript` is off in 'plugin/40_plugins.lua' and not reproduced here), so
-- nothing is keyed by extmark id: ids restart after each clear of the namespace.
local footnote_ns = vim.api.nvim_create_namespace('config-footnote')

M.anchor_footnotes = function(buf)
  local ns = require('render-markdown.core.ui').ns
  local link = require('render-markdown.state').get(buf).link
  local footnote = link.footnote
  vim.api.nvim_buf_clear_namespace(buf, footnote_ns, 0, -1)
  for _, mark in
    ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true }))
  do
    local id, row, col, d = mark[1], mark[2], mark[3], mark[4]
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    if
      d.conceal == ''
      and d.end_row == row
      and d.end_col
      and starts_footnote(line, col)
    then
      if d.virt_text then
        vim.api.nvim_buf_set_extmark(buf, ns, row, col, {
          id = id,
          end_row = row,
          end_col = d.end_col,
          conceal = '',
          priority = d.priority,
        })
      end
      local name = line:sub(col + 3, d.end_col - 1)
      vim.api.nvim_buf_set_extmark(buf, footnote_ns, row, d.end_col, {
        virt_text = {
          {
            footnote.icon .. footnote.prefix .. name .. footnote.suffix,
            link.highlight,
          },
        },
        virt_text_pos = 'inline',
        right_gravity = false,
        -- Rebuilt on every render. Undo restores a mark by id, and ids restart
        -- after each clear, so a restored one would move another mark.
        undo_restore = false,
      })
    end
  end
end

M.clear_footnotes = function(buf)
  vim.api.nvim_buf_clear_namespace(buf, footnote_ns, 0, -1)
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
  local runs, holes = {}, {}
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
        -- A footnote reference is replaced by inline virtual text, so its first
        -- byte stays reachable: the cursor has somewhere to land on it.
        if mark[2] == row and starts_footnote(line, mark[3]) then
          holes[#holes + 1] = mark[3]
        end
      end
    end
  end

  local ok, parser = pcall(vim.treesitter.get_parser, 0, 'markdown')
  if ok then
    parser:parse(true)
    parser:for_each_tree(function(tree, ltree)
      local lang = ltree:lang()
      if lang ~= 'markdown' and lang ~= 'markdown_inline' then return end
      -- The renderer draws an icon over the `#` of a heading but conceals
      -- nothing, so the marker and the space after it are added here.
      if lang == 'markdown' then
        local node = tree:root():descendant_for_range(row, 0, row, 0)
        while node and node:type() ~= 'atx_heading' do
          node = node:parent()
        end
        local marker = node and node:child(0)
        if marker then
          local _, sc, _, ec = marker:range()
          local _, last = line:find('^[ \t]*', ec + 1)
          add_range(row, sc, row, last)
        end
      end
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

  -- Take each hole out of the runs, whichever source hid it.
  for _, hole in ipairs(holes) do
    local split = {}
    for _, run in ipairs(runs) do
      if run[1] <= hole and hole < run[2] then
        if run[1] < hole then split[#split + 1] = { run[1], hole } end
        if hole + 1 < run[2] then split[#split + 1] = { hole + 1, run[2] } end
      else
        split[#split + 1] = run
      end
    end
    runs = split
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
