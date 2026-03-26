# Neovim Config — WSL2 Full-Stack

Neovim configuration for full-stack development (TypeScript/Angular, Java/Spring Boot, Rust, Go) on **WSL2 Ubuntu**, with AI integration via `agentic.nvim` and Claude Code.

**Requirements**: Neovim >= 0.11, WSL2 Ubuntu 22.04+

---

## Installation

### 1. System dependencies

```bash
# Core tools
sudo apt update && sudo apt install -y \
  git curl unzip wget ripgrep fd-find \
  build-essential xclip

# fd symlink (required by snacks.picker.explorer)
mkdir -p ~/.local/bin && ln -s /usr/bin/fdfind ~/.local/bin/fd

# Nerd Font (required for UI icons)
# Download and install manually in the Windows terminal:
# https://www.nerdfonts.com/font-downloads  (e.g. JetBrainsMono Nerd Font)
```

### 2. Runtimes

```bash
# Node.js (if not present — use nvm or apt)
# https://github.com/nvm-sh/nvm

# Global npm packages
npm install -g neovim tree-sitter-cli

# Python provider (isolated venv — avoids system package conflicts)
python3 -m venv ~/.venv/neovim
~/.venv/neovim/bin/pip install pynvim

# Rust (required by blink.cmp and some mason tools)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Go (required by gopls and some mason tools)
# https://go.dev/doc/install

# Claude Code (primary AI provider)
npm install -g @anthropic-ai/claude-code
```

### 3. Python provider in Neovim

Add to the top of `init.lua` (already present):

```lua
vim.g.python3_host_prog = vim.fn.expand("~/.venv/neovim/bin/python3")
```

### 4. First launch

On first open, `lazy.nvim` bootstraps itself and installs all plugins.
Then run inside Neovim:

```
:Lazy sync
:MasonInstall stylua prettier google-java-format goimports gofumpt eslint_d
:MasonInstall js-debug-adapter java-debug-adapter java-test
:TSInstall javascript typescript tsx html css json lua bash regex markdown markdown_inline yaml
```

### 5. Java (optional)

```bash
# sdkman to manage multiple JDKs
curl -s "https://get.sdkman.io" | bash
sdk install java 17.0.x-tem   # JavaSE-17
sdk install java 21.0.x-tem   # JavaSE-21
```

The path `~/.sdkman/candidates/java/` is already configured in `ftplugin/java.lua`.

---

## Structure

```
nvim/
├── init.lua              # Entry point: lazy bootstrap, core setup
├── lazy-lock.json        # Plugin version lockfile
├── ftplugin/
│   └── java.lua          # JDTLS (Java LSP) config, loaded per filetype
└── lua/
    ├── core/
    │   ├── options.lua   # Editor options (tabs, indent, UI, etc.)
    │   ├── keymaps.lua   # Global key mappings
    │   └── autocmds.lua  # Autocommands (yank highlight, trailing whitespace, etc.)
    ├── plugins/          # One file per plugin or logical group
    │   ├── agentic.lua
    │   ├── blink-cmp.lua
    │   ├── colorscheme.lua
    │   ├── dap.lua
    │   ├── editor.lua
    │   ├── gitsigns.lua
    │   ├── grapple.lua
    │   ├── grug-far.lua
    │   ├── lsp.lua
    │   ├── overseer.lua
    │   ├── smart-splits.lua
    │   ├── snacks.lua
    │   ├── treesitter.lua
    │   ├── trouble.lua
    │   └── which-key.lua
    └── lsp/
        └── servers.lua   # Per-server LSP configurations
```

---

## Plugins

