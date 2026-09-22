<p align="center"> <img src="logo.png" alt="mini.nvim" style="max-width:100%;border:solid 2px"/> </p>

## Personal Neovim config

This is Gaetano Esposito's personal Neovim configuration: primarily built on ['mini.nvim'](https://github.com/nvim-mini/mini.nvim), extensively commented, meant to be read and grown by hand rather than generated or auto-updated.

See [`AGENTS.md`](AGENTS.md) for the rules this repository is held to: where a change goes, commit and changelog conventions, external dependency management, and the documentation system. See [change log](CHANGELOG.md) for a history of changes.

### Origin

This config started as a fork of [MiniMax](https://github.com/nvim-mini/MiniMax), a Neovim config generator built around 'mini.nvim' that offers several reference configs (one per supported Neovim version) to copy into `stdpath('config')` and then own. This repository kept `nvim-0.12`, the one this machine runs, deleted the others, and detached from MiniMax entirely on 2026-09-22: no upstream remote, no generator script, no multi-version layout. The structure, the `Config` helpers in `init.lua`, and much of the documentation style below still trace back to it — credit where due — but there is no ongoing relationship to keep in sync with.

### What it is not

It is not a "Neovim distribution": there is no plugin abstraction layer and no automatic config updates. It is not a template for someone else's setup — it is tuned to one machine, one user, one set of languages (see `after/ftplugin/`, `after/lsp/`). Reuse whatever parts are useful; do not expect it to stay generic.

### Requirements

#### Software

- [Neovim](https://neovim.io/) executable. Assumed to be named `nvim`.
- [Git](https://git-scm.com/) executable. Assumed to be named `git`.
- Operating system: Windows (this config assumes `pwsh` and Windows path conventions in places; adapt `after/lsp/` and `lua/config/mise.lua` for other platforms).
- Internet connection for downloading plugins.
- [`ripgrep`](https://github.com/BurntSushi/ripgrep#installation), for search.
- Terminal emulator (or GUI) with [true colors](https://github.com/termstandard/colors#truecolor-support-in-output-devices) and [Nerd Font icons](https://www.nerdfonts.com/) support.
- System requirements for [`main` branch of 'nvim-treesitter/nvim-treesitter' plugin](https://github.com/nvim-treesitter/nvim-treesitter/tree/main?tab=readme-ov-file#requirements).
- [`mise`](https://mise.jdx.dev), for language servers, formatters, linters and language runtimes (see `AGENTS.md`, "External dependencies").

#### Knowledge

Basic level of understanding of how to:

- Use CLI (command line): open, navigate file system, execute commands, close.

- Use Neovim: open, modal editing, reading help, close. If inside Neovim, type [`:h help.txt`](https://neovim.io/doc/user/helptag.html?tag=help.txt) (or click it if it is a link) followed by `<Enter>` and it should guide you through understanding basics.

    Several personal recommendations (no need to read in full; be aware of their content): [`:h notation`](https://neovim.io/doc/user/helptag.html?tag=notation), [`:h key-notation`](https://neovim.io/doc/user/helptag.html?tag=key-notation), [`:h vim-modes`](https://neovim.io/doc/user/helptag.html?tag=vim-modes), [`:h mode-switching`](https://neovim.io/doc/user/helptag.html?tag=mode-switching), [`:h windows-intro`](https://neovim.io/doc/user/helptag.html?tag=windows-intro),  [`:h vimtutor`](https://neovim.io/doc/user/helptag.html?tag=vimtutor)

- Read help files from inside Neovim: notion of help tags, key notations, navigation.

  > [!TIP]
  > Press `<Space>` + `f` + `h` to fuzzy search across all help tags.

- Read [Lua language](https://learnxinyminutes.com/lua/): variables, tables, function calls, iterations. See also [`:h lua-concepts`](https://neovim.io/doc/user/helptag.html?tag=lua-concepts) and [`:h lua-guide`](https://neovim.io/doc/user/helptag.html?tag=lua-guide).

### Setting up

This repository **is** `%LOCALAPPDATA%\nvim` (Windows) — it is cloned directly there, not copied or symlinked from elsewhere. The `pyro-resources` toolkit does this automatically (`modules/editors/install.ps1`); to do it by hand:

```powershell
# Back up or remove any existing config first
git clone --branch minimax-config https://github.com/pyroMain404/nvim "$env:LOCALAPPDATA\nvim"

# Start Neovim
nvim

# On first run, confirm installation of all listed plugins when prompted
# Wait for plugins to install (there should be no new notifications)

# Enjoy!
# Start with reading its files. Type `<Space>`+`e`+`i` to open 'init.lua'.
```

### Updating

```powershell
git -C "$env:LOCALAPPDATA\nvim" pull --ff-only
```

Read [change log](CHANGELOG.md) to see what changed. There is no automatic update mechanism and no merge to reconcile — this is a plain `git pull` against a repository with a single author.

### Similar projects

- [nvim-mini/MiniMax](https://github.com/nvim-mini/MiniMax) — the generator this config started from, if you want a reference config of your own to grow.
- [nvim-lua/kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim)
- More automated approaches ("Neovim distributions"):
    - [LazyVim/LazyVim](https://github.com/LazyVim/LazyVim)
    - [NvChad/NvChad](https://github.com/NvChad/NvChad)
    - [AstroNvim/AstroNvim](https://github.com/AstroNvim/AstroNvim)
