-- ┌───────────────┐
-- │ rust-analyzer │
-- └───────────────┘
--
-- Install: `rustup component add rust-analyzer rust-src`. Only tables here: a
-- function such as `before_init` would replace the inherited one, which passes `settings`.
return {
  -- `cmd` stays bare so the `rustup` proxy honors 'rust-toolchain.toml'.
  settings = {
    ['rust-analyzer'] = {
      check = { command = 'clippy' },
      procMacro = { enable = true },

      -- `debugSingle` needs a DAP client; keep the lens off until there is one.
      lens = { debug = { enable = false } },
    },
  },
}
