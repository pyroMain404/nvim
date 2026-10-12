---
name: nvim-language-troubleshooting
description: Use when a language already configured in Neovim misbehaves: map the symptom to the responsible layer and a command that identifies the file or value. Trigger on "il server non si attacca", "non c’è highlight", "make usa il comando sbagliato", or "il linguaggio configurato non funziona". For adding or extending support, use nvim-language-support.
---

# Un linguaggio configurato che non funziona

La diagnosi di un linguaggio già configurato; la procedura per aggiungerne uno è in
`nvim-language-support`.

## Quando qualcosa non funziona

Per un linguaggio già configurato la procedura non serve: serve sapere **quale livello
interrogare**. Ogni riga è "sintomo → livello da sospettare → comando che risponde", e
il criterio comune è che la risposta deve nominare un file o un valore, non lasciare
un'impressione.

| Sintomo | Livello da sospettare | Comando |
|---|---|---|
| Non si carica niente: né ftplugin, né parser, né server | il filetype, che viene prima di tutto | `:=vim.bo.filetype`, `:=vim.filetype.match({ filename = '…' })` |
| Highlight assente o povero | parser non installato | `:InspectTree`, `:Inspect` |
| Un parser non si installa e **nessun messaggio lo dice**: `install()` riporta successo senza scaricare niente | 'nvim-treesitter' lo crede già presente | `get_installed()` conta anche i nomi in `site/queries/`, e lì un symlink **rotto** vale come installato, così `install_lang()` esce con `return true` prima di provarci. Confronta quella cartella con `site/parser/`, togli le voci morte, poi reinstalla con `{ force = true }` |
| Highlight che *era* completo e ora è parziale | query che ha sostituito quella del plugin | la **prima riga** dei file in `after/queries/`: manca `; extends` |
| Il server non si attacca | eseguibile assente, o `root_dir` che non trova la radice | `:checkhealth vim.lsp`, `:=vim.lsp.config['<server>']` |
| Il server si attaccava, e dopo aver riaperto l'applicazione che lo ospita non più | il client è morto con il processo esterno, e nessuno lo richiama | `:edit` sul buffer rifà passare `FileType`, quindi l'attach — `nvim-language-support/references/capabilities.md` "Un runtime esterno che possiede il server" |
| Il server risponde, ma con simboli che in questo progetto non esistono | due istanze dell'applicazione esterna, **una porta sola**: sei attaccato all'altro progetto | la porta in `:=vim.lsp.config['<server>']` e chi la sta ascoltando — `nvim-language-support/references/capabilities.md` "Un runtime esterno che possiede il server" |
| Go to definition apre un **buffer vuoto** il cui nome non è un percorso (`jdt://…`) | la risposta del server è un URI, e nessuno sa leggerlo | serve un `BufReadCmd` sullo schema — `nvim-language-support/references/capabilities.md` "Navigazione della codebase" |
| `method "..." is not supported by any server activated for this buffer` | non è il metodo a mancare: **nessun client è attaccato**, e quasi sempre il server non è nella lista abilitata | `:=vim.lsp.enable` in `plugin/40_plugins.lua`, poi `:checkhealth vim.lsp` |
| Due client dello stesso server sullo stesso progetto | `root_dir` sovrascritto da `after/lsp/` | `:checkhealth vim.lsp` |
| Un'impostazione di `settings` non ha effetto | nome sbagliato, **o una funzione ereditata sovrascritta** | il manuale del server, e `:=vim.lsp.config['<server>']` |
| Un comando o una mapping del server è sparito | `on_attach` ereditato sovrascritto | `:=vim.lsp.config['<server>']` |
| `:make` lascia il quickfix vuoto | `errorformat` che non riconosce l'output | `:verbose setlocal makeprg? errorformat?`, poi `:clist` |
| `:make` prende gli errori ma non i test falliti | `errorformat` incompleto | `:h errorformat`, e la forma esatta di un fallimento |
| `:make` usa il comando sbagliato | un altro `compiler/` prima sul `rtp` | `:verbose setlocal makeprg?` — nomina il file |
| Formatta, ma non come dalla riga di comando | 'conform.nvim' è ricaduto sull'LSP | `:ConformInfo` |
| Lo strumento c'è nel terminale ma non in Neovim | ambiente ereditato all'avvio | `:checkhealth config`, `:=vim.fn.exepath('<tool>')` |
| `gf`, `commentstring` o l'indentazione sbagliati | opzione del ftplugin sovrascritta | `:verbose setlocal commentstring? includeexpr? suffixesadd?` |

`:verbose setlocal <opt>?` è l'unico strumento che nomina **il file responsabile**, ed
è per questo che ricorre qui insieme a `:=vim.lsp.config['<server>']`: quasi ogni
guasto di questo elenco è un livello che ne ha sovrascritto un altro.

## Reference

- `../nvim-language-support/SKILL.md` — la procedura completa per un linguaggio.
