--- 10. Check parser installation and the tree that queries require.
---
--- "Highlight works" also applies to legacy syntax files, so it does not prove tree-sitter works.
--- Check the node and captures at a known position instead.
--- These require an installed parser, a loaded query, and a language registration for the
--- filetype.
---
--- Parameters:
---   lang: Specify the language to check. The default is the buffer filetype.
---   find: Search for this text to position the cursor at a known location.
---   row, col: Use this explicit position instead of `find` (1-based row, 0-based col).
---
---   node: Specify the expected node type at this position ('string_content').
---   capture: Specify the expected capture without the at sign.
---   injected: Specify the expected injected language at this position.
---
--- Give the file to open to the driver (`-File`).
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

  -- Collect all languages whose trees cover the position, not just the first match.
  -- `:h LanguageTree:language_for_range()` uses `pairs()` and returns the first child that
  -- contains the range.
  -- A Rust macro body can have nested `rust` and `sql` injections at the same position.
  -- `pairs()` has no fixed order, so `language_for_range()` can return either language at random.
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
