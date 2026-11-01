-- ┌─────────────────────────┐
-- │ In-house feature wiring │
-- └─────────────────────────┘
--
-- Switches on the modules of 'lua/config/' that need autocommands or commands.
-- Modules reached only through a mapping are required by name there instead.

local now, later = Config.now, Config.later

-- Git ========================================================================
later(function() require('config.git.autocmds').setup() end)

-- Editor behaviour ===========================================================
now(function() require('config.winbar').setup() end)
now(function() require('config.make').setup() end)
