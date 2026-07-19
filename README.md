# Neovim Config — Windows

Personal Neovim configuration for Windows, based on [Launch.nvim](https://github.com/LunarVim/Launch.nvim) and modernized for **Neovim 0.11+** (native `vim.lsp.config`, mason-lspconfig v2, which-key v3).

> **Branch layout of this repo**: this configuration lives on the `windows` branch.
> The `master` branch contains a different, unrelated config targeting WSL2.

## Prerequisites

Everything below must be available on `PATH` before the first launch.

| Dependency | Used for | Install (winget) |
|---|---|---|
| Neovim ≥ 0.11 | — | `winget install Neovim.Neovim` |
| Git | plugin manager, gitsigns, neogit | `winget install Git.Git` |
| zig (or gcc/clang) | compiling treesitter parsers | `winget install zig.zig` |
| Node.js | LSP servers installed via Mason (ts_ls, eslint, jsonls, yamlls, bashls, somesass_ls, tailwindcss, html, pyright) | `winget install Schniz.fnm` + `fnm install --lts` |
| Python 3 | `black` formatter (Mason installs it via pip) | `winget install Python.Python.3.12` |
| ripgrep | Telescope live grep | `winget install BurntSushi.ripgrep.GNU` |
| A [Nerd Font](https://www.nerdfonts.com/) | icons in statusline, tree, telescope | `winget install DEVCOM.JetBrainsMonoNerdFont` (then set it in your terminal) |

> **Note on fnm**: Node installed through fnm is only on `PATH` inside shells that run the fnm env hook. If you launch Neovim from a GUI shortcut, make sure Node is reachable there too (or install Node system-wide), otherwise Mason cannot install the npm-based language servers.

## Installation

```powershell
git clone -b windows https://github.com/pyroMain404/nvim "$env:LOCALAPPDATA\nvim"
nvim
```

On the first launch, everything is installed automatically:

1. **lazy.nvim** bootstraps itself and installs every plugin at the exact versions pinned in `lazy-lock.json`.
2. **mason-lspconfig** installs the language servers (`ensure_installed` in `lua/user/mason.lua`) and enables them.
3. **Mason** also installs the none-ls tools (`stylua`, `black`).
4. **nvim-treesitter** compiles the parsers listed in `lua/user/treesitter.lua` when the first file is opened (this is where the C compiler is needed).

Give the first launch a couple of minutes, then restart Neovim and run:

```
:checkhealth
:Lazy
:Mason
```

## Notes

- `<leader>` is `Space`; press it and wait to see the which-key popup with all mappings.
- Plugin versions are pinned in `lazy-lock.json` (committed). Use `:Lazy update` to update and re-pin, `:Lazy restore` to go back to the lockfile.
- nvim-treesitter is pinned to the `master` branch: the `main` branch is a rewrite with a different API, incompatible with this config.
- Optional extras live in `lua/user/extras/` and are not loaded by default; add a `spec "user.extras.<name>"` line in `init.lua` to enable one.
