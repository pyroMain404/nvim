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

## Interrogare la config: quale strumento per quale domanda

Vale per tutto il catalogo, e la scelta sbagliata fa perdere tempo perché risponde a
un'altra domanda:

| Domanda | Strumento |
|---|---|
| Quanto vale questa opzione, adesso? | `:=vim.bo.<opt>` / `:=vim.wo.<opt>` — il valore, senza rumore |
| **Chi** ha impostato questo valore? | `:verbose setlocal <opt>?` — è l'unico che nomina il file responsabile |
| Quali file del runtime esistono per questo filetype? | `vim.fn.globpath(vim.o.rtp, 'ftplugin/<ft>.{vim,lua}')` |
| Quali compiler / filetype / helptag esistono? | `vim.fn.getcompletion('', 'compiler')` — legge la stessa lista del completamento a riga di comando |
| Quali script sono stati eseguiti in questa sessione? | `vim.fn.getscriptinfo()` |
| Cosa conosce il registry dei filetype? | `vim.filetype.inspect()` |

`:verbose` e `vim.bo` non sono alternative: il primo dice **da dove viene** un
valore, il secondo **qual è**. Nella Fase 1 servono entrambi, e `:verbose` è quello
che chiude la domanda "devo scriverlo io o c'è già".

> **Sulla presunta lentezza di `globpath()`**: misurata su questa macchina, 50
> chiamate a `globpath(&rtp, 'ftplugin/lua.{vim,lua}')` costano **6,2 ms**, contro
> 23,8 ms di `nvim_get_runtime_file(..., true)` e 315,8 ms di
> `getcompletion('', 'compiler')`. `globpath` è la più rapida delle tre, e comunque
> si parla di frazioni di millisecondo per comandi che si lanciano a mano. La
> questione diventa reale solo se una di queste chiamate finisce in un percorso caldo
> — dentro `after/ftplugin/`, che gira a ogni apertura di buffer, o in un
> autocomando frequente. Lì la regola è non interrogare il filesystem affatto.

---

## 1. Riconoscimento del filetype

Il presupposto di tutto il resto: senza `filetype` non si carica nessun ftplugin,
non parte tree-sitter, non si attacca nessun server.

- **Dove va**: `ftdetect/<lang>.lua` con `vim.filetype.add()` (`:h ftdetect`,
  `:h vim.filetype.add()`), che accetta tre tabelle — `extension`, `filename`,
  `pattern` — dalla più specifica alla più generica.
- **Già gratis?** Neovim riconosce già diverse centinaia di filetype
  (`:h vim.filetype`): quasi sempre la risposta è sì.

**`vim.filetype.match()` fa più di quanto sembri.** Ha tre strategie mutuamente
esclusive nel loro nucleo, e vale la pena conoscerle perché rispondono a domande
diverse:

```lua
vim.filetype.match({ buf = 42 })                      -- la più accurata: nome + contenuto
vim.filetype.match({ buf = 42, filename = 'foo.c' })  -- come sopra, forzando il nome
vim.filetype.match({ filename = 'main.lua' })         -- senza buffer: solo il nome
vim.filetype.match({ contents = { '#!/usr/bin/env bash' } }) -- solo il contenuto
```

Il file **non deve esistere sul disco**, il che la rende adatta a provare una regola
prima di scriverla. Restituisce **tre valori**, non uno:

1. il filetype riconosciuto, se c'è;
2. una funzione `fun(buf)` da chiamare per applicare gli effetti collaterali che quel
   filetype comporta (variabili di buffer che il rilevamento imposta);
3. un booleano che segnala che il match è arrivato per **fallback generico** (`.conf`),
   caso in cui il filetype andrebbe impostato con `:setf FALLBACK`.

Ignorare il secondo e il terzo valore è la causa più comune di un rilevamento che
"funziona ma non del tutto".

Non esiste una funzione Vimscript equivalente: il rilevamento in Neovim è
implementato in Lua e `vim.filetype` è l'interfaccia. `:=` è il modo più corto per
interrogarla (`:h :=`).

**Quando non vale la pena aggiungere una regola.** Per un formato di nicchia, che si
incontra una volta ogni tanto o in un solo file, la risposta proporzionata è la
**modeline** (`:h modeline`): una riga di commento nel file stesso, del tipo
`# vim: ft=dosini`, che imposta il filetype solo lì. Non tocca la config, segue il
file ovunque, e non impegna nessuno a mantenerla. Conviene anche quando il nome del
file è troppo ambiguo per una regola sensata: meglio una modeline nei tre file che
contano che un `pattern` che sbaglia altrove. Il limite da conoscere: le modeline
sono lette solo entro `'modelines'` righe dall'inizio o dalla fine del file.

