# Engine audit findings

Each entry records a finding from the config engine audit, the file and line where it was observed, the evidence that decided it, and its verdict.

- **L4** — `after/ftplugin/gdscript.lua:81` — `vim.opt_local.isfname:append(':')` mutates the global `isfname` option in Neovim 0.12 (`isfname` is global-only); measured `gf` on `res://scripts/tracker.gd` still opens the resolved buffer after removing the append, because the `BufReadCmd` in `plugin/40_plugins.lua` strips the scheme. — fixed
