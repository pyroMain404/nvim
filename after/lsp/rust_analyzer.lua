-- ┌───────────────┐
-- │ rust-analyzer │
-- └───────────────┘
--
-- This file contains configuration of the Rust language server.
-- Source: https://github.com/rust-lang/rust-analyzer
-- Install: `rustup component add rust-analyzer rust-src`. Installing through
-- `rustup` is what keeps the server built from the same commit as the active
-- toolchain, and `rust-src` is what lets it analyze the standard library.
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
--
-- This file deliberately holds nothing but tables. 'nvim-lspconfig' ships two
-- hundred lines for this server: a workspace root resolved through `cargo
-- metadata`, dependency sources attaching to the running client instead of a new
-- one, the `:LspCargoReload` command, and the `before_init` that copies the
-- settings below into the `initializationOptions` the server reads at startup.
-- Every 'lsp/rust_analyzer.lua' found on 'runtimepath' is merged with
-- `vim.tbl_deep_extend('force')`, which merges tables but replaces functions, so
-- defining `on_attach`, `before_init` or `root_dir` here would delete the
-- inherited one and everything it did - starting with these settings ever
-- reaching the server. Run `:=vim.lsp.config['rust_analyzer']` to read what is
-- inherited; buffer-local behavior belongs in an `:h LspAttach` autocommand.
return {
  -- `cmd`, `filetypes` and `root_dir` come from 'nvim-lspconfig'. Leaving `cmd`
  -- as the bare `rust-analyzer` is a choice: the call then goes through the
  -- `rustup` proxy, which honors a project's 'rust-toolchain.toml'. An absolute
  -- path would pin a single toolchain for every project.

  -- Structure of these settings comes from rust-analyzer, not from Neovim. The
  -- names are those of `rust-analyzer --print-config-schema`, and they do change
  -- between releases: check them against the installed version.
  settings = {
    ['rust-analyzer'] = {
      -- Report `clippy` lints while typing instead of only in CI. Rust's own
      -- linter is what catches the mistakes `rustc` accepts.
      check = { command = 'clippy' },

      -- Procedural macros are what `#[tokio::main]` and `sqlx::query!` expand
      -- to. Without this the code inside them is invisible to the server, which
      -- then reports it as errors.
      procMacro = { enable = true },

      -- 'nvim-lspconfig' turns every code lens on and tells the server that
      -- three client commands are implemented, while only `runSingle` is.
      -- `showReferences` is filled in by 'plugin/40_plugins.lua'; `debugSingle`
      -- asks for a debugger and not a handful of lines, so the "Debug" lens
      -- fails when run. Turn it back on together with a DAP client, not before.
      lens = { debug = { enable = false } },
    },
  },
}
