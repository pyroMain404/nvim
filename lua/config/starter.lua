-- ┌─────────┐
-- │ Starter │
-- └─────────┘
--
-- Picks the 'mini.starter' menu: the first module in `menus` whose context applies, else the default.

local M = {}

-- Each module exposes `starter_config()`: a `MiniStarter.config` table, or `nil` if its context does not apply.
local menus = { 'config.obsidian' }

--- Argument for `MiniStarter.setup()`; `nil` gives the default screen.
function M.config()
  for _, name in ipairs(menus) do
    local ok, config = pcall(function() return require(name).starter_config() end)
    if ok and config then return config end
    -- A broken condition must not leave Neovim without a start screen.
    if not ok then
      vim.notify(('Starter menu %s: %s'):format(name, config), vim.log.levels.WARN)
    end
  end
end

return M