Se un filetype nuovo deve usare un parser tree-sitter esistente con un altro nome,
serve `vim.treesitter.language.register()`, non un parser nuovo.

## 2. Editing e opzioni di buffer

Il grosso di ciò che rende comodo scrivere in un linguaggio, e la parte più spesso
già coperta dal runtime.

- **Dove va**: `after/ftplugin/<ft>.lua`.
- **Come si scrive**: `vim.bo.<opt>` per le opzioni di buffer, `vim.wo.<opt>` per
  quelle di finestra. Sono l'interfaccia diretta, dicono da sé su cosa agiscono, e
  non passano dal parser dei comandi. `vim.cmd(...)` è l'ultima spiaggia — va usato
  solo per ciò che *è* un comando e non ha un equivalente in `vim.o`/`vim.bo`/`vim.wo`
  o nell'API (`:compiler`, `:packadd`), e in una config una sua comparsa è quasi
  sempre il segnale che esiste una strada migliore.
- **Perché `:setlocal` confonde**: non ha un target proprio, imposta *localmente*
  qualunque cosa l'opzione sia — buffer per `'shiftwidth'`, finestra per
  `'foldmethod'`, e per le `global-local` la parte locale. È comodo a riga di comando
  proprio perché non obbliga a saperlo; in un file di config quella stessa proprietà
  nasconde l'informazione che serve a chi legge.
- **Già gratis?** `:verbose setlocal <opt>?` dentro un buffer del linguaggio: se
  nomina un file sotto `$VIMRUNTIME`, il lavoro è fatto (`:h ftplugin-overrule`).

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
| Coppie | `'matchpairs'`, e `b:match_words` per `%` esteso | vedi la nota su matchit |

> **matchit è un pack opzionale, non un built-in attivo.** Vive in
> `$VIMRUNTIME/pack/dist/opt/matchit` e si carica con `:packadd matchit`; finché non
> lo si fa, `%` resta quello base e **`:h matchit` non risolve**, perché anche la sua
> documentazione arriva con il pack. Diversi ftplugin del runtime impostano comunque
> `b:match_words` e `b:match_skip` — innocui se il plugin non c'è, ma inerti. Se il
> salto tra `if`/`end` serve davvero, la decisione è abilitare matchit una volta per
> tutte, non impostare le variabili per linguaggio.

**`b:undo_ftplugin`** (`:h undo_ftplugin`): se il file imposta opzioni, dovrebbe
saperle annullare quando il filetype cambia. Per un file che tocca due opzioni è
sovrastruttura; per uno che ne tocca dieci e definisce comandi, è ciò che impedisce
a un buffer di restare in uno stato ibrido dopo un `:setfiletype`.

## 3. Tree-sitter: albero, highlight, query

- **Attivare un linguaggio**: aggiungerlo alla tabella `languages` in
  `plugin/40_plugins.lua`. L'autocomando che chiama `vim.treesitter.start()` sui
  filetype corrispondenti è già lì e non va toccato.
- **Perché l'installazione riesca serve la CLI `tree-sitter`**: 'nvim-treesitter'
  scarica la grammatica e poi la **compila invocando quel programma**. Senza,
  l'installazione fallisce con `ENOENT ... 'tree-sitter'` e il linguaggio resta
  semplicemente non installato — il file si apre lo stesso, colorato dal vecchio
  `syntax/`, che è il motivo per cui il guasto passa inosservato. La CLI è dichiarata
  in `mise` e verificata da `:checkhealth config`.
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
| `textobjects.scm` | **solo** per aggiungere capture che 'nvim-treesitter-textobjects' non fornisce — vedi §10 |

**La riga più importante di una query personalizzata è la prima**: `; extends`
aggiunge alla query esistente invece di sostituirla
(`:h treesitter-query-modeline-extends`). Senza, si perde silenziosamente tutto
l'highlight fornito dal plugin, e non arriva nessun messaggio.

`:EditQuery` apre l'editor di query interattivo per scriverle guardando il risultato.

## 4. LSP: la semantica

Configurazione in `after/lsp/<server>.lua` (ritorna una tabella,
`:h vim.lsp.Config`), nome dentro la chiamata `vim.lsp.enable({ ... })` che si trova
nella sezione `-- Language servers ===` di `plugin/40_plugins.lua`, dove è già
predisposta e commentata.

