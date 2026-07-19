# Verifica della config Neovim (headless)

> Documento di procedura — **non è una skill**: non compare in `available_skills` e non si auto-attiva. Lo legge ed esegue lo Step 1 di `/fine-lavoro`; puoi leggerlo e seguirne i comandi anche a mano per una verifica standalone. Non riconvertirlo in skill (`.claude/skills/`): la verifica deve restare un passo deliberato, non un trigger automatico.

Procedura validata per verificare questa config senza aprire l'UI. File di prova già pronti in `<test-dir>` (lua, py, sh, json, yaml, ts, c, md + progetto cargo in `rust\`). `<test-dir>` è una terminologia sostitutiva: il path reale è nella memory (`path-conventions`) — risolvilo prima di lanciare i comandi.

> **Delega della raccolta.** Il *lancio* dei comandi qui sotto e la *cattura* dell'output grezzo (stdout+stderr, exit code, client LSP attaccati, `.so` dei parser) possono essere delegati al subagent Haiku **`nvim-collector`** (`.claude/agents/nvim-collector.md`) per risparmiare token. L'**interpretazione** — output pulito o no? errore vero o falso positivo da MAX_PATH? abortire? — **resta a chi ha invocato**: l'agent raccoglie e riporta grezzo, non emette verdetti (l'exit code qui è sempre 0, non è un segnale). Le trappole qui sotto servono proprio a te per giudicare i dati che l'agent ti riporta.

## Verifica base (dopo ogni modifica)

```powershell
# 1. startup: NON deve stampare nulla
# Gli errori di startup scattano DURANTE il require sincrono di init.lua, prima
# che qualsiasi timer conti: 200 ms bastano per un giro di event loop (intercetta
# anche un errore in una callback vim.schedule accodata all'avvio). Non alzarli a
# secondi "per far caricare i lazy": in headless VeryLazy non scatta (vedi trappole).
nvim --headless "+lua vim.defer_fn(function() vim.cmd('qa!') end, 200)"

# 2. health di un plugin toccato
nvim --headless -c "checkhealth which-key" -c "w! $env:TEMP\h.txt" -c "qa!"; Get-Content $env:TEMP\h.txt
```

### Se la modifica è in una feature lazy, caricala direttamente

Lo startup test (defer 200 ms) intercetta gli errori **sincroni** di `init.lua`, ma NON esercita il codice di una feature caricata lazy: `config()`/setup di un plugin con trigger `VeryLazy`, `VimEnter`, `event`, `keys`, `cmd`, `ft` non gira in quella finestra (in headless `VeryLazy` non scatta — vedi trappole). Quindi "startup pulito" **non è** una verifica di una modifica che vive lì dentro.

Se sai già che la parte toccata è lazy, **non** fare lo startup test, constatare che la feature non è caricata e poi forzarla in un secondo run: **caricala direttamente dall'inizio** ed esercita nello stesso comando il percorso modificato. Un solo run che forza il load + controlla il comportamento vale più dello startup test per quella modifica (lo startup test resta utile solo come check aggiuntivo che `init.lua` non esploda).

```powershell
# es. modifica nel config() di telescope (lazy): carica il plugin e verifica subito
nvim --headless -c "Lazy load telescope.nvim" -c "lua
  assert(require('telescope.config').values.path_display, 'setup non applicato')
  -- ... asserzioni sul comportamento realmente cambiato ...
" -c "qa!"
```

Regola pratica: prima di lanciare, chiediti **quando** carica ciò che hai toccato. Startup/sincrono ⇒ startup test. Lazy ⇒ `Lazy load <plugin>` (o `require "<modulo>"`) + asserzioni, senza passare dallo startup.

## Verifica attach LSP per linguaggio

```powershell
nvim --headless <test-dir>\test.py "+lua vim.defer_fn(function()
  local ok = vim.wait(30000, function() return #vim.lsp.get_clients({bufnr=0}) > 0 end, 500)
  local names = {}
  for _, c in ipairs(vim.lsp.get_clients({bufnr=0})) do names[#names+1] = c.name end
  io.write('lsp: ' .. table.concat(names, ',') .. '\n')
  io.write('treesitter: ' .. tostring(vim.treesitter.highlighter.active[1] ~= nil) .. '\n')
  if not ok then vim.cmd('cquit! 1') end
  vim.cmd('qa!')
end, 3000)"
```

Primo attach: anche 10-20 s (rust_analyzer di più: indicizza il progetto cargo).

## Trappole headless (verificate, non supposizioni)

| Trappola | Rimedio |
|---|---|
| `ensure_installed` di mason-lspconfig NON gira headless (guardia `platform.is_headless`) | `nvim --headless "+MasonInstall <pkg>" +qa` — headless è bloccante by design |
| `VeryLazy` non scatta (niente UIEnter) | `vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })`, oppure `require("<modulo>")` |
| Output async di `TSUpdate` mente ("up-to-date" senza parser) | `+TSInstallSync <lingue>` e controllare i `.so` in `nvim-treesitter\parser\` |
| Exit code 0 anche se un `config()` esplode | grep dello stderr per `Failed to run|Error executing`; nei check Lua usare `vim.cmd('cquit! 1')` |
| Percorsi di test profondi superano MAX_PATH | falsi errori (checkout git falliti, ENOENT cache luac): testare in path corti tipo `$env:TEMP\nvim-ci` |
| `nvim --headless -l script.lua` **non carica init.lua**: niente lazy, niente plugin, nessun autocmd della config (jdtls/LSP non si agganciano mai → attese che vanno sempre in timeout) | non usare `-l` per verificare la config; apri il file come argomento e inietta il codice con `-c "luafile ..."`. Per un t0 *prima* dello startup: `nvim --headless --cmd "lua _G.T0=vim.uv.hrtime()" file -c "luafile obs.lua"` |

## Installazione da zero simulata (per modifiche strutturali)

```powershell
$T = "$env:TEMP\nvim-ci"; Remove-Item -Recurse -Force $T -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$T\data","$T\state","$T\cache","$T\config\nvim" | Out-Null
Copy-Item "$env:LOCALAPPDATA\nvim\init.lua","$env:LOCALAPPDATA\nvim\lazy-lock.json" "$T\config\nvim\"
Copy-Item -Recurse "$env:LOCALAPPDATA\nvim\lua" "$T\config\nvim\lua"
$env:XDG_CONFIG_HOME="$T\config"; $env:XDG_DATA_HOME="$T\data"; $env:XDG_STATE_HOME="$T\state"; $env:XDG_CACHE_HOME="$T\cache"
nvim --headless "+Lazy! restore" +qa   # installa tutto dal lockfile
# ... verifiche ...
Remove-Item Env:XDG_CONFIG_HOME,Env:XDG_DATA_HOME,Env:XDG_STATE_HOME,Env:XDG_CACHE_HOME
```

## Errori comuni

- Dichiarare "funziona" dopo il solo check di sintassi: l'attach LSP e il caricamento dei plugin VeryLazy vanno osservati davvero.
- Testare le mappature which-key contando i keymap prima che il plugin che le registra sia caricato.
- Dimenticare la routine di fine lavoro: commit su `windows` → push → bump del submodule `nvim` nel `<superproject>` se presente (vedi CLAUDE.md).
