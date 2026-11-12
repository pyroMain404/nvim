-- ┌────────────────────────┐
-- │ Global value of 'path' │
-- └────────────────────────┘
-- This module extends 'path' per buffer for 'plugin/10_options.lua', c and git patch buffers.

local M = {}

-- NOTE: Use a constant, not `vim.o.path`. In Neovim 0.12.5, the first local write to a
-- global-local option also overwrites the global value if no local value exists.
M.default = '.;,,'

--- Return 'path' with `dirs` added to the default. The caller must escape `dirs` first.
---@param dirs string[]
---@return string
M.with = function(dirs) return M.default .. ',' .. table.concat(dirs, ',') end

return M
