# CLAUDE.md — Neovim config (Windows)

Guida per sessioni future di Claude Code su questa config.

## Layout del repo

- Questa config vive sul branch **`windows`** di `pyroMain404/nvim`. Il branch `master` remoto contiene una config **diversa e indipendente** (WSL2: lua/core + lua/plugins, snacks, blink-cmp): non mergiare mai i due branch.
- Remote `upstream` = `LunarVim/Launch.nvim` (la base originale). È fermo a dicembre 2024 ed è già stato mergiato: non c'è più niente da prendere.
- La repo `~\pyro-resources` contiene questa config come **submodule `nvim`** (branch windows). Dopo ogni push qui, aggiornare anche lì: `git -C ~\pyro-resources\nvim pull --ff-only origin windows`, poi add/commit/push nel parent.
- `lazy-lock.json` è **versionato** (non rimetterlo nel gitignore): garantisce installazioni riproducibili.

## Architettura

- `init.lua` carica i moduli con `spec "user.<nome>"` (helper in `user/launch.lua` che accumula in `LAZY_PLUGIN_SPEC`); un file per plugin in `lua/user/`.
- `lua/user/extras/` NON è caricato: sono opzionali, si attivano aggiungendo `spec "user.extras.<nome>"` in init.lua. Non contarli nei controlli di coerenza.
- Impostazioni per-server LSP in `lua/user/lspsettings/<server>.lua` (caricate con pcall da lspconfig.lua).

## Decisioni prese (non regredire)

- **nvim-treesitter pinnato a `branch = "master"`**: il branch `main` è il rewrite incompatibile con `nvim-treesitter.configs`. Compilatore per i parser: zig (installato via winget).
- **LSP**: config per-server via `vim.lsp.config()` in `user/lspconfig.lua`; l'**abilitazione** la fa mason-lspconfig v2 (`automatic_enable`). Non reintrodurre il framework legacy `require("lspconfig")[s].setup` né neodev.
- **which-key v3**: mappature nella chiave `spec` di `setup` o via `wk.add`; MAI `wk.register`, `window`, `ignore_missing` (API v2 rimossa).
- **telescope-fzf-native rimosso**: su Windows la build `make` fallisce e non veniva comunque caricato.
- **Guardia delle dipendenze esterne per i server LSP** (`user/lsp_servers.lua`): l'elenco dei server è centralizzato lì (usato sia da `mason.lua` che da `lspconfig.lua`, invece di duplicarlo) e ogni voce può dichiarare `requires = "<eseguibile>"`. Se l'eseguibile non è nel PATH il server viene escluso da `ensure_installed`/`vim.lsp.config` invece di essere incluso e fallire: senza la guardia, `mason-lspconfig` **ritenta l'installazione fallita ad ogni avvio** (verificato nel sorgente di `ensure_installed.lua`), producendo un errore ogni volta. Torna disponibile da solo al riavvio successivo all'installazione del prerequisito (es. `gopls` richiede `go` nel PATH). Quando si aggiunge un server che dipende da un toolchain esterno (Go, .NET, JDK...), usare questo pattern invece di aggiungerlo direttamente alle liste.
- I tool none-ls (stylua, black) si auto-installano tramite l'hook mason-registry in `user/mason.lua`.
- nvim-tree: `filesystem_watchers.ignore_dirs` include `/Temp/rust-analyzer` (rust-analyzer inonda %TEMP% di eventi); l'opzione SOSTITUISCE i default, quindi i default sono ripetuti nella lista.

## Come testare

Usa la skill di progetto **verifying-nvim-config** (in `.claude/skills/`): contiene la procedura headless completa e le trappole verificate (ensure_installed saltato in headless, VeryLazy che non scatta, TSUpdate che mente, exit code sempre 0, MAX_PATH). File di prova in `C:\Users\gaeesp\nvim-test\`.

## Routine di fine lavoro

1. Test headless di startup pulito.
2. Commit sul branch `windows`, push.
3. Bump del submodule in `~\pyro-resources` (vedi sopra).
