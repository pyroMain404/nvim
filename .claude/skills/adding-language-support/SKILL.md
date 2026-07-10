---
name: adding-language-support
description: Use when adding LSP, treesitter, or tooling support for a new language/framework to this Neovim config — before declaring a new server "done", especially if it depends on Mason, a non-default filetype, or an external toolchain.
---

# Aggiungere supporto per un nuovo linguaggio/tool

## Quando si applica

Aggiunta di un nuovo server LSP (via mason-lspconfig), di un parser treesitter, o di tooling per un linguaggio/framework non ancora coperto da questa config (es. Terraform, Ansible, un nuovo linguaggio di programmazione).

## Procedura

1. **Treesitter**: se il linguaggio non ha già un parser, aggiungilo a `ensure_installed` in `lua/user/treesitter.lua`. Verifica con `+TSInstallSync <lingua>` e controlla il `.so` risultante — l'output async di `TSUpdate` mente (vedi skill `verifying-nvim-config`).
2. **Server LSP**: aggiungi la voce in `lua/user/lsp_servers.lua` (non direttamente nelle liste di `mason.lua`/`lspconfig.lua`, che la importano da lì). Se il pacchetto Mason dipende da un toolchain di sistema (npm, go, cargo...) per l'installazione, imposta `requires = "<eseguibile>"` — vedi CLAUDE.md, sezione "Guardia delle dipendenze esterne", per il perché (senza, `mason-lspconfig` ritenta e fallisce ad ogni avvio).
3. **Impostazioni per-server** (opzionale): `lua/user/lspsettings/<server>.lua` se serve configurare `settings`/`setup`.
4. **Filetype — il punto che si sbaglia più spesso**: apri `nvim-lspconfig`'s `lsp/<server>.lua` (in `nvim-data/lazy/nvim-lspconfig/lsp/`) e guarda il campo `filetypes`. Molti server richiedono un filetype **composto**, diverso da quello che Neovim assegna di default (`yaml.docker-compose`, `yaml.helm-values`, `helm`, `yaml.ansible`...). Se quel filetype non viene mai assegnato, il server non si attacca mai — e non dà nessun errore, semplicemente non fa nulla.
   - Se esiste un plugin per il ftdetect nell'ecosistema (es. `mfussenegger/nvim-ansible`, `towolf/vim-helm`), usalo — ma **non fidarti ciecamente**: verifica con un attach reale su file di esempio, incluse variazioni di naming/percorso non convenzionali (caso reale trovato: un playbook Ansible in radice come `site.yml` non viene riconosciuto, solo `playbook*.yml`/`roles/*/tasks/*.yml`). Su Windows in particolare, script ftdetect scritti con confronti su `/` esplicito possono essere silenziosamente rotti, perché `expand("%:p")` in Vimscript ritorna `\`, mentre i matcher di `vim.filetype.add` ricevono invece il path già normalizzato a `/` — i due meccanismi non si comportano allo stesso modo, verificalo sempre con un test, non per analogia.
   - Se manca o è inaffidabile, scrivi la regola direttamente in `lua/user/autocmds.lua` con `vim.filetype.add` (pattern o funzione) — vedi lì gli esempi già presenti per docker-compose/helm.
5. **Verifica**: segui `verifying-nvim-config` per l'attach LSP headless. Testa **sia** il caso convenzionale **sia** almeno un caso limite di naming/percorso — un "funziona" basato solo sul primo file provato è un'ipotesi, non una verifica.

## Errori comuni

| Sintomo | Causa probabile |
|---|---|
| Server installato ma non si attacca mai, nessun errore | Filetype composto non assegnato — controlla `filetypes` in `lsp/<server>.lua` |
| Il ftdetect di un plugin "non funziona" solo su Windows | Path separator: script che confronta esplicitamente con `/` invece di usare API robuste |
| Un file con naming non convenzionale non viene rilevato | Il ftdetect di terze parti spesso matcha solo path convenzionali; documentalo come limite noto invece di ignorarlo |
| L'LSP sembra non attaccarsi nel test headless | Cold-start: il primo spawn di un binario appena installato può richiedere più tempo del previsto — riprova con un wait più lungo prima di concludere che sia rotto |
| Un server fallisce ad ogni avvio (es. `gopls`) | Manca il toolchain richiesto — usa il campo `requires` in `lsp_servers.lua`, non aggiungere il server "a nudo" |

**Riferimenti**: skill `verifying-nvim-config` (metodologia di test headless), CLAUDE.md → "Guardia delle dipendenze esterne per i server LSP".
