-- ┌────────────────────────┐
-- │ Container breadcrumb   │
-- └────────────────────────┘
--
-- Names the tree-sitter containers (function, class, ...) enclosing the cursor
-- in 'winbar' (`:h 'winbar'`), e.g. `Outer > method`. Switched on by `setup()`
-- from 'plugin/50_features.lua'.

local M = {}

-- Node types per filetype. The value is the `:h vim.lsp.protocol.SymbolKind` name
-- closest to the node, which is also what `MiniIcons.get('lsp', ...)` indexes.
local containers_by_ft = {
  lua = { function_declaration = 'Function', function_definition = 'Function' },
  rust = {
    function_item = 'Function',
    impl_item = 'Interface',
    mod_item = 'Module',
    struct_item = 'Struct',
  },
  java = {
    method_declaration = 'Method',
    class_declaration = 'Class',
    interface_declaration = 'Interface',
  },
  gdscript = { function_definition = 'Function', class_definition = 'Class' },
  typescript = {
    function_declaration = 'Function',
    method_definition = 'Method',
    class_declaration = 'Class',
  },
  javascript = {
    function_declaration = 'Function',
    method_definition = 'Method',
    class_declaration = 'Class',
  },
  c = { function_definition = 'Function', struct_specifier = 'Struct' },
  cpp = {
    function_definition = 'Function',
    class_specifier = 'Class',
    struct_specifier = 'Struct',
    namespace_definition = 'Namespace',
  },
}

-- Most grammars name a container through a `name` field; Rust's `impl` uses
-- `type`; C/C++'s `function_definition` has neither: the name is at the bottom of
-- a `declarator` chain. Lua's anonymous `function_definition` takes the name of
-- the `=` left-hand side, one level up through its `expression_list`.
local container_label = function(node, bufnr)
  local target = node:field('name')[1] or node:field('type')[1]
  if target == nil then
    local d = node:field('declarator')[1]
    while d ~= nil and d:field('declarator')[1] ~= nil do
      d = d:field('declarator')[1]
    end
    target = d
  end
  if target == nil and node:type() == 'function_definition' then
    local assign = node:parent() and node:parent():parent()
    if assign ~= nil and assign:type() == 'assignment_statement' then
      local var_list = assign:named_child(0)
      target = var_list ~= nil and var_list:field('name')[1]
    end
  end
  if target == nil then return nil end
  return vim.treesitter.get_node_text(target, bufnr)
end

local compute = function(bufnr, containers)
  -- `get_node()` answers nil for a buffer never parsed, and the first
  -- `CursorMoved` can race the highlighting attach; `parse()` is cached.
  local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
  local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok_parser or parser == nil then return '' end
  parser:parse()
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr })
  if not ok or node == nil then return '' end
  local parts = {}
  while node ~= nil do
    local kind = containers[node:type()]
    if kind ~= nil then
      local label = container_label(node, bufnr)
      if label ~= nil then
        table.insert(parts, 1, MiniIcons.get('lsp', kind) .. ' ' .. label)
      end
    end
    node = node:parent()
  end
  return table.concat(parts, ' > ')
end

-- 'winbar' evaluates `%{...}` on every redraw, far too often to walk the syntax
-- tree in: the cursor line change refreshes this cache and 'winbar' only reads it.
local cache = {} ---@type table<integer, { line: integer, text: string }>
local refresh = function(bufnr)
  local containers = containers_by_ft[vim.bo[bufnr].filetype]
  if containers == nil then return end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local entry = cache[bufnr]
  if entry ~= nil and entry.line == line then return end
  cache[bufnr] = { line = line, text = compute(bufnr, containers) }
end

--- The breadcrumb of the current buffer, as read by 'winbar'.
---@return string
M.render = function()
  local entry = cache[vim.api.nvim_get_current_buf()]
  return entry ~= nil and entry.text or ''
end

M.setup = function()
  Config.new_autocmd(
    { 'CursorMoved', 'CursorMovedI' },
    nil,
    function(args) refresh(args.buf) end,
    'Cache the winbar breadcrumb on cursor line change'
  )

  Config.new_autocmd(
    { 'BufDelete', 'BufWipeout' },
    nil,
    function(args) cache[args.buf] = nil end,
    'Drop the cached winbar breadcrumb'
  )

  -- Only normal file buffers. `vim.wo[0][0]` keeps the write window-local
  -- (`:h vim.wo`); `%{%...%}` is the stateful form needed to call `v:lua`.
  Config.new_autocmd({ 'BufWinEnter', 'FileType' }, nil, function(args)
    if vim.bo[args.buf].buftype ~= '' then return end
    vim.wo[0][0].winbar = "%{%v:lua.require'config.winbar'.render()%}"
    -- Without this the bar sits empty until the first cursor move.
    refresh(args.buf)
  end, "Show the container breadcrumb in 'winbar'")
end

return M
