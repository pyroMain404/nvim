--- 10. The parser is installed, and the tree is the one the queries expect.
---
--- "Highlight works" is true of a legacy syntax file too, so it proves nothing
--- about tree-sitter. What proves it is the node under a known position and the
--- captures attached to it: those exist only if the parser is installed, the
--- query loaded, and the language registered for the filetype.
---
--- Parameters:
---   lang      language to check, default the filetype of the buffer
---   find      text to search for, to put the cursor on something known
---   row, col  explicit position instead of `find` (1 based row, 0 based col)
---   node      node type expected at that position ('string_content')
---   capture   capture expected at that position, without the at sign
---   injected  language expected to be injected at that position
---
--- The file to open is given to the driver (`-File`).
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  local lang = P.param('lang', vim.bo.filetype)
  P.info(('filetype: %s | language: %s'):format(vim.bo.filetype, lang))

  local ok, parser = pcall(vim.treesitter.get_parser, 0, lang)
  local available = ok and parser ~= nil
  P.check(
    'parser for `' .. lang .. '` available',
    available,
    not ok and parser or nil
  )
  if not available then return end
  parser:parse(true)

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
  local node = vim.treesitter.get_node()
  P.check('a node exists under the cursor', node ~= nil, vim.inspect(cursor))
  if node == nil then return end

  P.expect('node type', P.param('node'), node:type())
  P.info('node text: ' .. vim.inspect(vim.treesitter.get_node_text(node, 0)))

  local captures = {}
  for _, capture in ipairs(vim.treesitter.get_captures_at_cursor(0)) do
    table.insert(captures, capture)
  end
  P.expect('captures', P.param('capture'), table.concat(captures, ', '))

  local injected = P.param('injected')
  if injected == nil then return end
  local row, col = cursor[1] - 1, cursor[2]
  local at = parser:language_for_range({ row, col, row, col })
  P.check('`' .. injected .. '` injected here', at:lang() == injected, at:lang())
end)
