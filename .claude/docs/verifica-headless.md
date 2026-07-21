# Verifica della config Neovim

> Documento di procedura — **non è una skill**: non compare in `available_skills` e non si auto-attiva. Lo legge ed esegue lo Step 1 di `/fine-lavoro`; puoi leggerlo e seguirne i comandi anche a mano. Non riconvertirlo in skill (`.claude/skills/`): la verifica deve restare un passo deliberato, non un trigger automatico.

## Il gate primario è la CI (non il test locale)

La verifica autorevole è la **CI GitHub Actions** (`.github/workflows/headless.yml`), che gira su runner **Windows** ad ogni push/PR verso `windows` (+ dispatch manuale). Riproduce da zero l'ambiente (nvim pinnato, plugin dal `lazy-lock.json`) e applica **due gate**:

1. **Startup test** — `init.lua` non deve stampare nulla: coglie gli errori **sincroni** del require chain (moduli eager: options, keymaps, autocmds, node, projects).
2. **Load-all** — `+Lazy! load all` forza il caricamento di **tutti** i plugin, così girano anche i `config()` **lazy** (VeryLazy/ft/event/keys) che il gate 1 non tocca; in più `checkhealth vim.deprecated` per il drift di API deprecate. Detector a pattern stretti (`Failed to run` / stacktrace / errori lua) che ignorano il rumore benigno degli installer async (mason/treesitter) abortiti da `+qa`.

**Conseguenza pratica: non rifare in locale ciò che la CI già copre.** Dopo lo Step 1 di `/fine-lavoro`, è il push a innescare la verifica completa; leggine l'esito invece di replicarla a mano. Il test locale serve solo nei tre casi qui sotto.

### Cosa la CI NON copre (→ questi sì, in locale)

- **Attach LSP per linguaggio** — la CI non installa i server né compila i parser (niente zig/tree-sitter-cli sul runner): l'attach di un LSP e l'highlight treesitter reali vanno osservati in locale quando tocchi un server o un parser (vedi sotto).
- **Misconfig silenziose** — nessuno smoke-test le vede (chiave `opts` ignorata, RHS di un keymap errato che erra solo se premuto): vanno esercitate a mano aprendo il percorso specifico.
- **Riprodurre un fallimento CI** — se la CI diventa rossa, riproduci l'ambiente in locale (§ *Installazione da zero simulata*) per vedere l'output grezzo (i log delle Actions richiedono admin/token).

## Quick sanity locale (Step 1 di /fine-lavoro: fail-fast prima del push)

Un solo comando, per non pushare una rottura ovvia. La verifica *completa* la fa poi la CI sul push.

```powershell
# startup: NON deve stampare nulla. Gli errori sincroni di init.lua scattano nel
# primo giro di event loop (intercetta anche una callback vim.schedule accodata
# all'avvio): 200 ms bastano. Non alzarli "per far caricare i lazy": in headless
# VeryLazy non scatta (vedi trappole), e comunque i config() lazi li copre la CI.
nvim --headless "+lua vim.defer_fn(function() vim.cmd('qa!') end, 200)"
```

> In ambiente fresco l'hook `tools` di mason (non lazy) avvia l'install all'avvio e uscire a 200 ms fa stampare `…exiting while packages are still installing…`: è un artefatto di shutdown, non un errore (in locale, coi tool già presenti, non compare — la CI lo filtra). Ogni **altra** riga è un problema.

Se hai toccato una **feature lazy** e vuoi verificarla subito senza aspettare la CI, non fare lo startup test (non la esercita): **carica il plugin direttamente** e asserisci il comportamento nello stesso run.

```powershell
# es. modifica nel config() di telescope (lazy): carica il plugin e verifica subito
nvim --headless -c "Lazy load telescope.nvim" -c "lua
  assert(require('telescope.config').values.path_display, 'setup non applicato')
  -- ... asserzioni sul comportamento realmente cambiato ...
" -c "qa!"
```

## Verifica attach LSP per linguaggio (la CI non lo fa)