Campi che si usano davvero: `cmd`, `filetypes`, `root_markers`
(`:h lsp-root_markers`), `settings`, `capabilities`, `on_attach`. Con
'nvim-lspconfig' i primi tre di solito arrivano già dal plugin —
`:=vim.lsp.config['<server>']` mostra cosa si eredita, e il file locale dovrebbe
contenere **solo ciò che differisce**.

**Differire non è però sempre aggiungere.** I livelli si fondono con
`vim.tbl_deep_extend('force')`: una tabella si unisce in profondità, una funzione
(`on_attach`, `before_init`, `root_dir`) **sostituisce** quella ereditata e ne
cancella gli effetti senza dirlo. La regola completa, per tutti gli assi, è in
`SKILL.md`, sezione "I livelli si sovrappongono".

### Cosa arriva senza configurare niente

`:h lsp-defaults` è la lista autorevole. In sintesi: `K` per l'hover (a meno che
`'keywordprg'` sia personalizzato), le `gr`-prefissate, `gO` per l'outline dei
simboli, `'omnifunc'`, `'tagfunc'` — che è ciò che fa funzionare `CTRL-]`, `:tjump`
e `CTRL-W ]` sui simboli — e `'formatexpr'`, che fa formattare `gq` tramite il
server. In questa config le stesse azioni sono anche sotto `<Leader>l` perché `gr` è
occupato da 'mini.operators'.

**Anche la diagnostica e i colori del documento sono attivi di default.** Quest'ultimo
punto è facile da fraintendere: `vim.lsp.document_color` non riguarda le keyword del
linguaggio, ma i **riferimenti a colori dentro il testo** — un `#ff0000` o un
`rgb(...)` che il server segnala, che Neovim evidenzia con il colore corrispondente.
Ha senso nei linguaggi dove i colori si scrivono a mano (CSS e affini) ed è per
questo che l'esempio è quello; altrove il server semplicemente non segnala niente.
Poiché è già attivo, l'unica azione possibile è **disattivarlo**, su `LspAttach`.

### Cosa va abilitato esplicitamente

Solo se il server la supporta, dentro `on_attach` o su `LspAttach` (`:h lsp-attach`):

| Funzionalità | Come | Quando vale la pena |
|---|---|---|
| Inlay hint | `vim.lsp.inlay_hint.enable()` | linguaggi con inferenza di tipo forte |
| Semantic token | `vim.lsp.semantic_tokens.enable()` | quando tree-sitter non distingue abbastanza |
| Fold da LSP | `'foldexpr'` = `vim.lsp.foldexpr` (`:h vim.lsp.foldexpr()`) | server con folding range migliori dell'albero |
| Rinomina accoppiata | `vim.lsp.linked_editing_range.enable()` | HTML e affini: rinominare un tag di apertura aggiorna la chiusura |
| Formattazione durante la digitazione | `vim.lsp.on_type_formatting.enable()` | raro, spesso fastidioso |
| Completamento inline | `vim.lsp.inline_completion.enable()` | **solo con un server che lo offre**, vedi sotto |
| Code lens | `vim.lsp.codelens.enable()` | sempre: senza, Neovim non li chiede mai — vedi sotto |

**`inline_completion` non ha niente a che vedere con 'mini.completion'.** Sono due
cose diverse che il nome avvicina: 'mini.completion' mostra un **menù di candidati**
per la parola che stai scrivendo, alimentato dal server o dalle parole del buffer;
`vim.lsp.inline_completion` mostra **testo suggerito in sovraimpressione**, anche
lungo intere funzioni, ed esiste per i server di tipo assistente — l'esempio nella
documentazione di Neovim è Copilot (`:h lsp-copilot`). Nessun server di linguaggio
tradizionale la implementa, quindi per un linguaggio normale la voce non si pone.

