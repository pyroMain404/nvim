-- ┌────────────────┐
-- │ XML behaviour  │
-- └────────────────┘
--
-- `pom.xml` uses the `xml` filetype, so it never loads 'after/ftplugin/java.lua'.
local bufname = vim.api.nvim_buf_get_name(0)
if vim.fs.basename(bufname) ~= 'pom.xml' then return end

-- NOTE: An aggregator pom without `spring-boot-maven-plugin` or `exec-maven-plugin` resolves to
-- `mvn exec:java` and reports an error.
-- Override this command with `vim.b.run_command`.
require('config.ft').maven(bufname)
