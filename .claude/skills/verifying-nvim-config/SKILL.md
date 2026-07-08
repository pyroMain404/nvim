---
name: verifying-nvim-config
description: Use when modifying, debugging, or testing this Neovim configuration — after editing plugin specs, LSP servers, treesitter parsers, or keymaps, and before claiming a change works or committing it.
---

# Verifica della config Neovim (headless)

Procedura validata per verificare questa config senza aprire l'UI. File di prova già pronti in `C:\Users\gaeesp\nvim-test\` (lua, py, sh, json, yaml, ts, c, md + progetto cargo in `rust\`).

## Verifica base (dopo ogni modifica)

```powershell
# 1. startup: NON deve stampare nulla
nvim --headless "+lua vim.defer_fn(function() vim.cmd('qa!') end, 5000)"

# 2. health di un plugin toccato
nvim --headless -c "checkhealth which-key" -c "w! $env:TEMP\h.txt" -c "qa!"; Get-Content $env:TEMP\h.txt
```

## Verifica attach LSP per linguaggio

```powershell
nvim --headless C:\Users\gaeesp\nvim-test\test.py "+lua vim.defer_fn(function()
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
- Dimenticare la routine di fine lavoro: commit su `windows` → push → bump del submodule `nvim` in `~\pyro-resources` (vedi CLAUDE.md).
