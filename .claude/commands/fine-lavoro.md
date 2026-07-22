---
description: Routine di fine lavoro — test headless, commit+push su windows, bump del submodule nel superproject (se presente)
argument-hint: [messaggio di commit opzionale]
allowed-tools: Bash(git *), Bash(gh *), PowerShell(nvim *), Read
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

Leggi la procedura headless in `.claude/docs/verifica-headless.md` ed eseguila (almeno lo startup test; l'attach LSP per linguaggio se pertinente alle modifiche). Il *lancio dei comandi e la raccolta dell'output* puoi delegarli al subagent Haiku `nvim-collector`; l'**analisi** resta tua. Analizza l'output reale (l'exit code è sempre 0, non fidartene): se ci sono errori di startup, **ABORTISCI** la routine senza committare e riporta gli errori. Prosegui solo se lo startup è pulito.

## Step 2 — Commit + push su `windows`

- `git add -A` (o solo i file pertinenti se ci sono modifiche non correlate — usa il giudizio).
- Messaggio di commit: se `$ARGUMENTS` non è vuoto, usalo. Altrimenti **genera** un messaggio conciso e specifico dal diff (`git diff --cached`), nello stile dei commit recenti del repo. Aggiungi in coda i trailer Co-Authored-By e Claude-Session come da istruzioni di sessione.
- `git commit`, poi `git push origin windows`. Riporta l'esito del push (non dichiararlo fatto se il push non è andato a buon fine).

## Step 2b — Leggi l'esito della CI con `gh` (gate primario)

La CI (`headless.yml`) è il gate autorevole (vedi `verifica-headless.md`); `gh` è autenticato su questa macchina (scope `repo`) e ne legge esito e log **senza aprire il browser**. **Non replicare a mano in locale i due gate che la CI copre** (startup + load-all/deprecated): leggi il run.

> **Due trappole `gh` verificate** (senza queste i comandi falliscono, HTTP 404):
> - **Forza `-R pyroMain404/nvim` su OGNI comando `gh`.** Il repo ha il remote `upstream` = `LunarVim/Launch.nvim`: senza `-R`, `gh` lo auto-aggancia e interroga il repo sbagliato.
> - **Non usare `--workflow headless.yml`.** `--workflow` risolve il file sul *default branch* del repo = `master`, che qui è la config disgiunta e **non contiene** `headless.yml` (→ 404). Filtra i run per SHA, non per workflow.

1. Individua il run innescato dal push, filtrando sullo SHA appena pushato (evita di agganciare un run precedente). Il run può metterci qualche secondo a registrarsi (un breve `sleep`/retry aiuta):
   ```bash
   SHA=$(git rev-parse HEAD)
   gh run list -R pyroMain404/nvim --branch windows --limit 15 \
     --json databaseId,headSha,status,conclusion \
     --jq ".[] | select(.headSha==\"$SHA\") | .databaseId" | head -1
   ```
2. Attendi il completamento e cattura l'esito (esce non-zero se la CI fallisce):
   ```bash
   gh run watch <run-id> -R pyroMain404/nvim --exit-status --compact
   ```
   > La CI usa action su Node 20: `gh` mostra un'annotazione `! Node.js 20 is deprecated … forced to run on Node.js 24` — è un avviso **della piattaforma GitHub**, non della config; se `--exit-status` esce 0 la CI è verde.
3. **Se la CI è rossa**: leggi SOLO gli step falliti e riporta la causa; **non** dichiarare fatto.
   ```bash
   gh run view <run-id> -R pyroMain404/nvim --log-failed
   ```
   Correggi e ricomincia dallo Step 1, oppure riproduci in locale (`verifica-headless.md` § *Installazione da zero simulata*) se serve più contesto dei log.

Prosegui allo Step 3 solo con la CI **verde**.

## Step 3 — Bump del submodule nel `<superproject>`

Esegui **solo se `<superproject>` non è vuoto** (altrimenti questa config non è montata come submodule: salta e dillo). Solo se lo step 2 — o un push preesistente — ha aggiornato `origin/windows`:

- Dentro `<config-dir>` (che è il working tree del submodule): `git pull --ff-only origin windows` per allineare il submodule al commit appena pushato.
- Nel `<superproject>` (`git -C <superproject> ...`): `git add nvim`, `git commit` con messaggio tipo `nvim: bump submodule` (o più descrittivo se utile), poi `git push`.

## Al termine

Riepiloga in poche righe: esito del test locale, hash + messaggio del commit su windows, esito del push, **conclusione della CI letta con `gh`** (verde/rossa + run-id), e stato del bump del submodule (o "superproject assente, saltato"). Chiudi con una riga `result:` autoconclusiva.