**Code lens** (`<Leader>ll`, `vim.lsp.codelens.run()`) merita una parola perché è
l'unica di questa lista che non si limita a mostrare informazione. Un code lens è
un'**azione che il server annuncia in un punto preciso del codice**: "esegui questo
test", "esegui questo main", "mostra le implementazioni di questa interfaccia".
Chiamarla richiede tre condizioni insieme, e la prima è quella che si dimentica:
**Neovim non chiede i lens finché non glielo si dice** (`vim.lsp.codelens.enable()`,
già chiamato una volta per tutti i server in 'plugin/40_plugins.lua'); poi che il
server ne produca; e infine che il cursore sia sulla riga a cui uno è agganciato. Con
la prima mancante la mapping resta silenziosa ovunque, il che si confonde facilmente
con la terza. Attenzione a `vim.lsp.codelens.refresh()` dentro un autocomando, che
quasi tutte le ricette mostrano ancora: è la forma precedente, deprecata in 0.12 e
rimossa in 0.13, mentre `enable()` fa da sé la richiesta, il debounce e il ridisegno.
Vale la pena ricordarsene per i server che li usano molto (quelli con test runner
integrato), dove sostituiscono un giro nel terminale.

C'è poi una quarta condizione, che si manifesta solo dopo aver premuto: **un lens
può risolversi in un comando che tocca al client eseguire**, non al server. Quando
il messaggio è *"Language server `X` does not support command `Y`"*, quel `Y` va
registrato in `vim.lsp.commands` — un registro globale, quindi la sede è
`plugin/40_plugins.lua` e non `after/lsp/`, dove una funzione cancellerebbe quelle
ereditate. Succede quando la config di 'nvim-lspconfig' dichiara al server, nelle
`capabilities`, dei comandi che poi non registra: per `rust_analyzer` è il caso di
`showReferences` e `debugSingle`.

### Navigazione e altre funzioni

`vim.lsp.buf` offre più di quanto la config mappi: oltre a `definition()`,
`type_definition()`, `implementation()`, `declaration()`, `references()`,
`document_symbol()`, `workspace_symbol()`, ci sono `incoming_calls()` e
`outgoing_calls()` per la gerarchia delle chiamate, `typehierarchy()` per quella dei
tipi, `selection_range()` per allargare la selezione secondo la sintassi che il
server conosce, `document_highlight()` per evidenziare le altre occorrenze del
simbolo sotto il cursore, e `workspace_diagnostics()` per farsi dare dal server i
problemi dell'intero progetto invece che dei soli file aperti. Sono candidate
naturali per una mapping buffer-local quando un linguaggio le rende utili.

> **`vim.lsp.buf_detach_client()` non va chiamato al cambio di filetype: lo fa già il
> core.** `vim.lsp.enable()` installa un autocomando `FileType` che a ogni cambio
> stacca i client che non si applicano più al buffer, ne avvia di nuovi se ora si
> applicano, e per un passaggio tra due filetype gestiti dallo stesso server manda al
> server `didClose` seguito da `didOpen` con il nuovo language id. Chiamare
> `buf_detach_client()` a mano ha senso solo per client avviati con `vim.lsp.start()`
> fuori da quel meccanismo — che qui non è il caso.

`on_attach` è il posto giusto per ridurre i `triggerCharacters` troppo aggressivi
(come fa 'after/lsp/lua_ls.lua' per 'mini.completion'), abilitare gli inlay hint, e
creare mapping buffer-local per comandi propri del server — **a una condizione**: che
`:=vim.lsp.config['<server>']` non ne mostri già uno. Se il default di
'nvim-lspconfig' definisce `on_attach`, scriverne un altro qui lo cancella; la forma
che si aggiunge invece di sostituire è un autocomando `LspAttach` in
`after/ftplugin/<ft>.lua`.

### Più server sullo stesso filetype

`vim.lsp.enable()` accetta più nomi, e niente impedisce a due server di attaccarsi
allo stesso buffer: è la norma dove l'ecosistema separa il type checker dal linter
(Python con `ruff` di fianco a un type checker, TypeScript con `eslint` di fianco a
`ts_ls`). Neovim li tratta da pari — l'hover e le code action interrogano tutti i
client attaccati e uniscono le risposte — quindi funziona, ma tre cose vanno decise
invece che subite:

- **Chi formatta.** Due server che dichiarano `documentFormattingProvider` rendono
  `gq` e il fallback di 'conform.nvim' non deterministici. Si sceglie uno e agli altri
  si toglie la capability su `LspAttach`
  (`client.server_capabilities.documentFormattingProvider = false`).
- **La diagnostica doppia.** Due strumenti che applicano la stessa regola segnalano
  due volte lo stesso problema. Si spegne la regola nella configurazione dello
  strumento, non in Neovim: `vim.diagnostic` è globale (§5).
- **Chi ha risposto.** `:checkhealth vim.lsp` elenca i client attaccati al buffer, ed è
  il modo per sapere quale dei due ha prodotto una risposta strana.