| Plugin | Purpose |
|--------|---------|
| `lazy.nvim` | Package manager |
| `catppuccin` | Colorscheme (mocha) |
| `snacks.nvim` | Dashboard, picker, notifier, terminal, indent, scroll, statuscolumn |
| `blink.cmp` | Completion engine (Rust core, very low latency) |
| `nvim-treesitter` | Syntax highlighting and structural text objects |
| `mason.nvim` | Installer for LSP servers, DAP adapters, linters, formatters |
| `mason-lspconfig` | Bridge between Mason and native LSP |
| `conform.nvim` | Format on save |
| `nvim-lint` | Async linting |
| `nvim-dap` + ui | Debug Adapter Protocol |
| `nvim-jdtls` | Full-featured Java LSP (JDTLS) |
| `agentic.nvim` | AI via ACP protocol (Claude Code, Gemini, etc.) |
| `gitsigns.nvim` | Inline git hunks and blame |
| `grapple.nvim` | Per-branch file tagging |
| `grug-far.nvim` | Project-wide search & replace |
| `overseer.nvim` | Task runner (npm, make, cargo, etc.) |
| `trouble.nvim` | Aggregated diagnostics panel |
| `which-key.nvim` | Contextual keymap guide |
| `smart-splits.nvim` | Seamless split navigation with Tmux |
| `mini.*` | surround, pairs, comment, ai, icons |

### Configured LSP servers

| Server | Language |
|--------|----------|
| `vtsls` | TypeScript, JavaScript, TSX |
| `angularls` | Angular |
| `eslint` | JS/TS linting |
| `html` | HTML |
| `cssls` | CSS/SCSS |
| `jsonls` | JSON |
| `yamlls` | YAML |
| `lua_ls` | Lua |
| `rust_analyzer` | Rust |
| `gopls` | Go |
| `jdtls` | Java (via `ftplugin/java.lua`) |

---

## Key mappings

**Leader**: `<Space>`

### File navigation

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files in project |
| `<leader>fg` | Live grep in project |
| `<leader>fb` | Open buffers list |
| `<leader>fr` | Recent files |
| `<leader>e` | File explorer |
| `<leader>m` | Toggle file tag (Grapple) |
| `<leader>1`-`5` | Jump to tagged file |

### Code / LSP

| Key | Action |
|-----|--------|
| `K` | Hover documentation |
| `gd` | Go to definition |
| `gr` | References |
| `gI` | Implementations |
| `<leader>ca` | Code action |
| `<leader>cr` | Rename symbol |
| `<leader>cd` | Line diagnostics |
| `<leader>cf` | Format file |
| `[d` / `]d` | Previous/next diagnostic |

### Git

| Key | Action |
|-----|--------|
| `<leader>gs` | Staged files |
| `<leader>gl` | Git log |
| `]h` / `[h` | Next/previous hunk |
| `<leader>hs` | Stage hunk |
| `<leader>hr` | Reset hunk |
| `<leader>hb` | Blame line |

### AI (agentic.nvim)

| Key | Action |
|-----|--------|
| `<C-\>` | Toggle AI chat |
| `<C-'>` | Add file/selection to context |
| `<C-,>` | New session |
| `<leader>ad` | Add line diagnostic to context |
| `<leader>aD` | Add all buffer diagnostics to context |

### Debug (DAP)

| Key | Action |
|-----|--------|
| `<leader>db` | Toggle breakpoint |
| `<leader>dc` | Continue |
| `<leader>di` | Step into |
| `<leader>do` | Step over |
| `<leader>dO` | Step out |
| `<leader>du` | Toggle DAP UI |
| `<leader>dt` | Terminate session |

### Tasks and terminal

| Key | Action |
|-----|--------|
| `<leader>or` | Run task (Overseer) |
| `<leader>ot` | Task list |
| `<C-/>` | Toggle floating terminal |

### Windows and buffers

| Key | Action |
|-----|--------|
| `Alt+h/j/k/l` | Navigate between splits (and Tmux panes) |
| `Ctrl+←/→/↑/↓` | Resize splits |
| `Tab` / `S-Tab` | Next/previous buffer |
| `<leader>bd` | Close buffer |

---

## WSL2 notes

- **Clipboard**: uses `xclip` (`sudo apt install xclip`). Config uses `unnamedplus`.
- **Tmux**: `smart-splits.nvim` integrates automatically when Tmux is running — add the suggested configuration to `~/.tmux.conf`.
- **Networking**: enable **Mirrored Networking** in `~/.wslconfig` for direct `localhost` access from Windows:
  ```ini
  [wsl2]
  networkingMode=mirrored
  ```
- **File system**: keep project files under `~/` (Linux file system), not `/mnt/c/` — I/O performance is dramatically better.

---

## Health check

```
:checkhealth agentic
:checkhealth blink.cmp
:checkhealth mason
:checkhealth nvim-treesitter
:checkhealth vim.lsp
```
