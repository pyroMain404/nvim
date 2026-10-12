---
name: nvim-mise-toolchain
description: Use when installing or declaring Neovim language servers, formatters, linters, or runtimes with mise: global versus project mise.toml, Windows shims and PATH, and registering dependencies in the health check and language reference. Trigger on "installa il server", "configura mise", "aggiungi la toolchain", or "lo strumento non è nel PATH".
---

# Dipendenze di un linguaggio con `mise`

La Fase 4 della procedura di `nvim-language-support`.

## Fase 4 — Installare le dipendenze con `mise`

Un linguaggio porta con sé dei binari: il compilatore, il server, il formatter, il
linter. Installarli a mano funziona una volta sola; il punto è renderli
**dichiarativi e riproducibili**, così che la config sappia da cosa dipende e il
health check possa verificarlo.

Lo strumento adottato è [`mise`](https://mise.jdx.dev) (*mise-en-place*). Il suo
ruolo nella config, il rapporto con 'mason.nvim' e con 'nvim-lspconfig', e la regola
sui canali ufficiali del linguaggio sono in `AGENTS.md`, sezione "External
dependencies". Qui solo la procedura.

### Dichiarare e installare

Server e formatter servono in qualunque directory, quindi vanno nella configurazione
**globale**; runtime e versioni di un progetto nel `mise.toml` **del progetto**:

```bash
mise use -g rust-analyzer@latest     # globale: `mise config ls` dice dove finisce
mise install                         # installa tutto ciò che è dichiarato
```

Quando il registry non conosce un nome, quasi sempre lo copre un backend:
`aqua:owner/repo` per i binari da GitHub release, più `npm:`, `cargo:`, `go:`,
`pipx:`. Verifica con `mise registry | grep <nome>` prima di concludere che un tool
non sia disponibile, e con `mise backends ls` quali backend ha la versione
installata.

**Quando nessun backend a nome lo copre, resta `http:`**, e non è un ripiego: è
la via per gli strumenti che si distribuiscono come archivio da un sito proprio
invece che da una release GitHub — il caso di `jdtls`, che `aqua:` non conosce e
per cui `ubi:` elenca i tag di un repository che non pubblica asset.

```bash
mise use -g "http:<nome>[url=<url dell'archivio>,bin_path=<dir dentro l'archivio>]@<versione>"
```

`mise` scarica, estrae, calcola il checksum e mette `bin_path` sugli shim. La
versione è un'etichetta arbitraria e serve solo a pinnare, quindi va scelta uguale
a quella dell'archivio: un URL con dentro un timestamp resta pinnato, un URL
`...-latest.tar.gz` no, e quello è l'errore da non fare.

### Su Windows, gli shim non sono una preferenza

Le FAQ di `mise` sono esplicite: su Windows nativo il supporto passa **solo dagli
shim**, perché non esiste ancora l'attivazione per PowerShell. La conseguenza da
tenere a mente riguarda l'ambiente, e il confine non è dove sembra: **uno shim porta
l'ambiente del progetto al programma che lancia — le variabili del tool e i blocchi
`[env]` insieme — ma non alla shell** (verificato su questa macchina, contro quanto
lascia intendere la documentazione). Quindi `mvn` invocato dallo shim vede il
`JAVA_HOME` del JDK che il progetto pinna, mentre **tutto ciò che non passa da uno
shim non vede niente**: un IDE, un doppio clic, e soprattutto un server di linguaggio
avviato da Neovim, che Neovim esegue direttamente. Se un server ha bisogno di una
variabile — una `DATABASE_URL`, un flag che legge all'avvio — la sede è il `.nvim.lua`
del progetto (`:h 'exrc'`, già abilitato), non il suo `mise.toml`. Come si sceglie fra
i due, come si scrive quel file e come si prova che è stato letto sta nella skill
`nvim-project-environment`, che tiene anche il registro dei progetti già configurati.

E il `PATH` non se lo mettono da soli: la directory degli shim
(`%LOCALAPPDATA%\mise\shims`) va aggiunta una volta al `PATH` di sistema, perché
`mise` su Windows non lo fa. Finché non è fatto, uno strumento installato con `mise`
è **invisibile** a un Neovim avviato da un'icona o da un launcher — che è il caso
normale qui — e il sintomo è quello di un programma non installato. Fatta quella
volta, gli shim valgono per qualunque modo di avviarlo, ed è il loro vantaggio;
`:checkhealth config` è ciò che dice se è stata fatta.

### Registrare la dipendenza

Una dipendenza nuova va scritta in due posti, o è come se non esistesse: la
**reference del linguaggio** in `nvim-language-support/references/`, con il comando esatto, e il **health
check**, che ne verifica presenza e versione.

## Reference

- `../nvim-language-support/SKILL.md` — la procedura completa per un linguaggio.
