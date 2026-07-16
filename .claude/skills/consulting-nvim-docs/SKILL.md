---
name: consulting-nvim-docs
description: Use when implementing or changing anything in this Neovim config and you need the authoritative API of a plugin or of Neovim core — before writing plugin setup, keymaps, or LSP code from memory, especially for plugins with major-version API breaks (which-key v3, nvim-treesitter, mason-lspconfig v2).
---

# Consultare la doc locale di Neovim e dei plugin

La doc installata in locale è la fonte **preferita** rispetto alla memoria: descrive **esattamente la versione pinnata** in `lazy-lock.json`, non l'ultima su GitHub. Consultala **prima** di scrivere setup/keymap/API da memoria — le API a maggior rischio di regressione (which-key v3, nvim-treesitter branch `master`, mason-lspconfig v2) sono proprio quelle che la memoria tende ad allucinare in versione vecchia.

## Dove sta la doc

| Cosa | Percorso |
|---|---|
| Doc di un plugin | `%LOCALAPPDATA%\nvim-data\lazy\<dir-plugin>\doc\*.txt` (help vimdoc, la reference API) |
| README/changelog plugin | stessa dir: `README.md`, `NEWS.md`, `CHANGELOG.md` |
| **Doc core di Neovim** | `C:\Program Files\Neovim\share\nvim\runtime\doc\*.txt` (`lua-guide`, `lsp`, `api`, `options`, `map`, `autocmd`) — **non** sotto `nvim-data` |

La dir del plugin in `lazy\` è l'**ultimo segmento** dello short-name: `folke/which-key.nvim` → `which-key.nvim`. Lo short-name è nel file di config corrispondente (`lua\user\<plugin>.lua`, prima riga della spec).

## Procedura

1. **Feature → plugin**: se non sai quale plugin gestisce la feature, `grep` la config in `lua\user\` per un simbolo/keyword; il `require "..."` / short-name ti dà la dir.
2. **Apri la doc del plugin**: preferisci `doc\<plugin>.txt`. Non leggerlo intero — `grep` per il simbolo dell'API (nome funzione, opzione).
3. **API core Neovim** (`vim.lsp`, `vim.filetype.add`, autocmd, `vim.api.*`): usa i `.txt` in `runtime\doc`, non la memoria.
4. Cita l'API trovata, **poi** scrivi il codice.

```powershell
$lazy = "$env:LOCALAPPDATA\nvim-data\lazy"
# doc di un plugin, cercando un'API specifica
Select-String -Path "$lazy\which-key.nvim\doc\*.txt" -Pattern "wk.add|spec ="
# API core Neovim
Select-String -Path "C:\Program Files\Neovim\share\nvim\runtime\doc\lsp.txt" -Pattern "vim.lsp.config"
```

## Trappole (verificate)

| Trappola | Rimedio |
|---|---|
| Cerchi la doc core sotto `nvim-data` e non c'è | Sta nell'install: `C:\Program Files\Neovim\share\nvim\runtime\doc`. Scoprila via `nvim --headless -c 'echo $VIMRUNTIME' -c q` |
| **Circa metà dei plugin non ha `doc\*.txt`** (`cmp-*`, `harpoon`, `project.nvim`, `vim-helm`, `nvim-web-devicons`...) | Fallback: `README.md` → poi il sorgente `lua\` del plugin. Non concludere "non documentato" senza aver guardato il README |
| Un plugin ha **più `.txt`** e apri quello sbagliato | Es. `nvim-lspconfig` ne ha 3: `lspconfig.txt` (API), `server_configurations.txt` (elenco per-server), `configs.txt`. Lista la dir `doc\` prima di aprire |
| La doc su GitHub/nella tua memoria diverge da quella locale | La locale è la versione **pinnata**: è quella che nvim carica davvero. Vince sempre lei |
| `Select-String` su un `.txt` enorme (`markview` ne ha 22) satura l'output | Restringi il pattern e/o il file; non leggere l'intero help |

## Note

- **context7** (MCP) dà doc aggiornata di molti plugin, ma per il rischio-versione **preferisci il locale**: riflette il lockfile, non l'upstream.
- La doc dei plugin è reference **tecnica** (com'è l'API), non architetturale (come strutturare la config): quelle scelte restano in `CLAUDE.md` e nel codice esistente.

**Riferimenti**: `CLAUDE.md` → "Decisioni prese (non regredire)"; skill `adding-language-support` (usa `lsp\<server>.lua` di nvim-lspconfig per i `filetypes`).
