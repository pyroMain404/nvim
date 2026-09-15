# Engine audit findings

Each entry records a finding from the config engine audit, the file and line where it was observed, the evidence that decided it, and its verdict.

- **H1** — `lua/config/health.lua:595` — compilation database loop assigned without `break`, so `compile_flags.txt` won over `compile_commands.json` — fixed
- **H2** — `lua/config/health.lua:141` — `rustup show active-toolchain` returning nil reported as green `active toolchain: unknown` — fixed
- **H3** — `lua/config/health.lua:193` — `node --version` spawned twice in Angular section; now reused from `report()` — fixed
- **L4** — `after/ftplugin/gdscript.lua:81` — `vim.opt_local.isfname:append(':')` mutates the global `isfname` option in Neovim 0.12 (`isfname` is global-only); measured `gf` on `res://scripts/tracker.gd` still opens the resolved buffer after removing the append, because the `BufReadCmd` in `plugin/40_plugins.lua` strips the scheme. — fixed
- **L3** — `after/ftplugin/rust.lua:24`, `after/ftplugin/gdscript.lua:219`, `after/ftplugin/markdown.lua:25` — the `buffer` key on `vim.keymap.set`/`del` is deprecated and its fallthrough on removal makes a buffer-local map global; changed to `buf = true` / `buf = 0` in the owned ftplugin files. `plugin/41_git.lua:448` is outside this assignment. — fixed (partial: 41_git.lua left to Workflow agent)
- **L8** — `after/ftplugin/markdown.lua:19,22` — used `vim.cmd('setlocal ...')` for window-local options; replaced with `vim.wo[0][0]` assignments as the documented, reproducible way to set window-local options without going through an Ex command. — fixed
- **L9** — `after/lsp/lua_ls.lua:83-90` — the NOTE documented that LuaLS code lens carry an empty command and that disabling them would remove both the count and the empty command, but the returned `settings.Lua` omitted the key; added `codeLens = { enable = false }` and turned the NOTE into the record of the decision. — fixed
