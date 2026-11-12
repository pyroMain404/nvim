-- ┌─────────┐
-- │ Starter │
-- └─────────┘
-- Select the first context menu in `menus`. Apply the project's `start` contract over it.
-- Use the default menu if neither applies.

local M = {}

-- Each module exposes `starter_config()`, which returns a `MiniStarter.config` table or `nil` when
-- its context does not apply.
local menus = { 'config.obsidian' }

local function context_menu()
  for _, name in ipairs(menus) do
    local ok, config = pcall(function() return require(name).starter_config() end)
    if ok and config then return config end
    -- A broken condition must not leave Neovim without a start screen.
    if not ok then
      vim.notify(('Starter menu %s: %s'):format(name, config), vim.log.levels.WARN)
    end
  end
end

local function is_item(x) return type(x) == 'table' and x.name ~= nil end

-- Project items replace base items with the same section and name.
-- Insert other items before the first entry that is not a plain item.
-- Thus, `mini.starter` section functions, such as recent files and builtin actions, stay last.
-- NOTE: Add both duplicate project items if the base has no matching section and name.
-- The user owns the project file and can see and fix these duplicates.
local function merge_items(base_items, project_items)
  local items, index = {}, {}
  for i, item in ipairs(base_items) do
    items[i] = item
    if is_item(item) and item.section then
      index[item.section .. '\0' .. item.name] = i
    end
  end
  local added = {}
  for _, item in ipairs(project_items) do
    local at = index[item.section .. '\0' .. item.name]
    if at then
      items[at] = item
    else
      table.insert(added, item)
    end
  end
  local tail = #items + 1
  for i, item in ipairs(items) do
    if not is_item(item) then
      tail = i
      break
    end
  end
  for i, item in ipairs(added) do
    table.insert(items, tail + i - 1, item)
  end
  return items
end

-- Apply the project's `start` contract from 'lua/config/project.lua' to `base`, the context menu or
-- `nil`.
-- With `merge` and a base, use the project header if present and merge items.
-- Otherwise, use only the project menu without builtin items after it.
-- This includes `substitute` and `merge` without a base. The default screen never serves as a base.
local function project_menu(base)
  local start, root = require('config.project').contract('start')
  if not start then return base end
  if start.strategy == 'merge' and base then
    return vim.tbl_extend('force', base, {
      header = start.header or base.header,
      items = merge_items(base.items, start.items),
    })
  end
  return {
    header = start.header
      or (
        'Project: '
        .. vim.fs.basename(root)
        .. '\n'
        .. vim.fn.fnamemodify(root, ':~')
      ),
    items = vim.list_extend({}, start.items), -- Copy the cached contract value.
  }
end

--- Return the argument for `MiniStarter.setup()`. `nil` selects the default screen.
function M.config()
  local base = context_menu()
  local ok, config = pcall(project_menu, base)
  if ok then return config end
  -- A broken project must not leave Neovim without a start screen.
  vim.notify(('Starter menu project: %s'):format(config), vim.log.levels.WARN)
  return base
end

return M
