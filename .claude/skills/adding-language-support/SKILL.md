---
name: adding-language-support
description: Use when adding LSP, treesitter, or tooling support for a new language/framework to this Neovim config — before declaring a new server "done", especially if it depends on Mason, a non-default filetype, or an external toolchain.
---

# Aggiungere supporto per un nuovo linguaggio/tool

## Quando si applica

Aggiunta di un nuovo server LSP (via mason-lspconfig), di un parser treesitter, o di tooling per un linguaggio/framework non ancora coperto da questa config (es. Terraform, Ansible, un nuovo linguaggio di programmazione).

## Procedura

1. **Treesitter**: se il linguaggio non ha già un parser, aggiungilo a `ensure_installed` in `lua/user/lang/treesitter.lua`. Verifica con `+TSInstallSync <lingua>` e controlla il `.so` risultante — l'output async di `TSUpdate` mente ("up-to-date" senza che il parser esista): fidati del `.so` in `nvim-data\lazy\nvim-treesitter\parser\`, non del messaggio.
2. **Server LSP**: aggiungi la voce in `lua/user/lsp/lsp_servers.lua` (non direttamente nelle liste di `mason.lua`/`lspconfig.lua`, che la importano da lì). Se il pacchetto Mason dipende da un toolchain di sistema (npm, go, cargo...) per l'installazione, imposta `requires = "<eseguibile>"` — vedi CLAUDE.md, sezione "Guardia delle dipendenze esterne", per il perché (senza, `mason-lspconfig` ritenta e fallisce ad ogni avvio). Quando imposti `requires`, dichiara anche `filetypes` (gli stessi del campo `filetypes` di nvim-lspconfig, vedi punto 4): così il warning "prerequisito mancante" resta pigro e appare solo aprendo un file di quel linguaggio, non a ogni avvio. Se il server condivide filetype comuni con altri (es. `typescript`/`html`), aggiungi `root_markers` per ristringere il warning al suo workspace.
3. **Impostazioni per-server** (opzionale): `lua/user/lsp/lspsettings/<server>.lua` se serve configurare `settings`/`setup`.
4. **Filetype — il punto che si sbaglia più spesso**: apri `nvim-lspconfig`'s `lsp/<server>.lua` (in `nvim-data/lazy/nvim-lspconfig/lsp/`) e guarda il campo `filetypes`. Molti server richiedono un filetype **composto**, diverso da quello che Neovim assegna di default (`yaml.docker-compose`, `yaml.helm-values`, `helm`, `yaml.ansible`...). Se quel filetype non viene mai assegnato, il server non si attacca mai — e non dà nessun errore, semplicemente non fa nulla.
   - Se esiste un plugin per il ftdetect nell'ecosistema (es. `mfussenegger/nvim-ansible`, `towolf/vim-helm`), usalo — ma **non fidarti ciecamente**: verifica con un attach reale su file di esempio, incluse variazioni di naming/percorso non convenzionali (caso reale trovato: un playbook Ansible in radice come `site.yml` non viene riconosciuto, solo `playbook*.yml`/`roles/*/tasks/*.yml`). Su Windows in particolare, script ftdetect scritti con confronti su `/` esplicito possono essere silenziosamente rotti, perché `expand("%:p")` in Vimscript ritorna `\`, mentre i matcher di `vim.filetype.add` ricevono invece il path già normalizzato a `/` — i due meccanismi non si comportano allo stesso modo, verificalo sempre con un test, non per analogia.
   - Se manca o è inaffidabile, scrivi la regola direttamente in `lua/user/core/autocmds.lua` con `vim.filetype.add` (pattern o funzione) — vedi lì gli esempi già presenti per docker-compose/helm.
5. **Verifica l'attach** (headless, senza aprire l'UI): un filetype sbagliato non dà errori — il server semplicemente non si attacca — quindi l'attach va osservato davvero, non dedotto. Apri un file del linguaggio e aspetta che un client si agganci. `<test-dir>` è la cartella dei file di prova (risolvi il path a runtime); usa l'estensione giusta.

   ```powershell
   nvim --headless <test-dir>\test.<ext> "+lua vim.defer_fn(function() local ok=vim.wait(30000,function() return #vim.lsp.get_clients({bufnr=0})>0 end,500) local n={} for _,c in ipairs(vim.lsp.get_clients({bufnr=0})) do n[#n+1]=c.name end io.write('lsp: '..table.concat(n,',')..'\n') io.write('ts: '..tostring(vim.treesitter.highlighter.active[1]~=nil)..'\n') if not ok then vim.cmd('cquit! 1') end vim.cmd('qa!') end, 3000)"
   ```

   Deve stampare il nome del server in `lsp:` (e `ts: true`); se resta vuoto o esce con `cquit`, l'attach non avviene. Testa **sia** il caso convenzionale **sia** almeno un caso limite di naming/percorso — un "funziona" basato solo sul primo file provato è un'ipotesi, non una verifica. Primo attach: anche 10-20 s (cold-start di un binario appena installato).

## Errori comuni

| Sintomo | Causa probabile |
|---|---|
| Server installato ma non si attacca mai, nessun errore | Filetype composto non assegnato — controlla `filetypes` in `lsp/<server>.lua` |
| Il ftdetect di un plugin "non funziona" solo su Windows | Path separator: script che confronta esplicitamente con `/` invece di usare API robuste |
| Un file con naming non convenzionale non viene rilevato | Il ftdetect di terze parti spesso matcha solo path convenzionali; documentalo come limite noto invece di ignorarlo |
| L'LSP sembra non attaccarsi nel test headless | Cold-start: il primo spawn di un binario appena installato può richiedere più tempo del previsto — riprova con un wait più lungo prima di concludere che sia rotto |
| Un server fallisce ad ogni avvio (es. `gopls`) | Manca il toolchain richiesto — usa il campo `requires` in `lsp_servers.lua`, non aggiungere il server "a nudo" |

**Riferimenti**: CLAUDE.md → "Guardia delle dipendenze esterne per i server LSP".
