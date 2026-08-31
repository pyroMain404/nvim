# Catalogo degli assi

Tutto ciò che si può attivare per un linguaggio. Per ciascun asse: **cosa dà**,
**dove va**, **come scoprire se è già coperto**, quali **moduli MINI** lo toccano, e
gli helptag da citare nei commenti (verificati su Neovim 0.12.4).

Non è una lista di cose da fare: è una lista da cui scegliere. Attivare tutto per
ogni linguaggio è un errore quanto attivare troppo poco.

## Indice

1. [Riconoscimento del filetype](#1-riconoscimento-del-filetype)
2. [Editing e opzioni di buffer](#2-editing-e-opzioni-di-buffer)
3. [Tree-sitter: albero, highlight, query](#3-tree-sitter-albero-highlight-query)
4. [LSP: la semantica](#4-lsp-la-semantica)
5. [Diagnostica](#5-diagnostica)
6. [Build, test e quickfix](#6-build-test-e-quickfix)
7. [Formattazione](#7-formattazione)
8. [Navigazione della codebase](#8-navigazione-della-codebase)
9. [Completamento e snippet](#9-completamento-e-snippet)
10. [Textobject e manipolazione](#10-textobject-e-manipolazione)
11. [Gestione delle dipendenze del linguaggio](#11-gestione-delle-dipendenze-del-linguaggio)
12. [Debug](#12-debug)
13. [Highlight group](#13-highlight-group)
14. [Toolchain, versioni e ambiente di progetto](#14-toolchain-versioni-e-ambiente-di-progetto)
15. [Documentazione, REPL, terminale](#15-documentazione-repl-terminale)
16. [Health check](#16-health-check)
17. [Cosa Neovim non fa](#17-cosa-neovim-non-fa)

---

## 1. Riconoscimento del filetype

Il presupposto di tutto il resto: senza `filetype` non si carica nessun ftplugin,
non parte tree-sitter, non si attacca nessun server.

- **Dove va**: `ftdetect/<lang>.lua` con `vim.filetype.add()` (`:h ftdetect`,
  `:h vim.filetype.add()`).
- **Già gratis?** `:lua =vim.filetype.match({ filename = 'esempio.xyz' })`. Neovim
  riconosce già diverse centinaia di filetype (`:h vim.filetype`): quasi sempre la
  risposta è sì.
- **Serve davvero per**: file senza estensione riconoscibili dal nome, estensioni
  ambigue condivise tra linguaggi, dialetti che meritano un filetype proprio.

Se un filetype nuovo deve usare un parser tree-sitter esistente con un altro nome,
serve `vim.treesitter.language.register()`, non un parser nuovo.

## 2. Editing e opzioni di buffer

Il grosso di ciò che rende comodo scrivere in un linguaggio, e la parte più spesso
già coperta dal runtime.

- **Dove va**: `after/ftplugin/<ft>.lua`. `vim.bo.<opt>` per le opzioni di buffer,
  `vim.cmd('setlocal ...')` per quelle di finestra.
- **Già gratis?** `:verbose setlocal <opt>?` dentro un buffer del linguaggio: dice
  il file che ha impostato il valore. Se nomina un file sotto `$VIMRUNTIME`, il
  lavoro è fatto (`:h ftplugin-overrule`).

| Gruppo | Opzioni | Nota |
|---|---|---|
| Indentazione | `'shiftwidth'`, `'tabstop'`, `'softtabstop'`, `'expandtab'` | la config usa 2 spazi globali; molti linguaggi ne vogliono 4 |
| Larghezza | `'textwidth'`, `'colorcolumn'` | `'colorcolumn'` è `+1` globale, quindi segue `'textwidth'` da solo |
| Commenti | `'commentstring'`, `'comments'` | 'mini.comment' usa `'commentstring'` e sa personalizzarlo (§10) |
| Parole | `'iskeyword'` | decide `w`, `*`, il completamento e lo spell camelCase |
| Fold | `'foldmethod'`, `'foldexpr'` | vedi §3 (tree-sitter) e §4 (LSP) |
| Testo | `'spell'`, `'wrap'`, `'linebreak'`, `'formatoptions'` | utile per linguaggi di documentazione |
| Navigazione | `'path'`, `'include'`, `'includeexpr'`, `'define'`, `'suffixesadd'` | vedi §8 |
| Esecuzione | `'makeprg'`, `'errorformat'`, `'keywordprg'`, `'formatprg'` | vedi §6, §7, §15 |
| Coppie | `'matchpairs'`, `b:match_words` per `%` esteso (`:h matchit`) | i generici sono già impostati |

**`b:undo_ftplugin`** (`:h undo_ftplugin`): se il file imposta opzioni, dovrebbe
saperle annullare quando il filetype cambia. Per un file che tocca due opzioni è
sovrastruttura; per uno che ne tocca dieci e definisce comandi, è ciò che impedisce
a un buffer di restare in uno stato ibrido dopo un `:setfiletype`.

## 3. Tree-sitter: albero, highlight, query

- **Attivare un linguaggio**: aggiungerlo alla tabella `languages` in
  `plugin/40_plugins.lua`. L'autocomando che chiama `vim.treesitter.start()` sui
  filetype corrispondenti è già lì e non va toccato.
- **Già gratis?**
  `:=vim.tbl_contains(require('nvim-treesitter').get_available(), '<lang>')`,
  `:InspectTree` per l'albero, `:Inspect` per sapere quale capture e quale gruppo
  colorano la parola sotto il cursore.

Query personalizzate in `after/queries/<lang>/<nome>.scm` (`:h treesitter-query`):

| Query | A cosa serve |
|---|---|
| `highlights.scm` | correggere o arricchire i colori |
| `injections.scm` | evidenziare un linguaggio dentro l'altro: SQL in una macro, regex in una stringa, markdown nei doc comment (`:h treesitter-language-injections`) |
| `folds.scm` | fold sui costrutti del linguaggio, con `'foldexpr'` = `v:lua.vim.treesitter.foldexpr()` |
| `locals.scm` | scope e definizioni |
| `textobjects.scm` | **solo** per aggiungere capture che 'nvim-treesitter-textobjects' non fornisce — vedi §10, perché il textobject in sé spesso non richiede una query |

**La riga più importante di una query personalizzata è la prima**: `; extends`
aggiunge alla query esistente invece di sostituirla
(`:h treesitter-query-modeline-extends`). Senza, si perde silenziosamente tutto
l'highlight fornito dal plugin, e non arriva nessun messaggio.

`:EditQuery` apre l'editor di query interattivo per scriverle guardando il risultato.

## 4. LSP: la semantica

Configurazione in `after/lsp/<server>.lua` (ritorna una tabella,
`:h vim.lsp.Config`), nome in `vim.lsp.enable()` (`:h vim.lsp.enable()`).

Campi che si usano davvero: `cmd`, `filetypes`, `root_markers`
(`:h lsp-root_markers`), `settings`, `capabilities`, `on_attach`. Con
'nvim-lspconfig' i primi tre di solito arrivano già dal plugin —
`:=vim.lsp.config['<server>']` mostra cosa si eredita, e il file locale dovrebbe
contenere **solo ciò che differisce**.

**Quello che arriva senza configurare niente** (`:h lsp-defaults`): `K` per l'hover,
`gr`-prefissate, `gO` per i simboli, `'omnifunc'`, `'tagfunc'`, `'formatexpr'`. In
questa config le stesse azioni sono sotto `<Leader>l` perché `gr` è occupato da
'mini.operators'.

**Da abilitare esplicitamente**, dentro `on_attach` o su `LspAttach`
(`:h lsp-attach`), e solo se il server le supporta:

| Funzionalità | Come | Quando vale la pena |
|---|---|---|
| Inlay hint | `vim.lsp.inlay_hint.enable()` | linguaggi con inferenza di tipo forte |
| Semantic token | `vim.lsp.semantic_tokens.enable()` | quando tree-sitter non distingue abbastanza |
| Fold da LSP | `'foldexpr'` = `vim.lsp.foldexpr` (`:h vim.lsp.foldexpr()`) | server con folding range migliori dell'albero |
| Colori nel documento | `vim.lsp.document_color.enable()` | CSS e affini |
| Rinomina accoppiata | `vim.lsp.linked_editing_range.enable()` | HTML e affini |
| Formattazione durante la digitazione | `vim.lsp.on_type_formatting.enable()` | raro, spesso fastidioso |
| Completamento | `vim.lsp.completion.enable()` | **non serve**: 'mini.completion' è già configurato |
| Code lens | `vim.lsp.codelens.run()`, già su `<Leader>ll` | server che espongono "run test", "run main" |

**Navigazione semantica** disponibile: `definition()`, `type_definition()`,
`implementation()`, `declaration()`, `references()`, `document_symbol()`,
`workspace_symbol()`, `incoming_calls()`, `outgoing_calls()`, `typehierarchy()`,
`selection_range()`, `document_highlight()`.

`on_attach` è il posto giusto per ridurre i `triggerCharacters` troppo aggressivi
(come fa 'after/lsp/lua_ls.lua' per 'mini.completion'), abilitare gli inlay hint,
creare mapping buffer-local per comandi propri del server.

## 5. Diagnostica

`vim.diagnostic` è già configurato globalmente in 'plugin/10_options.lua' con una
scelta consapevole. Per un linguaggio non si tocca: `vim.diagnostic.config()` è
globale, e cambiarlo per filetype sarebbe logica per linguaggio in un file condiviso.

Quello che si può fare, e che di solito è la vera esigenza, è **cambiare cosa il
server segnala** — per esempio dirgli di usare un linter più severo al posto del
controllo standard — tramite `settings` in `after/lsp/<server>.lua`.

## 6. Build, test e quickfix

- **`:make`** esegue `'makeprg'` e riempie il quickfix interpretando l'output con
  `'errorformat'` (`:h :make`, `:h quickfix`). Poi `:copen`, `]q` e `[q` ('mini.bracketed').
- **`:compiler <nome>`** imposta entrambe le opzioni da un compiler plugin
  (`:h :compiler`). **Neovim ne spedisce oltre 130** in `$VIMRUNTIME/compiler/`:
  cargo, go, javac, tsc, pytest, mypy, ruff, eslint, maven, dotnet, msbuild, rspec,
  zig, jest… Guardare lì è sempre il primo passo:
  `:echo globpath(&rtp, 'compiler/*.{vim,lua}')`.
- **Se non esiste**: scrivine uno in `compiler/<tool>.lua`
  (`:h write-compiler-plugin`). È preferibile a `'makeprg'` scritto a mano nel
  ftplugin perché è riusabile su più filetype, si documenta da solo e si annulla con
  `:compiler make` (`:h compiler-make`).

> **`:make` non è specifico del C.** Il meccanismo è completamente agnostico: legge
> due opzioni di buffer e nient'altro. Ciò che ha un retaggio C è soltanto il
> **valore di default** di `'errorformat'`, tarato sui compilatori C-like (MSVC su
> Windows, gcc altrove), perché nel 1991 era l'unico caso che contasse. Neovim ha
> anzi ripulito gli altri default storici: `'include'` e `'define'`, che in Vim
> valevano `^\s*#\s*include` e `^\s*#\s*define`, qui sono **vuoti** e vengono
> impostati dai ftplugin dei singoli linguaggi. `:compiler` sostituisce il default e
> il C sparisce dal discorso.

Dettagli che fanno la differenza:

- `'autowrite'` fa salvare il buffer prima di `:make`, evitando di compilare codice
  vecchio.
- `QuickFixCmdPost` permette di aprire la finestra quickfix solo se ci sono risultati.
- Un `errorformat` che cattura anche il **fallimento dei test**, non solo gli errori
  di compilazione, trasforma `:make test` in navigazione dei test falliti.
- **`:make` è sincrono e blocca l'interfaccia.** Per un controllo veloce va benissimo;
  per una build lunga la risposta di questa config è il terminale (`<Leader>tt`).
  L'asincrono richiede `vim.system()` più `vim.fn.setqflist()` (`:h :cexpr`): è codice
  nuovo da mantenere, e va giustificato.

## 7. Formattazione

'conform.nvim' è già installato e configurato con `lsp_format = 'fallback'`: **è il
punto di ingresso della formattazione**, e `<Leader>lf` passa da lì. La regola è
quella già scritta nella sua config — usa il formatter dedicato del linguaggio, e
ricade sull'LSP solo quando non ce n'è uno.

Quindi, per un linguaggio nuovo: **se esiste il formatter ufficiale del linguaggio,
dichiaralo** in `formatters_by_ft` in `plugin/40_plugins.lua`, anche quando il server
saprebbe formattare. È una mappa filetype → strumento, cioè una lista, quindi sta lì.
Il formatter dedicato è più prevedibile del server (stessa versione della riga di
comando e della CI, stesso file di configurazione del progetto, nessuna dipendenza
dallo stato del server), e lasciare la scelta implicita significa formattare in modo
diverso a seconda che il server sia attaccato o no.

`'formatprg'` e `'formatexpr'` restano per far funzionare `gq` con lo strumento del
linguaggio; con LSP attaccato `'formatexpr'` è già impostato da Neovim.

La formattazione automatica al salvataggio non è attiva: attivarla è un cambiamento
di abitudine, da proporre.

## 8. Navigazione della codebase

Due strade che convivono: percorsi (funziona sempre, anche senza server) e semantica.

**Percorsi** — opzioni di buffer, da `after/ftplugin/<ft>.lua`:

| Opzione | Cosa abilita |
|---|---|
| `'path'` | `gf`, `:find` — la radice dei sorgenti o delle dipendenze |
| `'suffixesadd'` | l'estensione da provare quando il nome sotto il cursore non ce l'ha |
| `'include'` | il pattern che riconosce una riga di import, per `[i` e `:checkpath` |
| `'includeexpr'` | come trasformare il nome importato in un percorso |
| `'define'` | il pattern di una definizione, per `[d` |

Verificarle con `:verbose setlocal path? include? includeexpr?` prima di scriverne
una: per i linguaggi con ftplugin nel runtime sono spesso già corrette.

**Semantica** — LSP (§4), più i pickers già mappati: `<Leader>fs` / `<Leader>fS`, e
gli altri di 'mini.extra' (`:h MiniExtra.pickers.lsp()`). `CTRL-]` funziona
attraverso `'tagfunc'`, che il client LSP imposta da solo (`:h vim.lsp.tagfunc()`).

**Radice del progetto**: `MiniMisc.setup_auto_root()` è attivo con i marker di
default (`.git`, `Makefile`). Un marker proprio di un linguaggio — il manifesto di
pacchetto dentro un monorepo — si aggiunge a quella lista
(`:h MiniMisc.setup_auto_root()`). I `root_markers` dell'LSP sono cosa distinta:
valgono per il server, non per la directory corrente.

## 9. Completamento e snippet

- **Completamento**: 'mini.completion' usa l'LSP quando c'è, le parole del buffer
  quando non c'è. Per linguaggio l'unico intervento sensato è ridurre i
  `triggerCharacters` in `on_attach` quando il popup diventa rumoroso.
- **Snippet**: `after/snippets/<lang>.json`
  (`:h MiniSnippets.gen_loader.from_lang()`). 'friendly-snippets' è già installato e
  copre la maggior parte dei linguaggi: guarda cosa arriva già prima di scriverne. Il
  file in `after/` serve a **sovrascrivere o aggiungere**, non a rifare la collezione
  — 'after/snippets/lua.json' mostra anche come rimuovere un prefisso fornito dal
  plugin. Si può anche aggiungere un array di snippet solo per un buffer con
  `vim.b.minisnippets_config`, e mappare un linguaggio su file diversi con
  `lang_patterns`.

## 10. Textobject e manipolazione

Quasi tutto buffer-local, quindi in `after/ftplugin/<ft>.lua`
(`:h mini.nvim-buffer-local-config`). **Molte personalizzazioni per linguaggio si
fanno qui e non richiedono nessun file `.scm`:**

| Variabile | Cosa personalizza |
|---|---|
| `vim.b.miniai_config` | textobject `a`/`i`. `custom_textobjects` accetta pattern Lua, funzioni, e i generatori `gen_spec.pair()`, `gen_spec.argument()`, `gen_spec.function_call()`; `gen_spec.treesitter()` è l'opzione che usa l'albero (`:h MiniAi.gen_spec`) |
| `vim.b.minisurround_config` | delimitatori propri del linguaggio (l'esempio del link markdown in 'after/ftplugin/markdown.lua') |
| `vim.b.minihipatterns_config` | evidenziare pattern che contano in quel linguaggio (`:h MiniHipatterns.config`) |
| `vim.b.minisplitjoin_config` | hook per rispettare virgole finali o parentesi del linguaggio (`:h MiniSplitjoin.config`) |
| `vim.b.minicomment_config` | `options.custom_commentstring` e gli hook `pre`/`post`, per i linguaggi in cui il commento dipende dal contesto |
| `vim.b.minisnippets_config` | snippet aggiuntivi solo per quel buffer (§9) |
| `vim.b.minixxx_disable` | disabilitare un modulo dove dà fastidio, invece di rimuoverlo |

**Quando serve davvero un `.scm`**: solo se il textobject dipende dalla *struttura
sintattica* (funzione, classe, parametro) **e** 'nvim-treesitter-textobjects' non
fornisce già il capture per quel linguaggio. `gen_spec.treesitter()` consuma i
capture esistenti (`@function.outer`, `@class.inner`, …): nella maggior parte dei
casi basta indicarli, non scriverli.

> **Eccezione da ricordare: 'mini.pairs'.** La sua documentazione dice esplicitamente
> che **`vim.b.minipairs_config` non ha effetto**, perché il modulo non ha opzioni di
> runtime: le mapping si creano in `setup()`. Per un linguaggio si usano
> `MiniPairs.map_buf()` e `MiniPairs.unmap_buf()` in `after/ftplugin/`
> (`:h MiniPairs.map_buf()`). Serve nei linguaggi dove un carattere di coppia ha un
> altro significato — l'apice singolo delle lifetime in Rust, per dire.

## 11. Gestione delle dipendenze del linguaggio

Quasi ogni linguaggio ha un manifesto (`Cargo.toml`, `package.json`, `pyproject.toml`)
che si modifica spesso: aggiungere una dipendenza, cercare la versione corrente,
capire quali feature esistono. Fuori dall'editor significa aprire un browser.

- **Neovim non offre niente di specifico** per questo: il manifesto è un file di dati
  come un altro, al più con il suo parser tree-sitter.
- **L'LSP a volte c'è**: alcuni ecosistemi hanno un server per il proprio manifesto,
  e in quel caso l'asse si risolve in §4 senza aggiungere niente.
- **Altrimenti è terreno da plugin dedicato**, attivato sul filetype del manifesto e
  non su tutto il linguaggio. Il riferimento per Rust è
  ['crates.nvim'](https://github.com/saecki/crates.nvim): completamento delle versioni,
  popup con versioni, feature e dipendenze, virtual text con l'ultima disponibile,
  aggiornamento in blocco.
- **Costo/beneficio**: è un asse comodo ma non essenziale, e il plugin resta attivo
  su un file che si apre di rado. Attivalo sull'evento giusto (`BufRead <manifesto>`)
  perché non pesi sull'avvio, e trattalo come una scelta da proporre.

## 12. Debug

Due cose diverse portano lo stesso nome, e vanno tenute separate.

### Debug degli script della config

Built-in e spesso dimenticato (`:h debug-scripts`). Serve quando è la config stessa a
comportarsi in modo strano, ed è il modo più diretto per capire *chi* fa una certa
cosa:

- `:debug <comando>` esegue un comando in modalità debug, fermandosi a ogni riga;
  funziona anche per il codice invocato dagli autocomandi.
- `:breakadd file */qualcosa.lua` mette un breakpoint in uno script; poi `step`,
  `next`, `cont`, `finish`.
- `'verbose'` a un valore alto è l'alternativa meno invasiva, e `:verbose set <opt>?`
  ne è la forma quotidiana — la stessa usata nella Fase 1.
- La documentazione avverte che la modalità debug ha effetti collaterali sul disegno
  dello schermo: va usata per una domanda precisa, non lasciata attiva.

### Debug del programma scritto nel linguaggio

**Neovim non ha niente di built-in**: nessun DAP nel core, nessun modulo MINI. Serve
'nvim-dap' più un debug adapter per il linguaggio (`codelldb`, `debugpy`, …), e per
alcuni linguaggi esiste un plugin che li mette insieme e li configura da sé.

È l'asse più costoso di tutti: due dipendenze esterne, una interfaccia propria, e
mapping nuove da imparare. Va proposto quando serve davvero — molti linguaggi si
debuggano benissimo con i test e la diagnostica — e mai attivato di iniziativa. Se
l'utente lo vuole, il debug adapter si installa con `mise` come ogni altro binario.

## 13. Highlight group

**Quasi sempre non serve fare niente.** I gruppi tree-sitter ricadono da soli:
`@keyword.rust` eredita da `@keyword`, che il color scheme definisce già
(`:h treesitter-highlight-groups`). Lo stesso per i semantic token dell'LSP.

Quando un costrutto è colorato male ci sono due strade e una sola è buona:

- **Buona**: correggere la *query*, in `after/queries/<lang>/highlights.scm` con
  `; extends`, riassegnando la capture a un gruppo esistente. Sta in un file per
  linguaggio, sopravvive al cambio di color scheme, non introduce colori nuovi.
- **Da evitare**: `nvim_set_hl()` sparso, che è globale, va rifatto a ogni
  `ColorScheme` e fissa un colore che il color scheme non conosce.

Se serve un gruppo nuovo, **collegalo** a uno built-in semanticamente vicino invece
di dargli un colore.

## 14. Toolchain, versioni e ambiente di progetto

L'asse che decide se gli altri funzionano davvero, e quello che dà i guasti più
difficili da capire.

- **Installazione dichiarativa con `mise`**: vedi la Fase 4 di `SKILL.md`. Runtime,
  server, formatter e linter si dichiarano in un file e si installano con
  `mise install`.
- **Neovim eredita l'ambiente della shell che lo ha avviato.** Con l'attivazione di
  shell (di `mise` come di qualunque altro version manager) la versione "attiva" è
  quella del momento del lancio: una sessione aperta prima di un cambio di versione
  continua con la vecchia. È la prima cosa da sospettare quando il server usa una
  toolchain diversa da quella che l'utente vede nel terminale. Gli shim di `mise`
  evitano il problema perché stanno su `PATH` sempre.
- **Configurazione per progetto**: `'exrc'` è **già abilitato** in fondo a
  'init.lua'. Un `.nvim.lua` nella radice del progetto viene caricato dopo conferma
  (`:h 'exrc'`), ed è il posto per ciò che vale per quel progetto e non per il
  linguaggio: variabili d'ambiente che il server si aspetta, feature di compilazione
  attive, un `makeprg` diverso. Quel file vive nel progetto, non in questa config.

## 15. Documentazione, REPL, terminale

- **`'keywordprg'`** decide cosa fa `K` senza LSP. Con un server attaccato `K` è già
  l'hover, quindi conta solo per i buffer senza server.
- **Comandi buffer-local** in `after/ftplugin/<ft>.lua` per aprire la documentazione
  o lanciare un REPL. `:command! -buffer` è preferibile a una mapping globale: non
  consuma spazio nel namespace e sparisce con il buffer.
- **Terminale**: `<Leader>tt` e `<Leader>tT` esistono già. Per un REPL specifico basta
  un comando buffer-local che apre `:terminal` con il programma giusto.

## 16. Health check

`AGENTS.md` fissa la forma del file. Qui solo cosa conviene controllare:

```lua
local function check_<lang>()
  health.start('config: <lang>')

  if vim.fn.executable('<tool>') ~= 1 then
    return health.warn('`<tool>` non è disponibile', {
      'Installalo con `mise use -g <tool>@latest`',
      '<cosa smette di funzionare>',
    })
  end

  local out = vim.system({ '<tool>', '--version' }):wait()
  health.ok('<tool>: ' .. vim.trim(out.stdout))
end
```

- **La versione, non solo la presenza.**
- **Quale toolchain è attiva**, se c'è un version manager (§14).
- **Il parser installato**, con
  `vim.api.nvim_get_runtime_file('parser/<lang>.*', false)` — lo stesso controllo che
  'plugin/40_plugins.lua' usa già.
- **Il consiglio come comando eseguibile**: con `mise` è quasi sempre una riga sola.

## 17. Cosa Neovim non fa

Sapere dove finisce il built-in evita di cercare a lungo una funzione che non esiste.

- **Debug del programma**: nessun DAP nel core (§12).
- **Esecuzione asincrona di build e test**: `:make` è sincrono, e non esiste un task
  runner né nel core né in MINI (§6).
- **Linter non-LSP**: o il linter parla LSP, o finisce dentro `:make` con un compiler
  plugin, o serve un plugin esterno.
- **Gestione dei pacchetti dei server**: 'mason.nvim' è citato in
  'plugin/40_plugins.lua' fra le honorable mentions e lasciato disattivato di
  proposito. Il ruolo è coperto da `mise` (§14), che installa strumenti utilizzabili
  anche fuori da Neovim.
- **Gestione delle dipendenze del progetto**: niente per i manifesti (§11).
- **Breadcrumb nella `'winbar'`**: l'opzione esiste (`:h 'winbar'`), il contenuto no.
