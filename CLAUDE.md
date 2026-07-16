# CLAUDE.md — Neovim config (Windows)

Guida per sessioni future di Claude Code su questa config.

## Convenzioni sui path

I path assoluti specifici della macchina NON compaiono in questo file né negli altri documenti portabili (slash command, skill): si usano solo le terminologie sostitutive qui sotto. I valori reali per la macchina corrente stanno nella memory di Claude (`path-conventions`), che non viaggia col repo. Non dare mai per scontata la struttura delle directory: rileva i path a runtime.

- **`<config-dir>`** — la cartella di questa config (il repo). **Sempre presente**: è la dir su cui gira Neovim (symlinkata dalla dir config standard). A runtime: `git rev-parse --show-toplevel`.
- **`<superproject>`** — il repo contenitore che include la config come **submodule `nvim`**. **Può non esistere**: non darne per scontata la presenza. Rilevalo strutturalmente con `git rev-parse --show-superproject-working-tree` (output vuoto ⇒ assente).
- **`<test-dir>`** — cartella dei file di prova per i test headless.

## Layout del repo

- Questa config vive sul branch **`windows`** di `pyroMain404/nvim`. Il branch `master` remoto contiene una config **diversa e indipendente** (WSL2: lua/core + lua/plugins, snacks, blink-cmp): non mergiare mai i due branch.
  - **Isolamento worktree**: il default branch del repo è `master`, quindi un worktree "fresh" (es. `EnterWorktree` senza specificare la base) parte da `master` = la config sbagliata e disgiunta. Per lavorare isolati su `windows`, crea il worktree a mano dalla base giusta: `git worktree add .claude/worktrees/<nome> -b <branch> origin/windows`. Verifica sempre con `git merge-base --is-ancestor origin/windows HEAD` (deve passare) e la presenza di `lua/user/launch.lua` (marker di windows; `lua/core/` sarebbe master). Le PR hanno base **windows**, mai master.
- Remote `upstream` = `LunarVim/Launch.nvim` (la base originale). È fermo a dicembre 2024 ed è già stato mergiato: non c'è più niente da prendere.
- Il **`<superproject>`** contiene questa config come **submodule `nvim`** (branch windows), quando presente. Dopo ogni push qui, se il `<superproject>` esiste aggiornarlo: dentro il submodule (`<config-dir>`) `git pull --ff-only origin windows`, poi nel `<superproject>` `git add nvim` + commit + push.
- La dir config standard di Neovim (`%LOCALAPPDATA%\nvim` su Windows) è un **symlink** a `<config-dir>`: editare i file qui = editare la config che nvim carica, nessuna copia da sincronizzare né da cercare. Testa headless con `nvim` normale, legge il symlink. La dir dati (`stdpath("data")`, `%LOCALAPPDATA%\nvim-data`) è invece **separata** da `<config-dir>`.
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
- **Java via nvim-jdtls** (`user/jdtls.lua`), NON via mason-lspconfig: jdtls vuole un client per-progetto con workspace dedicato e un avvio ad-hoc. Perciò jdtls **non** è in `lsp_servers.lua` ed è **escluso da `automatic_enable`** in `mason.lua` (`automatic_enable = { exclude = { "jdtls" } }`), altrimenti girerebbero due client sullo stesso buffer. Avvio manuale con `java -jar` (launcher equinox + `config_win` + `-data <workspace-per-progetto>`, lombok opzionale), così l'unica dipendenza è la JDK, non anche Python. **Guardia di versione, non solo presenza**: eclipse.jdt.ls è compilato per Java 21+, quindi con una JDK più vecchia crasha con `UnsupportedClassVersionError`; `jdtls.lua` risolve la JVM del server preferendo `JAVA_HOME` (gli installer Windows tipo Temurin la impostano su una versione più recente di quella lasciata nel PATH), poi `java` del PATH, e usa la prima JDK >= 21; se nessuna basta non avvia il client e avvisa una volta (pigro, su `ft=java`). Non reintrodurre jdtls in `lsp_servers.lua`/`ensure_installed`. jdtls scrive metadati Eclipse nella root del progetto (`.project`, `.classpath`, `.factorypath`, `.settings/`): sono coperti dal `.gitignore` globale dell'utente (`~/.gitignore_global`, fuori dal repo). La cartella di output `bin/` NON è nel gitignore globale (in altri progetti può essere codice versionato): `jdtls.lua` la ignora solo nei progetti dove gira, aggiungendo `/bin/` al `.git/info/exclude` locale (idempotente).
- I tool none-ls (stylua, black) si auto-installano tramite l'hook mason-registry in `user/mason.lua`.
- nvim-tree: `filesystem_watchers.ignore_dirs` include `/Temp/rust-analyzer` (rust-analyzer inonda %TEMP% di eventi); l'opzione SOSTITUISCE i default, quindi i default sono ripetuti nella lista.

## Come testare

Usa la skill di progetto **verifying-nvim-config** (in `.claude/skills/`): contiene la procedura headless completa e le trappole verificate (ensure_installed saltato in headless, VeryLazy che non scatta, TSUpdate che mente, exit code sempre 0, MAX_PATH). File di prova in `<test-dir>`.

## Routine di fine lavoro

1. Test headless di startup pulito.
2. Commit sul branch `windows`, push.
3. Bump del submodule nel `<superproject>`, se presente (vedi sopra).
