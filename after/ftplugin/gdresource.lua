-- ┌──────────────────────────┐
-- │ Godot resource behaviour │
-- └──────────────────────────┘
--
-- `:GodotTree` shows `.tscn`/`.tres` `[node ...]` sections as a tree in a scratch buffer (`:h scratch-buffer`).
-- `<CR>` jumps to the node. Neovim detects the `gdresource` filetype (`:h filetype`).
-- 'lua/config/toolchain.lua' lists the `godot_resource` parser, and 'plugin/40_plugins.lua' installs it.

-- NOTE: The identifier of a `section`/`attribute` is `named_child(0)`, not `child(0)`,
-- because the first child is an anonymous `[`/`=` token.
local query = vim.treesitter.query.parse(
  'godot_resource',
  [[
  (section (identifier) @section_name) @section
  (attribute (identifier) @attr_key (string) @attr_value) @attr
]]
)

-- Depth equals the number of `parent=` segments plus one.
-- The root has no `parent=` and has depth 0. `parent="."` has depth 1.
local function depth_of(parent_path)
  if parent_path == nil then return 0 end
  if parent_path == '.' then return 1 end
  return #vim.split(parent_path, '/', { plain = true }) + 1
end

-- The result contains `{ { name, type, depth, lnum }, ... }` in file order.
local function scene_nodes(bufnr)
  local parser = vim.treesitter.get_parser(bufnr, 'godot_resource')
  local root = parser:parse()[1]:root()

  local function text(node) return vim.treesitter.get_node_text(node, bufnr) end
  local function unquote(node) return text(node):sub(2, -2) end

  local sections, attrs = {}, {}
  for id, node in query:iter_captures(root, bufnr, 0, -1) do
    local capture = query.captures[id]
    if capture == 'section' then
      table.insert(sections, node)
    elseif capture == 'attr' then
      table.insert(attrs, node)
    end
  end

  local nodes = {}
  for _, sec in ipairs(sections) do
    if text(sec:named_child(0)) == 'node' then
      local row = sec:range()
      local entry = { name = nil, type = nil, parent = nil, lnum = row + 1 }
      for _, attr in ipairs(attrs) do
        if attr:parent() == sec then
          local key = text(attr:named_child(0))
          if key == 'name' then
            entry.name = unquote(attr:named_child(1))
          elseif key == 'type' then
            entry.type = unquote(attr:named_child(1))
          elseif key == 'parent' then
            entry.parent = unquote(attr:named_child(1))
          end
        end
      end
      entry.depth = depth_of(entry.parent)
      table.insert(nodes, entry)
    end
  end
  return nodes
end

-- The result includes tree lines and a corresponding `lnum` table, so `<CR>` does not need to parse
-- again.
local function render(nodes)
  local lines, lnums = {}, {}
  for _, node in ipairs(nodes) do
    local text = ('  '):rep(node.depth) .. node.name
    if node.type ~= nil then text = text .. (' (%s)'):format(node.type) end
    table.insert(lines, text)
    table.insert(lnums, node.lnum)
  end
  return lines, lnums
end

vim.api.nvim_buf_create_user_command(0, 'GodotTree', function()
  local source_win, source_buf =
    vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  local nodes = scene_nodes(source_buf)
  if #nodes == 0 then
    return vim.notify(
      'No [node ...] sections found in this file',
      vim.log.levels.WARN
    )
  end
  local lines, lnums = render(nodes)

  local tree_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[tree_buf].buftype = 'nofile'
  vim.bo[tree_buf].bufhidden = 'wipe'
  vim.bo[tree_buf].filetype = 'godottree'
  vim.api.nvim_buf_set_name(tree_buf, 'Godot scene tree')
  vim.api.nvim_buf_set_lines(tree_buf, 0, -1, false, lines)
  vim.bo[tree_buf].modifiable = false

  vim.cmd('vertical new')
  vim.api.nvim_win_set_buf(0, tree_buf)

  vim.keymap.set('n', '<CR>', function()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local target = lnums[line]
    if target == nil or not vim.api.nvim_win_is_valid(source_win) then return end
    vim.api.nvim_set_current_win(source_win)
    vim.api.nvim_win_set_cursor(source_win, { target, 0 })
  end, { buffer = tree_buf, desc = 'Jump to this node in the scene file' })
end, { desc = 'Open the node tree of the current .tscn/.tres as a scratch buffer' })

require('config.ft').undo('delcommand GodotTree')
