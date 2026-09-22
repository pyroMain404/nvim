-- ┌────────────────┐
-- │ XML behaviour  │
-- └────────────────┘
--
-- Neovim detects `pom.xml` as plain `xml` ('plugin/40_plugins.lua'), so
-- opening the manifest itself never loads 'after/ftplugin/java.lua' - the
-- file that defines `:Run` from a `.java` buffer by walking up to its
-- project's `pom.xml`. Opening the manifest directly hit `E492: Not an
-- editor command: Run`.
--
-- The fix stays minimal and gated on the exact basename `pom.xml` - never a
-- blanket XML behavior.
--
-- Two things follow from being that manifest, both reused from `java.lua`
-- rather than duplicated:
-- - `:Run`, through 'lua/config/run.lua''s `java_builds` - so the goal it
--   picks (`spring-boot:run`, `exec:java`) never diverges between a `.java`
--   buffer and the manifest itself;
-- - `:compiler maven` (`:h :compiler`, '$VIMRUNTIME/compiler/maven.vim'),
--   so `:make clean install` works from the manifest exactly as it already
--   does from a `.java` buffer under the same project. `java.lua`'s own
--   'foldmethod'/`shiftwidth`/Javadoc settings stay Java-specific and are
--   not pulled in here - they have no meaning on an XML buffer.
local bufname = vim.api.nvim_buf_get_name(0)
if vim.fs.basename(bufname) ~= 'pom.xml' then return end

local build = require('config.run').java_builds['pom.xml']

-- The buffer already IS the build file, so there is nothing to walk up
-- for: `build_file` is this buffer's own name, and the root `M.command()`
-- falls back to when `resolve` returns no third value is already this
-- file's directory (`:h vim.fs.dirname()`) - no explicit root needed.
--
-- NOTE: an aggregator `pom.xml` (`<packaging>pom</packaging>`, no
-- `spring-boot-maven-plugin` and no `exec-maven-plugin` - the case of
-- `assimoco-passportal-client`) resolves to `mvn exec:java`, which fails
-- loudly in the terminal split rather than doing nothing quietly - the same
-- contract 'java.lua' documents above. A project whose real start is
-- something else entirely (here: `npm run serve-local` from
-- `src/main/angular/`) overrides it from its own '.nvim.lua' with
-- `vim.g.run_command`/`vim.b.run_command` (`:h 'exrc'`, skill
-- `nvim-project-environment`) - `M.command()` checks that override before
-- ever calling this resolver.
require('config.run').command(function(args) return build.run(args, bufname) end)

-- `:compiler` defines its options through a command it creates and deletes
-- while sourcing, so it has no Lua API and `vim.cmd()` is the only way here
-- (same as 'java.lua').
vim.cmd('compiler maven')

-- `mvn` prints paths relative to the project, while Neovim resolves
-- quickfix `%f` entries against its own directory - kept at the repository
-- root by 'setup_auto_root()' in 'plugin/30_mini.lua', not necessarily
-- `pom.xml`'s own directory in a multi-module checkout. Same remedy
-- 'java.lua' needs for a `.java` buffer, shared through
-- 'lua/config/run.lua''s `make_root()`.
require('config.run').make_root({ 'pom.xml' })

-- Undo the compiler selection when the filetype changes away from `xml`
-- (`:h b:undo_ftplugin`). `:Run` undoes itself, registered inside
-- 'lua/config/run.lua''s `M.command()`.
vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n'
  .. table.concat({
    'setlocal makeprg< errorformat<',
    'unlet! b:current_compiler',
  }, ' | ')
