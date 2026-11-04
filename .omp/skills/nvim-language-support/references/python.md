# Python

Esito delle Fasi 1, 2, 4 e 5 per Python, svolte e verificate su questa macchina
(Neovim 0.12, Windows). Ambito: scrivere script ordinari il cui interprete e i cui
import vengono dal Python globale **o** da un virtualenv locale (`.venv/` o `venv/`,
il più vicino sopra il file). REPL e Jupyter sono rimandati: vedi l'ultima sezione.

## 1. Fase 1 — cosa il runtime dà già

`$VIMRUNTIME/ftplugin/python.vim` (Last Change 2024/05/13) imposta già indentazione
PEP 8, `commentstring`, `include`/`includeexpr`/`suffixesadd` (`gf` su un `import`),
`keywordprg=python3 -m pydoc` e `:compiler pytest` per `test_*.py` e `*_test.py` quando
`pytest` è nel PATH. Si tiene tutto e non si ripete niente. A `:make` non si aggiunge
nulla: le diagnostiche arrivano dai server.

`nvim-lspconfig` porta `lsp/basedpyright.lua` (`basedpyright-langserver --stdio`,
`settings.basedpyright.analysis`, un `on_attach` che definisce
`:LspPyrightOrganizeImports` e `:LspPyrightSetPythonPath`, **nessun `before_init`**) e
`lsp/ruff.lua` (`ruff server`, nessuna funzione). conform porta `ruff_format`.

## 2. Fase 2 — scelte

| Asse | Scelta | Perché |
|---|---|---|
| Server | `basedpyright` | le funzioni di pyright più inlay hint e semantic token; `ty` è più giovane |
| Formato e lint | `ruff` | un solo strumento, legge `pyproject.toml`/`ruff.toml` come la riga di comando e la CI |
| Parser | `python` | non è tra quelli inclusi in Neovim |

## 3. Fase 4 — installazione

```bash
mise use -g npm:basedpyright@latest ruff@latest
```

`basedpyright` non è nel registro di `mise`: `npm:basedpyright` dà sia `basedpyright` sia
`basedpyright-langserver`. `ruff` si risolve in `aqua:astral-sh/ruff`. Se il pacchetto npm
non parte, `pipx:basedpyright` dà gli stessi binari.

Nel PATH di questa macchina c'è `WindowsApps\python.exe`, lo stub di Microsoft Store: non
è un interprete, e l'health check lo segnala.

## 4. Fase 5 — cosa implementare

- **Dichiarazione**: una voce `Python` in `lua/config/toolchain.lua`: parser `python`,
  server `basedpyright` e `ruff`, formatter `ruff_format`, e i tre programmi che l'health
  check verifica. Da lì la leggono `plugin/40_plugins.lua` e `health.lua`.
- **Interprete**: `lua/config/python.lua`, `interpreter(start)`. Cerca `.venv` e `venv` con
  un solo `vim.fs.find` verso l'alto, così vince il **più vicino** qualunque sia il nome;
  controlla `Scripts/python.exe` e `bin/python` senza rami per piattaforma; un venv senza
  interprete cade sul `python` globale. `VIRTUAL_ENV` non si legge: una shell attivata ha
  già messo quel `python` per primo nel PATH. Lo usano server, `:Run` e health check, così
  concordano sempre.
- **Server**: `after/lsp/basedpyright.lua`, solo `before_init`, che imposta
  `settings.python.pythonPath`. Le `settings` vanno **modificate sul posto**: il client
  Neovim 0.12 conserva la tabella per riferimento e `workspace/configuration` legge
  `client.settings`; assegnare `config.settings = …` non arriva mai al server. Mai
  `on_attach` (cancellerebbe i due comandi di lspconfig). `root_dir` è nil per uno script
  isolato, quindi si usa il buffer corrente. L'interprete è fissato all'avvio del client:
  un venv creato dopo richiede `:lsp restart basedpyright`. `ruff` non ha file in
  `after/lsp/`: il default di lspconfig è già giusto, e non formatta (lo fa conform).
- **Formato**: `ruff_format` per `python`, dichiarato nella stessa voce.
- **Esecuzione**: `after/ftplugin/python.lua`, `:Run [args]` esegue
  `<interprete> <file> <args>` con cwd la cartella del file. L'interprete si risolve a ogni
  chiamata, quindi un venv creato a sessione aperta è visto subito.

## 5. Il ciclo di lavoro

Apri lo script → il server sceglie venv o globale → `<Leader>lf` formatta → `:Run`.
Se crei il venv dopo aver aperto il file: `:lsp restart basedpyright`.

## 6. Health check

`hook_python()` in `lua/config/health.lua` sostituisce il controllo di `python`:
interprete per la cwd (avvisa se manca o se è l'alias di Store) e la sua versione. Gli
altri programmi e il parser li controlla il ciclo generico di `check_language()`.

## 7. Verifica

Fixture: `$env:TEMP\pyfix\{global,proj}` con `proj\.venv` creato da `uv venv` e `colorama`
installato. Controlli eseguiti in headless:

1. `interpreter()` su `proj/main.py` dà il Python del `.venv`; su `global/main.py` quello
   di `exepath('python')`.
2. Un solo client `basedpyright` e uno `ruff`; `client.settings.python.pythonPath` è
   l'interprete atteso; in `proj` `colorama` si risolve, in `global` no (`could not be
   resolved from source`).
3. `:verbose setlocal includeexpr?` punta a `$VIMRUNTIME/ftplugin/python.vim`.
4. `x=1` → conform → `x = 1`.
5. `:checkhealth config` → sezione `config: Python` tutta OK.

`:Run` apre un terminale, quindi si consegna all'utente: in `proj/main.py` deve stampare il
path del `.venv`, in `global/main.py` quello globale, e dopo `uv venv` a sessione aperta
deve scegliere il nuovo venv senza riavvio.

## 8. Rimandato: REPL e Jupyter

Non implementati di proposito.

- **REPL**: primo passo, un comando locale al buffer in `after/ftplugin/python.lua` che apra
  `:terminal` con `require('config.python').interpreter(file)` (vedi `capabilities.md`,
  "15. Documentazione, REPL, terminale"). Poi decidere se inviare righe o selezioni richiede
  un plugin.
- **Jupyter**: primo passo, la Fase 2 sui plugin per `.ipynb` (conversione tipo jupytext
  contro un plugin con kernel) confrontati con i livelli 1-2 di `AGENTS.md`. Richiede
  `jupyter`/`ipykernel` dentro il venv.