Due client dello **stesso** server sullo stesso progetto non sono invece mai voluti:
vuol dire che `root_dir` ha risposto due volte in modo diverso.

## 5. Diagnostica

`vim.diagnostic` è già configurato globalmente in 'plugin/10_options.lua' con una
scelta consapevole. Per un linguaggio non si tocca: `vim.diagnostic.config()` è
globale, e cambiarlo per filetype sarebbe logica per linguaggio in un file condiviso.

Quello che si può fare, e che di solito è la vera esigenza, è **cambiare cosa il
server segnala** — per esempio dirgli di usare un linter più severo al posto del
controllo standard — tramite `settings` in `after/lsp/<server>.lua`.

## 6. Build, test e quickfix

L'asse che chiude il ciclo *edit → compile → fix* senza uscire dall'editor.

| Cosa | Dove si imposta | Quando serve |
|---|---|---|
| `'makeprg'` ed `'errorformat'` | un compiler plugin, attivato con `:compiler <tool>` | sempre, appena esiste un comando di build o test |
| `:compiler` per il filetype | `after/ftplugin/<ft>.lua` | se il ftplugin del runtime non lo sceglie già da sé |
| Un compiler plugin nuovo | `compiler/<tool>.lua` (`:h write-compiler-plugin`) | il runtime non ne ha uno per quel tool |
| Apertura automatica del quickfix | `QuickFixCmdPost` | per aprire la finestra solo quando ci sono risultati |
| Salvataggio prima della build | `'autowrite'` | per non compilare mai una versione vecchia del buffer |
| Navigazione dei risultati | già fatto: `]q` / `[q` di 'mini.bracketed', `'switchbuf'` a `usetab` | — |

**Neovim spedisce oltre 130 compiler plugin** in `$VIMRUNTIME/compiler/`: cargo, go,
javac, tsc, pytest, mypy, ruff, eslint, maven, dotnet, msbuild, rspec, zig, jest…
`vim.fn.getcompletion('', 'compiler')` è il modo più diretto per vedere la lista.
Guardare lì è sempre il primo passo.

Un `errorformat` che cattura anche il **fallimento dei test**, non solo gli errori di
compilazione, trasforma `:make test` in navigazione dei test falliti — ed è la
differenza tra un compiler plugin utile e uno che serve solo a compilare.

### Quickfix e location list non sono la stessa lista

È una distinzione poco sfruttata e utile proprio qui: la **quickfix è una sola per
sessione**, la **location list è una per finestra**, e ogni finestra ne conserva uno
storico navigabile con `:lolder` e `:lnewer` (come `:colder` / `:cnewer` per la
quickfix). Quasi ogni comando quickfix ha il gemello con la `l`: `:lmake`, `:lgrep`,
`:lvimgrep`, `:lopen`, e `]l` / `[l` sono già mappati da 'mini.bracketed'.

Da qui nascono divisioni del lavoro che con una lista sola non sono possibili:

- **la quickfix per il progetto, la location list per il file**: `:make` per la build
  intera, `:lmake %` (o `:lgrep` nel file corrente) per la verifica locale, senza che
  la seconda distrugga i risultati della prima;
- **una lista per finestra**: due finestre affiancate, ciascuna con i risultati che
  la riguardano — comodo quando si confrontano due implementazioni;
- **lo storico come "pila di ricerche"**: `:lolder` torna alla ricerca precedente
  senza rifarla, il che rende economico esplorare una pista e tornare indietro;
- `gO` costruisce il proprio outline proprio in una location list, il che la rende il
  posto naturale anche per indici e sommari.

### Su `:make` sincrono

`:make` blocca l'interfaccia finché il comando non finisce, ed è la sua unica
scomodità. Non è però un motivo per rinunciarci: è integrato con quickfix,
`'errorformat'`, `'autowrite'`, `QuickFixCmdPost` e le mapping di navigazione, e
riprodurre quella catena a mano costa molto più di quanto si guadagni. Per un
`check` incrementale l'attesa è impercettibile; per una build lunga il terminale
(`<Leader>tt`) resta l'alternativa, ma è una scelta di comodo, non la strada maestra.
Se l'attesa diventa un problema, la direzione giusta è rendere `:make` asincrono
(`vim.system()` più `vim.fn.setqflist()`, `:h :cexpr`) mantenendo tutto il resto —
non abbandonarlo.

## 7. Formattazione

