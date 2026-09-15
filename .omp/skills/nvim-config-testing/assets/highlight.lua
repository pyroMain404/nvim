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
---   group    pattern one of the groups at that position must match. They are
---            reported as `<group> -> <link>` where the two differ, so the
---            capture and the group it resolves to can both be asked for
---   fg, bg   pattern the resolved colours must match ('#ff0000')
---   link     pattern the group must be linked to
---
--- The file to open is given to the driver (`-File`).
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  local cursor = P.locate()
  if cursor == nil then return end
  local info = vim.inspect_pos(0, cursor[1] - 1, cursor[2])

  -- Both names are kept, `@keyword.lua -> Statement`, because only the first
  -- says where the colour comes from: a capture and a legacy syntax group
  -- resolve to the same link, so reporting the link alone cannot tell
  -- tree-sitter from 'syntax/lua.vim' - which is the whole question here.
  local groups, painter = {}, nil
  local add = function(name, link)
    if name == nil then return end
    painter = link or name
    local same = link == nil or link == name
    table.insert(groups, same and name or (name .. ' -> ' .. link))
  end
  for _, item in ipairs(info.treesitter or {}) do
    add(item.hl_group, item.hl_group_link)
  end
  for _, item in ipairs(info.semantic_tokens or {}) do
    add(item.opts and item.opts.hl_group, item.opts and item.opts.hl_group_link)
  end
  for _, item in ipairs(info.extmarks or {}) do
    add(item.opts and item.opts.hl_group or '?', nil)
  end
  for _, item in ipairs(info.syntax or {}) do
    add(item.hl_group, item.hl_group_link)
  end

  P.expect(
    'groups at ' .. vim.inspect(cursor),
    P.param('group'),
    table.concat(groups, ', ')
  )

  local last = painter
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
