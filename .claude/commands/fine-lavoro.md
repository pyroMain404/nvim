---
description: Routine di fine lavoro — test headless, commit+push su windows, bump del submodule nel superproject (se presente)
argument-hint: [messaggio di commit opzionale]
allowed-tools: Bash(git *), PowerShell(nvim *), Skill(verifying-nvim-config)
---

Esegui la **routine di fine lavoro** di questa config Neovim, nell'ordine, fermandoti se uno step fallisce.

Messaggio di commit fornito dall'utente (può essere vuoto): `$ARGUMENTS`

## Terminologia dei path (risolvi a runtime, non assumere la struttura)

- **`<config-dir>`** = `git rev-parse --show-toplevel` — il repo di questa config. Sempre presente.
- **`<superproject>`** = `git rev-parse --show-superproject-working-tree` — il repo contenitore che ha questa config come submodule `nvim`. **Output vuoto ⇒ non è un submodule**: in tal caso lo step 3 va saltato, non è un errore.

## Precondizioni

1. Il branch corrente deve essere **`windows`**. Se non lo è, **fermati** e segnalalo: questa routine non deve mai girare su `master` (config disgiunta).
2. Se `git status --porcelain` è vuoto (niente da committare), salta lo step 2 e comunica che non ci sono modifiche; valuta comunque lo step 3 (il submodule nel `<superproject>` potrebbe essere indietro rispetto a `origin/windows`).

## Step 1 — Test headless di startup pulito

Usa la skill **verifying-nvim-config** per lanciare la procedura headless completa. Analizza l'output reale (l'exit code è sempre 0, non fidartene): se ci sono errori di startup, **ABORTISCI** la routine senza committare e riporta gli errori. Prosegui solo se lo startup è pulito.

## Step 2 — Commit + push su `windows`

- `git add -A` (o solo i file pertinenti se ci sono modifiche non correlate — usa il giudizio).
- Messaggio di commit: se `$ARGUMENTS` non è vuoto, usalo. Altrimenti **genera** un messaggio conciso e specifico dal diff (`git diff --cached`), nello stile dei commit recenti del repo. Aggiungi in coda i trailer Co-Authored-By e Claude-Session come da istruzioni di sessione.
- `git commit`, poi `git push origin windows`. Riporta l'esito del push (non dichiararlo fatto se il push non è andato a buon fine).

## Step 3 — Bump del submodule nel `<superproject>`

Esegui **solo se `<superproject>` non è vuoto** (altrimenti questa config non è montata come submodule: salta e dillo). Solo se lo step 2 — o un push preesistente — ha aggiornato `origin/windows`:

- Dentro `<config-dir>` (che è il working tree del submodule): `git pull --ff-only origin windows` per allineare il submodule al commit appena pushato.
- Nel `<superproject>` (`git -C <superproject> ...`): `git add nvim`, `git commit` con messaggio tipo `nvim: bump submodule` (o più descrittivo se utile), poi `git push`.

## Al termine

Riepiloga in poche righe: esito del test, hash + messaggio del commit su windows, esito del push, e stato del bump del submodule (o "superproject assente, saltato"). Chiudi con una riga `result:` autoconclusiva.
