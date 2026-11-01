-- ┌────────────────┐
-- │ XML behaviour  │
-- └────────────────┘
--
-- `pom.xml` is plain `xml`, so it never loads 'after/ftplugin/java.lua'.
local bufname = vim.api.nvim_buf_get_name(0)
if vim.fs.basename(bufname) ~= 'pom.xml' then return end

-- NOTE: an aggregator pom with neither `spring-boot-maven-plugin` nor
-- `exec-maven-plugin` resolves to `mvn exec:java` and fails loudly; override
-- with `vim.b.run_command`.
require('config.ft').maven(bufname)
