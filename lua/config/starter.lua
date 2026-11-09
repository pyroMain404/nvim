-- ┌─────────┐
-- │ Starter │
-- └─────────┘
--
-- Picks the 'mini.starter' menu: the first context in `menus`, then the project's `start` contract on top, else the default.

local M = {}

-- Each module exposes `starter_config()`: a `MiniStarter.config` table, or `nil` if its context does not apply.
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

-- Project items replace the base item with the same section and name; the rest are
-- inserted before the first entry that is not a plain item (`mini.starter` section
-- functions such as recent files and builtin actions), so those stay last.
-- NOTE: two project items with the same section and name that the base lacks are both added;
-- the project file is the user's own, so the duplicate is theirs to see and fix.
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

-- Applies the project's `start` contract (see 'lua/config/project.lua') to `base`, the
-- context menu or `nil`. `merge` with a base: project header if given, items merged;
-- otherwise (`substitute`, or `merge` with no base: the default screen is never a base)
-- the project menu alone, with no builtin tail: the project owns it.
local function project_menu(base)
  -- `mini.starter` shows the screen only without file arguments; skip the trust prompt then.
  if vim.fn.argc() > 0 then return base end
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
    items = vim.list_extend({}, start.items), -- a copy: the contract value is cached
  }
end

--- Argument for `MiniStarter.setup()`; `nil` gives the default screen.
function M.config()
  local base = context_menu()
  local ok, config = pcall(project_menu, base)
  if ok then return config end
  -- A broken project must not leave Neovim without a start screen.
  vim.notify(('Starter menu project: %s'):format(config), vim.log.levels.WARN)
  return base
end

return M