Da fare in locale quando tocchi un server LSP o un parser treesitter. File di prova in `<test-dir>` (lua, py, sh, json, yaml, ts, c, md + progetto cargo in `rust\`; `<test-dir>` è una terminologia sostitutiva, path reale nella memory `path-conventions`).

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

Valgono sia per interpretare l'esito della CI sia per i test locali.

| Trappola | Rimedio |
|---|---|
| `ensure_installed` di mason-lspconfig NON gira headless (guardia `platform.is_headless`) | `nvim --headless "+MasonInstall <pkg>" +qa` — headless è bloccante by design |
| `VeryLazy` non scatta (niente UIEnter) | `+Lazy! load all` (come fa la CI), oppure `vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })` / `require("<modulo>")` |
| Output async di `TSUpdate` mente ("up-to-date" senza parser) | `+TSInstallSync <lingue>` e controllare i `.so`/`.dll` in `stdpath/site/parser\` |
| Exit code 0 anche se un `config()` esplode | grep dello stderr per `Failed to run`; nei check Lua usare `vim.cmd('cquit! 1')` |
| `+Lazy! load all` riavvia gli installer async (mason tools, parser) che `+qa` aborta stampando `Error in command line:` / `Installation was aborted` | rumore **benigno**: non è un errore di config. Chiave i detector solo su `Failed to run` / stacktrace / errori lua (è ciò che fa la CI) |
| Percorsi di test profondi superano MAX_PATH | falsi errori (checkout git falliti, ENOENT cache luac): testare in path corti tipo `$env:TEMP\nvim-ci` |
| `nvim --headless -l script.lua` **non carica init.lua**: niente lazy, niente plugin, nessun autocmd della config (jdtls/LSP non si agganciano mai → attese che vanno sempre in timeout) | non usare `-l` per verificare la config; apri il file come argomento e inietta il codice con `-c "luafile ..."` |

## Installazione da zero simulata (per riprodurre un problema CI)

È **esattamente ciò che fa la CI**: la ricetta serve solo a riprodurre in locale un fallimento del runner (i log delle Actions non sono leggibili senza admin/token). Mirror fedele = **senza `machine.lua`** (git-ignorato, assente sul checkout CI) e con parser/tool assenti.

```powershell
$T = "$env:TEMP\nvim-ci"; Remove-Item -Recurse -Force $T -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$T\data","$T\state","$T\cache","$T\config\nvim" | Out-Null
Copy-Item "$env:LOCALAPPDATA\nvim\init.lua","$env:LOCALAPPDATA\nvim\lazy-lock.json" "$T\config\nvim\"
Copy-Item -Recurse "$env:LOCALAPPDATA\nvim\lua" "$T\config\nvim\lua"
Remove-Item "$T\config\nvim\lua\user\machine.lua" -ErrorAction SilentlyContinue  # mirror CI
$env:XDG_CONFIG_HOME="$T\config"; $env:XDG_DATA_HOME="$T\data"; $env:XDG_STATE_HOME="$T\state"; $env:XDG_CACHE_HOME="$T\cache"
nvim --headless "+Lazy! restore" +qa                      # installa dal lockfile (gate: install)
nvim --headless "+lua vim.defer_fn(function() vim.cmd('qa!') end, 200)"   # gate 1: startup
nvim --headless "+Lazy! load all" "+checkhealth vim.deprecated" "+qa"     # gate 2: load-all
Remove-Item Env:XDG_CONFIG_HOME,Env:XDG_DATA_HOME,Env:XDG_STATE_HOME,Env:XDG_CACHE_HOME
```

## Errori comuni

- **Replicare a mano la CI**: dopo il push, l'esito CI è la fonte di verità — non rifare in locale i due gate, leggi il run.
- Dichiarare "funziona" dopo il solo check di sintassi: l'attach LSP (che la CI non fa) va osservato davvero in locale.
- Testare le mappature which-key contando i keymap prima che il plugin che le registra sia caricato.
- Dimenticare la routine di fine lavoro: quick sanity locale → commit su `windows` → push (→ la CI verifica) → bump del submodule `nvim` nel `<superproject>` se presente (vedi CLAUDE.md).
