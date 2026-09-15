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

  local cursor = P.locate()
  if cursor == nil then return end
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

  -- Every language whose tree covers the position, not the first one found:
  -- `:h LanguageTree:language_for_range()` returns the first child that
  -- contains the range and iterates with `pairs()`, so where injections nest -
  -- the body of a Rust macro is inside a `rust` injection and the `sql` one at
  -- the same time - it answered either of them at random.
  local langs, found = {}, {}
  parser:for_each_tree(function(tree, ltree)
    local srow, scol, erow, ecol = tree:root():range()
    local after_start = row > srow or (row == srow and col >= scol)
    local before_end = row < erow or (row == erow and col <= ecol)
    if after_start and before_end and not langs[ltree:lang()] then
      langs[ltree:lang()] = true
      table.insert(found, ltree:lang())
    end
  end)
  table.sort(found)
  local evidence = table.concat(found, ', ')
  P.check('`' .. injected .. '` injected here', langs[injected] == true, evidence)
end)
