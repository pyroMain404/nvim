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
- I tool none-ls (stylua, black) si auto-installano tramite l'hook mason-registry in `user/mason.lua`.
- nvim-tree: `filesystem_watchers.ignore_dirs` include `/Temp/rust-analyzer` (rust-analyzer inonda %TEMP% di eventi); l'opzione SOSTITUISCE i default, quindi i default sono ripetuti nella lista.

## Come testare (headless)

File di prova già pronti in `C:\Users\gaeesp\nvim-test\` (lua, py, sh, json, yaml, ts, c, md + progetto cargo in `rust\`).

```powershell
# startup: deve essere completamente silenzioso
nvim --headless "+lua vim.defer_fn(function() vim.cmd('qa!') end, 5000)"

# health di un plugin
nvim --headless -c "checkhealth which-key" -c "w! out.txt" -c "qa!"
```

Trappole della modalità headless (verificate, non supposizioni):

- **`ensure_installed` di mason-lspconfig NON gira in headless** (guardia `platform.is_headless` nel plugin). Per installare server headless: `nvim --headless "+MasonInstall <pacchetti>" +qa` (bloccante, fatto apposta).
- **L'evento VeryLazy non scatta in headless** (niente UIEnter): i plugin VeryLazy si testano forzando `require("<modulo>")`.
- Parser treesitter headless: `+TSInstallSync <lingue>` (l'output async di `TSUpdate` può mentire).
- Per verificare l'attach LSP: aprire un file e fare polling con `vim.wait(..., function() return #vim.lsp.get_clients{bufnr=...} > 0 end)`. Il primo attach può richiedere 10-20s.
- NON testare in percorsi profondi (es. sandbox in %TEMP% annidata): si supera MAX_PATH e compaiono falsi errori (checkout git falliti, ENOENT della cache luac).

## Routine di fine lavoro

1. Test headless di startup pulito.
2. Commit sul branch `windows`, push.
3. Bump del submodule in `~\pyro-resources` (vedi sopra).
