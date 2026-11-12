-- ┌───────────────┐
-- │ rust-analyzer │
-- └───────────────┘
--
-- Install with `rustup component add rust-analyzer rust-src`. Use only tables here.
-- A function such as `before_init` would replace the inherited one, which passes `settings`.
return {
  -- Keep `cmd` bare so the `rustup` proxy uses 'rust-toolchain.toml'.
  settings = {
    ['rust-analyzer'] = {
      check = { command = 'clippy' },
      procMacro = { enable = true },

      -- Keep the lens off until a DAP client is available because `debugSingle` needs one.
      lens = { debug = { enable = false } },
    },
  },
}
