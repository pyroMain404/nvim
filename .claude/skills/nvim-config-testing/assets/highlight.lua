--- 14. Which highlight actually paints a position, and with which colour.
---
--- The complement of the tree-sitter probe: not "is there a capture", but
--- "which group won, and what does the colour scheme give it". Extmarks,
--- LSP semantic tokens and tree-sitter all paint the same cell, and the visible
--- result is the last one that wins - which is why a capture can be right while
--- the colour is not.
---
--- Parameters:
---   find     text to search for, to inspect a known position
---   row, col explicit position instead of `find` (1 based row, 0 based col)
---   group    pattern one of the groups at that position must match
---   fg, bg   pattern the resolved colours must match ('#ff0000')
---   link     pattern the group must be linked to
---
--- The file to open is given to the driver (`-File`).
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  local find = P.param('find')
  if find ~= nil then
    vim.fn.cursor(1, 1)
    local line = vim.fn.search(find, 'W')
    P.check('`' .. find .. '` found in the buffer', line > 0, line)
    if line == 0 then return end
  else
    vim.api.nvim_win_set_cursor(0, { P.param('row', 1), P.param('col', 0) })
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local info = vim.inspect_pos(0, cursor[1] - 1, cursor[2])

  local groups = {}
  for _, item in ipairs(info.treesitter or {}) do
    table.insert(groups, item.hl_group_link or item.hl_group)
  end
  for _, item in ipairs(info.semantic_tokens or {}) do
    table.insert(groups, item.opts and item.opts.hl_group_link or '?')
  end
  for _, item in ipairs(info.extmarks or {}) do
    table.insert(groups, item.opts and item.opts.hl_group or '?')
  end
  for _, item in ipairs(info.syntax or {}) do
    table.insert(groups, item.hl_group_link or item.hl_group)
  end

  P.expect(
    'groups at ' .. vim.inspect(cursor),
    P.param('group'),
    table.concat(groups, ', ')
  )

  local last = groups[#groups]
  if last == nil then return end
  local resolved = vim.api.nvim_get_hl(0, { name = last, link = false })
  local linked = vim.api.nvim_get_hl(0, { name = last })
  P.expect('link of ' .. last, P.param('link'), linked.link)
  local function colour(value)
    return value ~= nil and ('#%06x'):format(value) or '<none>'
  end
  P.expect('foreground of ' .. last, P.param('fg'), colour(resolved.fg))
  P.expect('background of ' .. last, P.param('bg'), colour(resolved.bg))
end)
