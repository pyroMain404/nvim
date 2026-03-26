# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Neovim configuration targeting Neovim >= 0.11 on WSL2 Ubuntu, for full-stack development in TypeScript/Angular, Java/Spring Boot, Rust, and Go. It uses **native `vim.lsp`** (no nvim-lspconfig), **lazy.nvim** as package manager, and **agentic.nvim** for AI integration via the ACP protocol.

## Architecture

### Load order

`init.lua` → `core/options` → `core/keymaps` → `core/autocmds` → `lazy.setup("plugins", ...)` (auto-discovers all files in `lua/plugins/`)

All plugins default to `lazy = true`. Startup plugins that must load immediately are marked `priority = 1000` (e.g., catppuccin) or use `init` instead of `config`.

### LSP pipeline

This config uses **Neovim 0.11+ native LSP** — `nvim-lspconfig` is intentionally absent.

The flow is:
1. `lua/plugins/lsp.lua` — sets up diagnostic UI, `LspAttach` keymaps, and merges blink.cmp capabilities into `vim.lsp.config("*", ...)`
2. `lua/lsp/servers.lua` — returns a table of `{ server_name = config_table }` for each LSP server
3. `mason-lspconfig` installs and auto-enables all servers listed in `servers.lua`
4. **Java is excluded** from this pipeline — handled entirely by `ftplugin/java.lua` via `nvim-jdtls`, which calls `jdtls.start_or_attach()` on every `.java` buffer open

To add a new LSP server: add its name and config to `lua/lsp/servers.lua`. Mason will install and enable it automatically on next `:Lazy sync`.

### Formatting and linting

- **conform.nvim** (`lua/plugins/editor.lua`) handles format-on-save (3s timeout). Tries `prettierd` first, falls back to `prettier` for web filetypes.
- **nvim-lint** runs `eslint_d` on JS/TS files on `BufWritePost`, `BufReadPost`, and `InsertLeave`.
- `<leader>cf` triggers LSP formatting as a fallback when conform has no formatter configured.

### Completion

blink.cmp with native LSP sources. Its capabilities are injected globally into every LSP server via `vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })` in `lsp.lua`.

### snacks.nvim replaces multiple plugins

`snacks.picker` replaces telescope. `snacks.notifier` replaces nvim-notify. `snacks.input` replaces dressing.nvim. `snacks.terminal` provides the floating terminal (`<C-/>`). Check `lua/plugins/snacks.lua` for what's enabled/disabled.

`mini.icons` mocks `nvim-web-devicons` via `package.preload` — plugins requesting nvim-web-devicons get mini.icons transparently.

## Key conventions

- **One file per plugin or logical group** in `lua/plugins/`. Each file returns a lazy.nvim plugin spec table.
- **Leader** is `<Space>`. Groups: `<leader>a` AI, `<leader>c` Code/LSP, `<leader>f` Find, `<leader>g` Git, `<leader>h` Hunks, `<leader>o` Overseer, `<leader>s` Search, `<leader>x` Trouble.
- **Java keymaps** (`<leader>co/cv/cc/ct/cT`, `<leader>cm` in visual) are buffer-local and defined in `ftplugin/java.lua`, not in `lua/plugins/`.
- **Treesitter**: bundled parsers (bash, c, lua, markdown, python, etc.) are listed in `ensure_installed` but `update_strategy = "lockfile"` is not set — parsers in `lazy-lock.json` control versions.

## Java-specific notes

- JDTLS workspace is stored per-project in `~/.local/share/nvim/jdtls-workspace/<project-folder-name>`
- JDK runtimes are expected at `~/.sdkman/candidates/java/17-open/` and `21-open/`. If SDK paths differ, update `ftplugin/java.lua` under `configuration.runtimes`.
- Debug and test bundles (`java-debug-adapter`, `java-test`) are resolved dynamically from Mason's install path. If Mason hasn't installed them, bundles will be empty and DAP won't work for Java.

## Common Neovim commands for this config

```
:Lazy          — plugin manager UI
:Lazy sync     — update all plugins
:Lazy profile  — startup time breakdown
:Mason         — LSP/tool installer UI
:ConformInfo   — show active formatters for current buffer
:LspInfo       — active LSP clients (use :checkhealth vim.lsp for full details)
:TSInstall <lang>  — install a treesitter parser
:checkhealth agentic blink.cmp mason nvim-treesitter vim.lsp
```
