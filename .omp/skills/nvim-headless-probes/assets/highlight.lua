--- 14. Check the highlight group and colour at a position.
---
--- The tree-sitter probe checks "is there a capture".
--- This probe checks "which group won, and what does the colour scheme give it".
--- Extmarks, LSP semantic tokens, and tree-sitter can colour the same cell.
--- The last applicable highlight determines the visible result, so a correct capture can still
--- show the wrong colour.
---
--- Parameters:
---   find: Search for this text to inspect a known position.
---   row, col: Use this explicit position instead of `find` (1-based row, 0-based col).
---   group: Specify the pattern that one group at this position must match.
---          Reports show `<group> -> <link>` when names differ.
---          Thus, checks can use the capture or its resolved group.
---   fg, bg: Specify the patterns that resolved colours must match ('#ff0000').
---   link: Specify the pattern that the group's link must match.
---
--- Give the file to open to the driver (`-File`).
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  local cursor = P.locate()
  if cursor == nil then return end
  local info = vim.inspect_pos(0, cursor[1] - 1, cursor[2])

  -- Keep both names, `@keyword.lua -> Statement`, to identify the colour source.
  -- A capture and a legacy syntax group can share a link.
  -- The link alone cannot distinguish tree-sitter from 'syntax/lua.vim'.
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
