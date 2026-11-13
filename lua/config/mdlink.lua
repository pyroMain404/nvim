-- ┌───────────────────────────┐
-- │ Markdown link for 'path'  │
-- └───────────────────────────┘
-- 'after/ftplugin/markdown.lua' loads this module by name for 'includeexpr'.
-- It resolves Markdown links for 'path' (`:h 'includeexpr'`).

-- 'path' commands (`gf`, `gF`, `<C-w>f`, `[f`, `:find`) first use the name under the cursor.
-- If no file matches, they ask 'includeexpr' for another name.
-- In `[label](target)`, that name is wrong in both cases.
-- On the label it is a word of the label. On the target it can carry a `#anchor`.
--
-- This module returns the target of the link that contains the cursor, without its anchor.
-- The cursor column is a byte column of the source text.
-- Concealed (rendered) `<Leader>om` states therefore do not change the result.

local M = {}

-- Return the link target under the cursor for 'path', or `fname` if no link contains the cursor.
-- Remove `#anchor` in both cases. Handle `<...>` and a trailing title.
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

-- Check whether source byte `col` (0-based) starts a footnote `[^name]`.
local starts_footnote = function(line, col) return line:sub(col + 1, col + 2) == '[^' end

-- 'render-markdown.nvim' anchors inline footnote text at the start of its hidden source.
-- The cursor on that source appears after the mark and seems to skip it.
-- Anchor the text at the hidden range end so the cursor on its first byte appears at the mark
-- start.
-- Use this for the plugin's `on.render` and `on.clear` hooks (`:h render-markdown-setup`).

-- The plugin's extmark keeps only the conceal.
-- This code rebuilds the text from the source on every render, as the plugin does.
-- It follows `render/common/footnote.lua`: icon, prefix, name, suffix, `link.highlight`.
-- It does not reproduce `superscript`, which 'plugin/40_plugins.lua' disables.
-- It stores no data by extmark id because ids restart after each namespace clear.
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
        -- The renderer rebuilds marks on every render.
        -- Undo restores marks by id, but ids restart after each clear.
        -- A restored mark could therefore move another mark.
        undo_restore = false,
      })
    end
  end
end

M.clear_footnotes = function(buf)
  vim.api.nvim_buf_clear_namespace(buf, footnote_ns, 0, -1)
end

-- Keep reading-state motions off source that renderer extmarks or Markdown highlight captures
-- conceal, including multiline ranges.
-- Merge their runs after clipping them to the current row.
-- Move after a run when moving right, or before it when moving left or at line end.
-- A fully hidden line has one cursor anchor at column zero. `prev` gives the previous 1-based byte
-- column.
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
        -- Inline virtual text replaces a footnote reference. Keep its first byte reachable as a
        -- cursor position.
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
      -- The renderer covers the heading `#` with an icon but conceals nothing.
      -- Add the marker and its following space here.
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

  -- Remove each hole from the runs, regardless of which source concealed it.
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
