-- ┌───────┐
-- │ jdtls │
-- └───────┘
--
-- This file contains configuration of the Java language server.
-- Source: https://github.com/eclipse-jdtls/eclipse.jdt.ls
-- Install: see `check_java()` in 'lua/config/health.lua' for the exact `mise`
-- line. The server is a JVM program launched by 'bin/jdtls', a Python script,
-- so `java` and `python` both have to be reachable; the `mise` shim is what
-- carries them, which is why 'jdtls' is called by name and not by path.
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
--
-- This file deliberately holds nothing but tables. Every 'lsp/jdtls.lua' found
-- on 'runtimepath' is merged with `vim.tbl_deep_extend('force')`, which merges
-- tables but replaces functions, and the one in 'nvim-lspconfig' defines `cmd`
-- as a function: it builds the `-data` workspace directory under
-- `:h stdpath()` cache from the project root and adds the JVM arguments of
-- `$JDTLS_JVM_ARGS`. Writing `cmd` here as the usual list would delete all of
-- that and make every project share one workspace. Its `root_markers` are two
-- ordered groups (`mvnw`, `gradlew`, '.git' first, then 'pom.xml' and the
-- Gradle build files), which is what keeps a multi-module build on one client
-- instead of one per module. Run `:=vim.lsp.config['jdtls']` to read it;
-- buffer-local behavior belongs in an `:h LspAttach` autocommand.
--
-- NOTE: 'nvim-jdtls' is the plugin the server's own documentation points at,
-- and it is the exclusive kind: it starts and owns the client, so it replaces
-- this file rather than adding to it. What it brings on top of what is here is
-- the JDT extensions Neovim knows nothing about - test runner, debug adapter,
-- `organizeImports`, extract refactorings, decompiled sources. Worth taking
-- when that is the day's work, not before.
return {
  -- Structure of these settings comes from jdtls, not from Neovim: they are
  -- the `java.*` keys of the Eclipse JDT language server, documented with the
  -- VS Code extension that drives it
  -- (https://github.com/redhat-developer/vscode-java#supported-vs-code-settings).
  -- Neovim hands them over when the server asks with `workspace/configuration`.
  -- Only settings whose default is off are here.
  settings = {
    java = {
      configuration = {
        -- With the default 'interactive' the server asks before re-reading
        -- 'pom.xml', through a request Neovim answers with nothing, so a
        -- dependency added to the build stays unknown and its imports keep
        -- being reported as errors until the server is restarted.
        updateBuildConfiguration = 'automatic',
      },

      -- `<Leader>ls` on a symbol of a dependency otherwise lands in a
      -- decompiled stub with no parameter names and no comments. These two
      -- make the build tool fetch the sources jar, which is the Java
      -- equivalent of `rust-src`. The cost is paid once per dependency.
      maven = { downloadSources = true },
      eclipse = { downloadSources = true },

      -- Off by default in jdtls, and it is what fills the signature window of
      -- 'mini.completion' while typing the arguments of a call
      -- (`:h MiniCompletion.config`).
      signatureHelp = { enabled = true },
    },
  },
}
