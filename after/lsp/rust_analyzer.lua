-- ┌───────────────┐
-- │ rust-analyzer │
-- └───────────────┘
--
-- Install with `rustup component add rust-analyzer rust-src`.
-- This file contains only tables.
-- A function such as `before_init` would replace the inherited one, which passes `settings`.
return {
  -- This file leaves `cmd` bare, so the `rustup` proxy uses 'rust-toolchain.toml'.
  settings = {
    ['rust-analyzer'] = {
      check = { command = 'clippy' },
      procMacro = { enable = true },

      -- The lens stays off until a DAP client is available, because `debugSingle` needs one.
      lens = { debug = { enable = false } },
    },
  },
}