'conform.nvim' è già installato e configurato con `lsp_format = 'fallback'`: **è il
punto di ingresso della formattazione**, e `<Leader>lf` passa da lì. La regola è già
scritta nella sua config — usa il formatter dedicato del linguaggio, e ricade
sull'LSP solo quando non ce n'è uno.

Quindi, per un linguaggio nuovo: **se esiste il formatter ufficiale, dichiaralo** in
`formatters_by_ft` in `plugin/40_plugins.lua`, anche quando il server saprebbe
formattare. È una mappa filetype → strumento, cioè una lista, quindi sta lì. Il
formatter dedicato è più prevedibile del server: stessa versione della riga di
comando e della CI, stesso file di configurazione del progetto, nessuna dipendenza
dallo stato del server.

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

> **`[i` e `[d` in questa config non fanno più include-search e define-search.**
> Verificato a config caricata: `[i` è `MiniIndentscope.operator('top')` e `[d` è la
> diagnostica. Su `[i` si accavallano addirittura tre livelli — il built-in, il target
> `indent` di 'mini.bracketed' e 'mini.indentscope' — e vince l'ultimo che fa
> `setup()`, cioè indentscope. La documentazione di 'mini.bracketed' prevede il caso e
> suggerisce `indent = { suffix = '' }` proprio "in favore di 'mini.indentscope'":
> applicarlo non cambierebbe il comportamento ma toglierebbe di mezzo una mapping
> mascherata. Su `[d` la sovrascrittura è arrivata prima ancora, da Neovim stesso, che
> lo assegna alla diagnostica in `lsp-defaults`. Conclusione pratica: impostare
> `'include'` e `'define'` per un linguaggio ha senso per `:checkpath` e `[I`, ma non
> aspettarsi che `[i` e `[d` li usino — la navigazione per import passa da `gf`
> (`'includeexpr'`), quella per definizione dall'LSP.

**Semantica** — LSP (§4), più i pickers già mappati: `<Leader>fs` / `<Leader>fS`, e
gli altri di 'mini.extra' (`:h MiniExtra.pickers.lsp()`). Per i buffer senza server,
`:h MiniExtra.pickers.treesitter()` naviga i nodi dell'albero ed è il sostituto più
diretto di un outline.

**Radice del progetto**: `MiniMisc.setup_auto_root()` è attivo con i marker di
default (`.git`, `Makefile`), e li cerca risalendo, fermandosi al primo. Un marker
proprio di un linguaggio — il manifesto di pacchetto dentro un monorepo — si aggiunge
a quella lista (`:h MiniMisc.setup_auto_root()`). I `root_markers` dell'LSP sono cosa
distinta: valgono per il server, non per la directory corrente.

> **Il caso di questa config.** Aprendo un file in `configs/nvim-0.12` il primo marker
> che si incontra risalendo è il `.git` della radice del repo, quindi la directory
> corrente diventa l'intero fork e ricerche e picker vedono anche `nvim-0.10`,
> `nvim-0.11` e `nvim-0.13` — che per policy non si toccano. Il marker che separa le
> config senza inventare un file nuovo è **`nvim-pack-lock.json`**: esiste in
> `nvim-0.12` (e nelle versioni che usano `vim.pack`), non alla radice del repo, e
> non compare in nessun altro tipo di progetto. Messo *prima* di `.git` nella lista,
> fa fermare la risalita sulla config giusta. `init.lua` non è utilizzabile, come
> osservato: ne esiste uno in ogni config e in molti plugin.

## 9. Completamento e snippet

- **Completamento**: 'mini.completion' usa l'LSP quando c'è, le parole del buffer
  quando non c'è. Per linguaggio l'unico intervento sensato è ridurre i
  `triggerCharacters` in `on_attach` — o su `LspAttach`, vedi §4 — quando il popup
  diventa rumoroso.
- **Snippet**: `after/snippets/<lang>.json`
  (`:h MiniSnippets.gen_loader.from_lang()`). 'friendly-snippets' è già installato e
  copre la maggior parte dei linguaggi: guarda cosa arriva già prima di scriverne. Il
  file in `after/` serve a **sovrascrivere o aggiungere**, non a rifare la collezione
  — 'after/snippets/lua.json' mostra anche come rimuovere un prefisso fornito dal
  plugin. Si può anche aggiungere un array di snippet solo per un buffer con
  `vim.b.minisnippets_config`, e mappare un linguaggio su file diversi con
  `lang_patterns`.

