-- ┌────────────────────────┐
-- │ Global value of 'path' │
-- └────────────────────────┘
-- Per-buffer extensions of 'path' for 'plugin/10_options.lua', c and git patch buffers.

local M = {}

-- NOTE: a constant, not a read of `vim.o.path`: the first write to a
-- never-locally-set global-local option also overwrites the global (Neovim 0.12.5).
M.default = '.;,,'

--- Value of 'path' for a buffer that adds `dirs` (already escaped) to the default.
---@param dirs string[]
---@return string
M.with = function(dirs) return M.default .. ',' .. table.concat(dirs, ',') end

return M
