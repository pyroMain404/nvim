-- ┌────────────────────────┐
-- │ Global value of 'path' │
-- └────────────────────────┘
--
-- Required by name from 'plugin/10_options.lua', 'after/ftplugin/c.lua' and
-- 'lua/config/git' (patch buffers), which extend it per buffer.

local M = {}

-- `.;` searches the directory of the current file and then every directory above
-- it (`:h file-searching`); the trailing `,,` keeps the working directory.
-- NOTE: a constant, not a read of `vim.o.path`: the first write to a
-- never-locally-set global-local string option from any scope also overwrites
-- the global value (Neovim 0.12.5), so reading it back later grows without bound.
M.default = '.;,,'

--- Value of 'path' for a buffer that adds `dirs` (already escaped) to the default.
---@param dirs string[]
---@return string
M.with = function(dirs) return M.default .. ',' .. table.concat(dirs, ',') end

return M