> **`MiniSnippets.start_lsp_server()` è commentato** in `plugin/30_mini.lua`.
> Attivarlo espone gli snippet come un vero server LSP, così i candidati arrivano
> dallo stesso canale di quelli del linguaggio invece che da un percorso separato:
> compaiono nello stesso menù di 'mini.completion', ordinati insieme. Per un
> linguaggio con molti snippet propri è la differenza tra averli sotto mano e doverli
> ricordare. È un cambiamento che si vede a schermo, quindi si propone.

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
  popup con versioni, feature e dipendenze, virtual text con l'ultima disponibile.
- **Costo/beneficio**: comodo ma non essenziale, e il plugin resta attivo su un file
  che si apre di rado. Attivalo sull'evento giusto (`BufRead <manifesto>`) perché non
  pesi sull'avvio, e trattalo come una scelta da proporre.

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
  ne è la forma quotidiana.
- La documentazione avverte che la modalità debug ha effetti collaterali sul disegno
  dello schermo: va usata per una domanda precisa, non lasciata attiva.

### Debug del programma scritto nel linguaggio

Il runtime **una cosa ce l'ha**: `Termdebug` (`:h terminal-debug`), un pack opzionale
che si carica con `:packadd termdebug`. Non è un client DAP — è un frontend per
**gdb**, con finestra del debugger, finestra di I/O del programma, segni di
breakpoint nel sorgente e cursore che segue l'esecuzione. Il linguaggio quindi non
c'entra: **funziona con qualunque cosa gdb sappia debuggare**, che è molto più del
C — C++, Rust (anche via `rust-gdb`), Go, Fortran, Ada, Zig. Il limite è l'altra
metà: dove l'ecosistema usa un adapter proprio e non gdb (Python, Node, Java, .NET),
Termdebug non arriva.

Vale quindi la pena provarlo **prima** di installare 'nvim-dap' quando il linguaggio
è compilato e gdb lo copre: è già lì, non aggiunge dipendenze, e per mettere un
breakpoint ed esaminare una variabile basta. 'nvim-dap' più un adapter resta la
strada per tutto il resto, e per chi vuole un'interfaccia più ricca — al costo di due
dipendenze esterne e di mapping nuove da imparare.

In entrambi i casi l'asse va proposto, non attivato di iniziativa: molti linguaggi si
debuggano benissimo con i test e la diagnostica. Un eventuale insieme di mapping
condivise, indipendenti dal linguaggio e dall'adapter, è la forma giusta per non
moltiplicare le convenzioni.

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

**"Collegare invece di colorare"** vuol dire questo, concretamente. Un gruppo di
evidenziazione può essere definito in due modi: dandogli degli attributi propri
(`nvim_set_hl(0, 'MioGruppo', { fg = '#d787ff', bold = true })`), oppure dichiarando
che *è* un altro gruppo (`nvim_set_hl(0, 'MioGruppo', { link = 'Keyword' })`). Nel
primo caso quel viola resta viola con qualunque color scheme, e prima o poi finisce
illeggibile su uno sfondo chiaro o stona con la tavolozza; nel secondo il gruppo non
ha colore proprio e prende quello che il color scheme attivo dà a `Keyword`,
qualunque esso sia, cambiando insieme a lui. Il lavoro da fare, allora, non è
scegliere un colore: è scegliere **di cosa quella cosa è un caso** — una parola
chiave, un tipo, un commento, un errore — e collegarla al gruppo che lo rappresenta.
È la stessa regola che `AGENTS.md` e 'mini.nvim' applicano a tutti i loro gruppi, ed
è il motivo per cui qualsiasi color scheme funziona subito.

## 14. Toolchain, versioni e ambiente di progetto

L'asse che decide se gli altri funzionano davvero, e quello che dà i guasti più
difficili da capire. Il ruolo di `mise`, il rapporto con gli altri strumenti e il
vincolo Windows sono in `AGENTS.md` e nella Fase 4 di `SKILL.md`.

Qui l'unica cosa che riguarda i linguaggi: **Neovim eredita l'ambiente della shell
che lo ha avviato**, quindi la versione "attiva" di una toolchain può non essere
quella che l'utente vede in un terminale nuovo. È la prima cosa da sospettare quando
un server si comporta diversamente dalla riga di comando, ed è il motivo per cui il
health check deve dirla (§16).

