-- ┌────────────────┐
-- │ XML behaviour  │
-- └────────────────┘
--
-- Neovim detects `pom.xml` as plain `xml` ('plugin/40_plugins.lua'), so opening
-- the manifest never loads 'after/ftplugin/java.lua'. Gated on the exact
-- basename: `:make` and `:Run` for a Maven project, never blanket XML behavior.
local bufname = vim.api.nvim_buf_get_name(0)
if vim.fs.basename(bufname) ~= 'pom.xml' then return end

-- NOTE: an aggregator pom with neither `spring-boot-maven-plugin` nor
-- `exec-maven-plugin` resolves to `mvn exec:java` and fails loudly in the
-- terminal; a project overrides it with `vim.b.run_command` (`:h 'exrc'`).
require('config.ft').maven(bufname)
