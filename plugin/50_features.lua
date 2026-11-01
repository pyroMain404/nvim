-- ┌─────────────────────────┐
-- │ In-house feature wiring │
-- └─────────────────────────┘

local now, later = Config.now, Config.later

-- Git ========================================================================
later(function() require('config.git.autocmds').setup() end)

-- Editor behaviour ===========================================================
now(function() require('config.winbar').setup() end)
now(function() require('config.make').setup() end)
now(function() require('config.lsp').setup() end)
later(function() require('config.markers').setup() end)