**Configurazione per progetto**: `'exrc'` è già abilitato in fondo a 'init.lua'. Un
`.nvim.lua` nella radice del progetto viene caricato dopo conferma (`:h 'exrc'`), ed è
il posto per ciò che vale per quel progetto e non per il linguaggio: variabili
d'ambiente che il server si aspetta — su Windows, dove gli shim di `mise` non le
applicano, è spesso l'unica sede — feature di compilazione attive, un `makeprg`
diverso. Quel file vive nel progetto, non in questa config.

## 15. Documentazione, REPL, terminale

- **`'keywordprg'`** decide cosa fa `K` senza LSP. Con un server attaccato `K` è già
  l'hover, quindi conta solo per i buffer senza server.
- **Comandi buffer-local** in `after/ftplugin/<ft>.lua` per aprire la documentazione
  o lanciare un REPL. `:command! -buffer` è preferibile a una mapping globale: non
  consuma spazio nel namespace e sparisce con il buffer.
- **Terminale**: `<Leader>tt` e `<Leader>tT` esistono già. Per un REPL specifico basta
  un comando buffer-local che apre `:terminal` con il programma giusto.

> **'mini.doc' non è lo strumento per documentare codice di altri linguaggi.** Genera
> **help file di Vim** (`doc/*.txt`, con i suoi tag) a partire da annotazioni
> EmmyLua nei sorgenti **Lua**: serve a documentare un plugin Neovim, ed è per questo
> che esiste. Tecnicamente `annotation_extractor` è configurabile e si potrebbe
> puntarlo sui `///` di Rust o sui `///` di C#, ma l'output resterebbe un help file di
> Vim: leggibile solo dentro Neovim, invisibile a chi non lo usa, e scollegato
> dall'hover dell'LSP che è dove quella documentazione viene letta davvero. Con un
> generatore nativo (`cargo doc`, `javadoc`) la scelta non si pone. **Anche senza**,
> la risposta resta no: il formato dei commenti di documentazione lo detta il
> linguaggio, non l'editor, e legarlo a uno strumento dell'editor rende il codice meno
> portabile in cambio di un output che nessun altro strumento della catena sa leggere.

## 16. Health check

La forma del file è in `AGENTS.md`, lo scheletro in `assets/health.lua`. Cosa
conviene controllare, per un linguaggio:

- **La versione, non solo la presenza**: una toolchain vecchia fallisce in modi più
  confusi di una assente. `vim.fn.executable()` per esserci, `vim.system(...):wait()`
  per la versione.
- **Quale toolchain è attiva in questa sessione** (§14).
- **Il parser installato**, con
  `vim.api.nvim_get_runtime_file('parser/<lang>.*', false)` — lo stesso controllo che
  'plugin/40_plugins.lua' usa già.
- **Il consiglio come comando eseguibile**: con `mise` è quasi sempre una riga sola,
  il che rende il check anche una guida all'installazione.

## 17. Cosa Neovim non fa

Sapere dove finisce il built-in evita di cercare a lungo una funzione che non esiste.

- **Debug con adapter propri**: non c'è DAP nel core. C'è `Termdebug` per tutto ciò
  che gdb copre (§12).
- **Esecuzione asincrona di build e test**: `:make` è sincrono, e non esiste un task
  runner né nel core né in MINI (§6).
- **Linter non-LSP**: o il linter parla LSP, o finisce dentro `:make` con un compiler
  plugin, o serve un plugin esterno.
- **Gestione dei pacchetti dei server**: coperta da `mise`.
- **Gestione delle dipendenze del progetto**: niente per i manifesti (§11).
- **Breadcrumb nella `'winbar'`.** La `'winbar'` è una riga di testo che Neovim
  disegna in cima a una finestra, e si riempie esattamente come la `'statusline'`:
  una stringa di formato, eventualmente prodotta da una funzione Lua, valutata a ogni
  ridisegno. Neovim quindi **fornisce lo spazio ma non il contenuto**: la catena
  `modulo › classe › funzione` che si vede negli IDE non esiste da nessuna parte come
  funzione pronta. Per ottenerla bisogna, a ogni ridisegno, prendere la posizione del
  cursore, chiedere all'LSP i simboli del documento (o percorrere l'albero
  tree-sitter), trovare la catena di nodi che la contiene, formattarla e passarla alla
  `'winbar'` — con il caching che serve a non farlo ad ogni movimento. È del tutto
  fattibile, ma è codice da mantenere: è il motivo per cui questo è un asse a cui si
  risponde con un plugin, o a cui non si risponde.
