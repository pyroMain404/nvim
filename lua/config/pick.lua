-- ┌───────────────────┐
-- │ Picker item shows │
-- └───────────────────┘
--
-- `source.show` of 'mini.pick' (`:h MiniPick-source.show`), set in 'plugin/30_mini.lua'.

local M = {}

local shorten_path = function(path)
  local head, tail = path:match('^(.*[/\\])([^/\\]+[/\\][^/\\]+[/\\][^/\\]+)$')
  if head == nil then return path end
  return vim.fn.pathshorten(head .. 'x'):sub(1, -2) .. tail
end
local shorten = function(s) return (s:gsub('^[^%z]+', shorten_path, 1)) end

M.show = function(buf_id, items, query)
  local has_path = false
  -- NOTE: the icon needs the real `path`, kept alongside the shortened `text`.
  local short = vim.tbl_map(function(item)
    local text = type(item) == 'table' and item.text or item
    if type(text) ~= 'string' then return item end
    has_path = has_path or text:find('[/\\]') ~= nil
    local path = type(item) == 'table' and item.path or text:match('^[^%z]+')
    return { text = shorten(text), path = path }
  end, items)
  MiniPick.default_show(buf_id, short, query, { show_icons = has_path })
end

return M
