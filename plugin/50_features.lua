-- ┌─────────────────────────┐
-- │ In-house feature wiring │
-- └─────────────────────────┘
--
-- Switches on the modules of 'lua/config/' that need autocommands or commands.
-- Modules reached only through a mapping are required by name there instead.

local later = Config.later

-- Git ========================================================================
later(function() require('config.git.autocmds').setup() end)
