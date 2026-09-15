---
name: nvim-language-support
description: Use when adding, extending, or fixing support for a programming language, platform, or file format — LSP server, tree-sitter parser and queries, :make and quickfix, formatter, snippets, ftplugin options, code navigation, debugging, package manager integration, toolchain installation, health check entries, plus running the program from the editor, a language server that lives inside an external application, and Neovim as that application's external editor. Make sure to use this skill whenever the user says things like "aggiungi il supporto per <linguaggio>", "configura rust/python/go/zig", "manca l'LSP per X", "il quickfix non prende gli errori di X", "voglio compilare/testare da dentro nvim", "installa <server>", "voglio lanciare il gioco/l'app da dentro nvim", "il server sta dentro l'editor di <X>", "far aprire i file a nvim da <applicazione>", or asks where a language specific setting belongs — even when they name only one piece (just the server, just the parser), because the procedure decides what the rest of the config needs in order to stay coherent.
---

# Supporto di un nuovo linguaggio

Aggiungere il supporto per un linguaggio, una piattaforma o un formato. L'obiettivo
è quadruplice:

1. **Decidere** quanto di ciò che Neovim sa già fare vale la pena attivare, e cosa
   invece va preso da un modulo MINI o da un plugin esterno.
2. **Installare** le risorse necessarie in modo dichiarativo e ripetibile, non con
   comandi improvvisati che nessuno ricorda l'anno dopo (Fase 4).
3. **Mettere ogni pezzo** nel file che gli compete.
4. **Lasciare questa skill più precisa** di come l'hai trovata: ciò che la sessione
   scopre sul linguaggio, o su Neovim, torna qui e non muore con la sessione (Fase 6).

Se invece il linguaggio è **già configurato e qualcosa non funziona**, la procedura
non è la strada: parti da ["Quando qualcosa non funziona"](#quando-qualcosa-non-funziona),
che va dal sintomo al livello da interrogare.

## Fase 1 — Inventario: cosa c'è già

**Non saltare questa fase.** È quella che distingue una configurazione di venti
righe motivate da una di duecento che duplicano il runtime. Va fatta dentro una vera
sessione, con aperto un file del linguaggio: gli ftplugin si caricano solo quando il
filetype viene effettivamente impostato.

```vim
" Il filetype viene riconosciuto? Con quale nome?
:=vim.bo.filetype
:=vim.filetype.match({ filename = 'esempio.xyz' })

" Quali file del runtime sono già attivi per questo filetype?
" NOTE: `*` e non `{vim,lua}`. Le graffe le espande la shell, e `cmd.exe` non le
" conosce: su Windows `globpath(&rtp, 'ftplugin/html.{vim,lua}')` risponde stringa
" vuota — cioè "il runtime non ha niente" — mentre `'ftplugin/html.*'` trova il
" file. Verificato con `-u NONE`, quindi non è una regola della config.
" NOTE: `.*` e non `.{vim,lua}`. Su questa macchina (Windows, `shell=cmd.exe`)
" l'espansione delle graffe in `globpath()` non restituisce niente, nemmeno per
" un file che esiste: la risposta vuota si legge come "il runtime non ha niente"
" ed è il modo più rapido di riscrivere ciò che c'è già.
:=vim.fn.globpath(vim.o.rtp, 'ftplugin/<ft>.*')
:=vim.fn.globpath(vim.o.rtp, 'indent/<ft>.*')

" Quali compiler plugin esistono, senza scorrere le directory
:=vim.fn.getcompletion('', 'compiler')

" Chi ha impostato cosa: `:verbose` nomina il file responsabile, `vim.bo`/`vim.wo`
" danno il valore senza rumore. Servono entrambi, per domande diverse.
:verbose setlocal makeprg? errorformat? commentstring? includeexpr?
:=vim.bo.makeprg
:=vim.wo.foldexpr

" Esiste una pagina di help dedicata al ftplugin built-in?
:h ft-<lang>

" Tree-sitter: il parser è disponibile, e installato?
:=vim.tbl_contains(require('nvim-treesitter').get_available(), '<lang>')
:InspectTree

:checkhealth vim.lsp vim.treesitter
```

### Il secondo inventario: i plugin già installati

Fermarsi a `$VIMRUNTIME` fa dare per scontato un livello che per questo linguaggio ha
già lavorato. 'nvim-lspconfig', 'nvim-treesitter-textobjects' e 'friendly-snippets'
spediscono **default per linguaggio**, e la varianza da un linguaggio all'altro è
enorme: il file di 'nvim-lspconfig' per `lua_ls` è una decina di righe, quello per
`rust_analyzer` ne ha duecento — ricerca della workspace root con `cargo metadata`,
runnable, comandi utente.

```vim
" Cosa 'nvim-lspconfig' dà già per il server. LEGGILO, non limitarti a vedere che
" esiste: le funzioni che contiene sono quelle che un override cancella.
:=vim.lsp.config['<server>']

" I textobject tree-sitter arrivano già da 'nvim-treesitter-textobjects'?
:=vim.treesitter.query.get('<lang>', 'textobjects') ~= nil

" Quali snippet arrivano da 'friendly-snippets' (un `<lang>.json`, o una directory)
:=vim.fn.globpath(vim.o.rtp, 'snippets/<lang>*', false, true)
```

Tutte e tre valgono **solo dopo** che il plugin è sul `runtimepath`, e
'friendly-snippets' e 'conform.nvim' arrivano da `Config.later()`: chiesto troppo
presto, `globpath` risponde vuoto e la risposta si legge come "il plugin non dà
niente". Aspetta l'evento, non un numero — è la stessa regola della skill
`nvim-config-testing`, e qui costa un asse dichiarato mancante per sbaglio.

**Un inventario può essere fatto davvero e restare falso a metà, ed è il modo in cui
questa fase viene saltata senza accorgersene.** Le affermazioni sul runtime reggono,
quelle sui plugin no, e nel testo finito nulla distingue le due: si leggono uguali.
Misurato su Godot, dove due assi su tredici sono stati classificati male così — e in un
caso l'asse non era *mancante* ma **attivo e sbagliato**, che è peggio:

- «il parser `gdshader` dichiara `gdshaderinc`, quindi non copre `*.gdshader`».
  `get_filetypes('gdshader')` risponde **`gdshader, gdshaderinc`**: la tabella di
  'nvim-treesitter/plugin/filetypes.lua' registra i filetype **in più** rispetto al
  nome del parser, che è già un filetype di suo. È additiva, ed era stata letta come
  sostitutiva — lo stesso errore di categoria della tabella in
  ["I livelli si sovrappongono"](#i-livelli-si-sovrappongono), applicato però a una
  tabella *di un plugin* invece che a un file scritto da noi.
- «'friendly-snippets' non offre un set per questo linguaggio». Ne caricava **25**, e
  quattro espandevano sintassi di una major precedente del motore.

La regola che ne esce: **un'affermazione su cosa un plugin contiene si scrive solo
dopo il comando che l'ha prodotta.** Le tre righe qui sopra costano un secondo; senza,
un asse archiviato come "non serve ora" può essere un asse già rotto, e nessuno lo
riapre perché il documento dice che è stato valutato.

Da qui esce la lista di **cosa manca**. Riportala all'utente prima di implementare:
spesso è la parte più sorprendente del lavoro. E ciò che questi comandi mostrano non
va riscritto né, peggio, sovrascritto per sbaglio: vedi
["I livelli si sovrappongono"](#i-livelli-si-sovrappongono).

## Fase 2 — Il built-in basta, o serve altro?

La Fase 1 dice cosa *c'è*. Questa dice se **vale**. Ereditare qualcosa dal runtime
non significa che sia la scelta migliore: parte di ciò che Neovim spedisce sono
snapshot di plugin Vimscript nati prima di LSP e tree-sitter, manutenuti a ritmo
lento dal Vim project. Funzionano, ma a volte l'ecosistema del linguaggio si è
spostato altrove.

**E la scelta non è binaria.** Fra il runtime e un plugin nuovo c'è un livello
intermedio **già installato**, che per un linguaggio diffuso ha spesso già fatto il
lavoro: 'nvim-lspconfig' per il server, 'nvim-treesitter' e i suoi textobject per
l'albero, 'friendly-snippets' per gli snippet, 'conform.nvim' per la formattazione.
Il secondo inventario della Fase 1 serve a questo — sapere cosa quel livello dà prima
di chiedersi se ne serve un terzo. Un plugin nuovo che duplica quel livello è lo
stesso errore di uno che duplica il core, solo meno visibile.

Non è una scelta di gusto. Applica questi criteri, in quest'ordine:

**Tieni il built-in quando**

- copre il caso d'uso senza attriti, e il costo di manutenzione è zero: si aggiorna
  con Neovim, non ha config, non si rompe;
- il plugin candidato porta soprattutto funzioni che non useresti;
- **altre parti della config lo danno per scontato.** Le opzioni impostate dai
  ftplugin del runtime non servono solo a chi le legge: `'commentstring'` è ciò che
  'mini.comment' usa per commentare, `'makeprg'` ed `'errorformat'` sono ciò che
  `:make` legge per riempire il quickfix (e quindi ciò che rende utili `]q` e `[q`
  di 'mini.bracketed'), `'includeexpr'` e `'suffixesadd'` sono ciò che fa arrivare
  `gf` al file giusto, `'shiftwidth'` decide l'indentazione di ogni operatore che
  rientra il testo. Sostituire il ftplugin con un plugin che imposta le sue
  convenzioni significa spostare tutti questi comportamenti insieme, spesso senza
  accorgersene finché uno smette di funzionare.

**Guarda altrove quando riconosci uno di questi segnali**

- il file del runtime è **datato o in manutenzione minima**: controlla l'intestazione
  (`Last Change:`, `Latest Revision:`) in cima al file — sono commenti veri, non
  decorativi;
- **duplica in Vimscript ciò che LSP o tree-sitter fanno meglio**: completamento a
  pattern, navigazione a tag, highlight con `syntax/`;
- **l'ecosistema del linguaggio ha un tool di riferimento** che il runtime non
  conosce (un test runner, un gestore di dipendenze, un debug adapter);
- ti accorgi di **star scrivendo la stessa funzionalità a mano**: se serve del codice
  per colmare la distanza, quel codice è già scritto e manutenuto da qualcun altro.

**Il segnale opposto, che vale quanto gli altri**: un plugin che *reimplementa* ciò
che Neovim ha nel frattempo assorbito nel core va **evitato**, anche quando è
popolare e ben fatto. LSP, tree-sitter, `vim.pack`, `vim.snippet`, i comandi di
diagnostica, gli inlay hint e i semantic token sono stati a lungo territorio di
plugin, e quei plugin esistono ancora, spesso con più installazioni del built-in che
li ha resi superflui. Popolarità e attività di sviluppo misurano quanti utenti sono
arrivati prima del core, non se oggi servano: qui l'ordine di preferenza di
`AGENTS.md` decide, e il built-in vince.

**Prima di installare un plugin** vale l'ordine di preferenza di `AGENTS.md`. Il
livello MINI si salta troppo spesso, ed è quello che risolve più casi di quanti
sembri: `references/capabilities.md` elenca, asse per asse, i moduli con
configurazione per linguaggio.

Un plugin esterno deve dichiarare cosa porta che gli altri due livelli non danno, e
va verificato che **non spenga ciò che già funziona**. Alcuni prendono possesso della
configurazione di un server e chiedono esplicitamente di non configurarlo per conto
proprio: la scelta diventa allora **esclusiva** — o il plugin, o `after/lsp/<server>.lua`,
mai i due insieme — invece che **additiva**, cioè un pezzo che si aggiunge lasciando
al suo posto quello che c'era. È la differenza che decide se una prova si può
annullare cancellando due righe o se richiede di rifare la configurazione.

Riporta la decisione all'utente prima di installare qualcosa. Un plugin nuovo è un
impegno di manutenzione, non un dettaglio implementativo.

## Fase 3 — Decidere l'ambito

Non tutti gli assi meritano di essere attivati per ogni linguaggio. Uno che serve a
leggere qualche file altrui ha bisogno di riconoscimento e highlight; quello in cui
si lavora ogni giorno merita tutto.

Per ogni asse decidi **serve / non serve / è già gratis**, sapendo già dove andrà:

| Asse | Dove va | Serve quando |
|---|---|---|
| Riconoscimento filetype | `ftdetect/<lang>.lua` | Neovim non riconosce l'estensione o il nome del file |
| Opzioni di editing | `after/ftplugin/<ft>.lua` | indentazione, `textwidth`, fold, `commentstring` non già corretti |
| Parser e highlight | lista `languages` in `plugin/40_plugins.lua` | esiste un parser tree-sitter per il linguaggio |
| Query personalizzate | `after/queries/<lang>/*.scm` | injection, fold, o capture che il parser non fornisce |
| Server di linguaggio | `after/lsp/<server>.lua` + `vim.lsp.enable()` | esiste un server e il linguaggio si scrive, non solo si legge |
| Build, test, quickfix | `:compiler` in `after/ftplugin/`, o `compiler/<tool>.lua` | il progetto si compila o si testa da riga di comando |
| Formattazione | `formatters_by_ft` di 'conform.nvim' | esiste un formatter dedicato per il linguaggio |
| Snippet | `after/snippets/<lang>.json` | ci sono costrutti ricorrenti propri del linguaggio |
| Navigazione | `path`, `include`, `includeexpr`, LSP | `gf`, `[i`, `<C-]>` non arrivano dove dovrebbero |
| Sorgenti che non stanno su disco | `BufReadCmd` sullo schema dell'URI, in `plugin/` | il server risponde con un `jdt://` invece che con un percorso, perché le librerie arrivano compilate |
| Textobject e manipolazione | `vim.b.mini*_config` in `after/ftplugin/` | i costrutti del linguaggio meritano operatori propri |
| Gestione dipendenze | plugin dedicato, attivato sul manifesto | il linguaggio ha un manifesto che si modifica spesso |
| Debug del programma | `Termdebug`, o 'nvim-dap' + adapter | serve eseguire passo passo, non solo leggere errori |
| Server di un'applicazione esterna | `after/lsp/<server>.lua`, più la porta nel `.nvim.lua` del progetto | il server non lo avvia Neovim: vive dentro un'applicazione che l'utente apre a parte |
| Esecuzione del programma | `:command! -buffer` in `after/ftplugin/<ft>.lua` | il progetto si **esegue**, e sapere se compila non basta |
| Neovim come editor esterno | l'avvio dell'editor (`--listen`) e le impostazioni dell'applicazione | l'applicazione deve poter aprire un file a una riga dentro Neovim |
| Vista sullo stato del progetto | un picker di 'mini.pick', o un buffer scratch | l'albero delle scene, delle dipendenze o lo schema non si leggono come file |
| Toolchain e installazione | `mise`, health check | sempre, appena serve un binario esterno |
| Salute | `lua/config/health.lua` | sempre, se hai aggiunto una dipendenza esterna |

Il catalogo completo — cosa dà ciascun asse, come scoprire se è già coperto, e gli
helptag — è in `references/capabilities.md`. Leggilo quando decidi l'ambito, invece
di andare a memoria: citare un `:h` inesistente in un commento è un danno che resta
nel repo.

**Questa tabella non è chiusa, e un plugin del linguaggio è anche un inventario di
assi.** Quando un plugin dedicato fa cose che qui non compaiono, la lettura immediata
è "funzioni in più che non userei" — e a volte è vera. L'altra è che manchi una riga.
Le righe di questo blocco nascono così, leggendo il sorgente di `godotdev.nvim` per
decidere se adottarlo: la risposta è rimasta **no** (duplica livelli già installati e
su Windows pretende `ncat` per fare ciò che `vim.lsp.rpc.connect` fa da sé), ma quattro
dei suoi moduli nominavano assi che questa skill non aveva — il server posseduto
dall'applicazione, l'esecuzione, l'editor esterno, la vista sul progetto. Leggere il
codice di un plugin che si sta scartando è quindi parte della Fase 2, e ciò che se ne
impara torna qui anche quando il plugin non entra.

La regola vale anche **all'indietro**, sui plugin scartati prima che esistesse. Riletti
`rustaceanvim`, `nvim-jdtls` e `crates.nvim` — tutti e tre respinti a suo tempo sulla
sola documentazione — ne è uscita la riga sulle sorgenti che non stanno su disco
(`plugin/jdtls.lua` registra un `BufReadCmd` su `jdt://*` e `*.class`) e una sezione
su ciò che un server offre fuori dal protocollo, che è poi la sostanza di quei plugin:
`capabilities.md` §4 e §8. `crates.nvim` è l'esito opposto e vale quanto gli altri: i
suoi trenta moduli stanno tutti dentro una riga che c'era già, la gestione delle
dipendenze, e non hanno aggiunto niente.

### Gli assi dicono cosa serve, i contratti dicono come ci si arriva

Un **contratto** è un nome solo — un comando, una mapping o un'opzione — con un
significato fisso, che ogni linguaggio soddisfa a modo proprio in un punto stabilito.
L'asse è la domanda ("questo progetto si compila? si esegue?"), il contratto è la
leva, ed è uguale ovunque: `:make` non sa cosa stia compilando, lo sa `'makeprg'`;
`gf` non sa come si risolve un import, lo sa `'includeexpr'`.

Il valore è tutto nel **nome unico**. Ciò che si ricorda aprendo un repository che non
si conosce deve essere un tasto, non il build tool che quel repository ha scelto — ed
è il motivo per cui un contratto si definisce **anche quando l'ecosistema ha già il
suo comando**: il runtime di Rust ha `:Crun`, e questa config gli affianca `:Run`
senza toglierlo.

| Contratto | Cosa promette | Chi lo soddisfa, e con quale precedenza | Di chi è |
|---|---|---|---|
| `:make`, `]q` | compila o testa, e i risultati si navigano | `'makeprg'` ed `'errorformat'` da un `compiler/<tool>.lua`, scelto con `:compiler` | Vim |
| `:grep`, `]q` | cerca nel progetto, e i risultati si navigano | `'grepprg'` e `'grepformat'` — **per strumento, non per linguaggio** | Vim |
| `gf`, `[I`, `:checkpath` | dal riferimento al file che lo definisce | `'path'`, `'include'`, `'includeexpr'`, `'suffixesadd'` | Vim |
| `K` | la documentazione di ciò che è sotto il cursore | l'hover del server, che vince **salvo** un `'keywordprg'` personalizzato o una mappatura propria | Vim |
| `gq` | impagina | `'formatexpr'` (che i default LSP riempiono), poi `'formatprg'`, poi l'interno — `gw` forza quest'ultimo | Vim |
| `=` | rientra | `'equalprg'` se non vuoto, altrimenti `'indentexpr'`, `'cindent'` o `'lisp'` | Vim |
| `gc` di 'mini.comment' | commenta come si commenta qui | `'commentstring'` | Vim |
| `zc`, `zo` | piega per struttura | `'foldexpr'` | Vim |
| `<C-x><C-o>` | completa con ciò che il linguaggio sa | `'omnifunc'`, di solito quello del server | Vim |
| `<Leader>lf` | formatta come farebbe la CI | `formatters_by_ft` di 'conform.nvim' | questa config |
| `<Leader>l*` | semantica: definizione, riferimenti, rename | un server in `after/lsp/` più `vim.lsp.enable()` | Neovim |
| `:Run` | esegui **questo progetto**, in un terminale | un resolver in `after/ftplugin/<ft>.lua` (`capabilities.md` §19) | questa config |
| `:checkhealth config` | dimmi se l'ambiente di questo linguaggio regge | un `check_<lang>()` in `lua/config/health.lua` | questa config |

Due cose che la colonna centrale rende visibili, e che contano quando se ne definisce
uno. La prima: **la parte variabile non è sempre il linguaggio.** `:grep` promette
quanto `:make`, ma la sua risposta dipende da quale strumento c'è sulla macchina, non
dal file aperto — si imposta una volta e vale per tutti i buffer. La seconda: **un
contratto può avere più implementazioni, e la precedenza fra loro ne fa parte.** `K` e
`gq` ne hanno due — quella di Vim e quella dell'LSP, che vince quando un server è
attaccato e lascia la vecchia come ripiego. È esattamente ciò che `:Run` fa accanto a
`:Crun`, solo che lì a farlo è stato Neovim: un contratto che guadagna
un'implementazione migliore non cambia nome, dichiara chi risponde per primo.

**Prima di inventarne uno, guarda se ce n'è già uno da alimentare.** Vim ne ha per
quasi tutto, e un asse che ricade su uno di questi non vuole un comando nuovo: vuole
che quell'opzione sia impostata per il linguaggio. È la stessa regola della Fase 2
applicata ai nomi invece che ai plugin, e sbagliarla produce un `:Build` che fa
peggio di `:make` perché non ha il quickfix dietro.

Quando invece il buco è reale — l'operazione ha senso in ogni linguaggio, ogni
ecosistema le dà un nome diverso, e nessun contratto di Vim la copre — un contratto
nuovo si definisce dichiarando quattro cose, e nessuna è facoltativa:

1. **il nome e la promessa**, in una frase che valga per ogni linguaggio;
2. **dove il linguaggio lo soddisfa**, uno e un solo punto per linguaggio — e se le
   implementazioni possibili sono due, **quale risponde per prima**, come `K` fa con
   l'hover e `'keywordprg'`;
3. **cosa succede quando quel linguaggio non può soddisfarlo**: rifiutare dicendolo,
   mai fallire in silenzio, e — dove non c'è niente da fare — non definirlo affatto e
   scrivere perché (il Lua di una config Neovim non ha niente da eseguire);
4. **come il progetto lo sovrascrive**, perché il caso particolare di un checkout
   esiste sempre e la sede è il suo `.nvim.lua` (skill `nvim-project-environment`).

`:Run` è nato così. **Quanto un buco sia grande si misura su due cose**, non a
impressione: quante volte al giorno serve l'operazione, e quanti nomi diversi
l'ecosistema ha già inventato per farla — perché dove un contratto manca lo spazio
viene occupato da comandi scoordinati, ed è quella proliferazione la prova che
mancava. L'esecuzione le massimizza entrambe: sta nel ciclo quotidiano quanto la
compilazione, e i nomi che la coprono sono `:Crun`, `:RustRun`, gli `executors/` di
rustaceanvim, il test runner di 'nvim-jdtls', gli script che ogni progetto npm chiama
a modo suo. Nessuno, per contrasto, ha mai inventato un comando per compilare un file
Rust: `:make` c'era già.

Le opzioni con cui Vim chiede a un linguaggio come si fa una cosa sono cinque —
`'makeprg'`, `'grepprg'`, `'keywordprg'`, `'formatprg'`, `'equalprg'` — e di
`'runprg'` non c'è traccia in tutta la documentazione (verificato sui tag). Dopo
l'esecuzione resta poco: un REPL del linguaggio dentro l'editor
(`capabilities.md` §15) è il solo candidato con la stessa forma, e vale meno perché
non ogni linguaggio ne ha uno. "Eseguire i test" **non** è un candidato per quanto lo
sembri: lì il contratto c'è già ed è `:make`, e dove manca qualcosa manca un compiler
plugin.

**Le decisioni che cambiano le abitudini dell'utente** — una mapping nuova, un
formatter che scatta al salvataggio, un `textwidth` diverso — si propongono, non si
prendono.

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
**reference del linguaggio** in `references/`, con il comando esatto, e il **health
check**, che ne verifica presenza e versione.

## I livelli si sovrappongono

Non è una fase: è la regola che vale per ogni file scritto nella Fase 5. Ogni file
aggiunto per un linguaggio ne ha già uno sotto — del runtime, di un plugin, o di
entrambi — e **come i due si combinano cambia da asse ad asse**. È la sola parte della
procedura che rompe in silenzio: nessun errore, nessun messaggio, solo una
funzionalità che c'era e non c'è più.

| Cosa scrivi | Cosa succede a ciò che stava sotto |
|---|---|
| `after/ftplugin/<ft>.lua` | **Si aggiunge**: girano entrambi, il tuo dopo, e corregge (`:h ftplugin-overrule`) |
| `after/queries/<lang>/*.scm` | **Sostituisce tutto**, a meno che la prima riga sia `; extends` (`:h treesitter-query-modeline-extends`) |
| `after/snippets/<lang>.json` | Si aggiunge; stesso prefisso **vince** su 'friendly-snippets', un prefisso senza body lo **rimuove** |
| `after/lsp/<server>.lua` | Fuso con `vim.tbl_deep_extend('force')`: le tabelle si uniscono in profondità, **le funzioni si sostituiscono** |
| `lsp/<server>.lua` (senza `after/`) | **Perde**: viene fuso *prima* di 'nvim-lspconfig', che quindi lo sovrascrive. È il motivo per cui la sede è `after/lsp/` |
| `compiler/<tool>.lua` | **Sostituisce**: `:compiler` carica il primo file trovato sul `rtp`, e la config viene prima del runtime |

La riga dell'LSP è quella che sorprende, perché il danno non si vede. Definire
`on_attach`, `before_init` o `root_dir` **cancella la funzione ereditata**, non la
affianca. E l'elenco dei campi da temere non è chiuso: anche **`cmd` può essere
una funzione** — per `jdtls` è quella che dà a ogni progetto la propria directory
di lavoro — quindi scriverlo come la solita lista è lo stesso errore, in un campo
che sembra innocuo. La regola operativa non cambia: `:=vim.lsp.config['<server>']`
prima di scrivere, e in `after/lsp/` solo ciò che `type()` dice essere una tabella. Se 'nvim-lspconfig' usava `before_init` per riempire le
`initializationOptions` — cioè per far arrivare al server proprio le `settings` che
hai appena scritto — quelle impostazioni smettono di arrivare, e il server continua a
funzionare come se non le avessi mai messe.

> In `after/lsp/<server>.lua` scrivi **`settings` e le altre tabelle**. Se ti serve
> comportamento con il server attaccato e `:=vim.lsp.config['<server>']` mostra che il
> default definisce già una funzione, non scrivere `on_attach`: usa un autocomando
> `LspAttach` in `after/ftplugin/<ft>.lua`, che si aggiunge invece di sostituire.

## Fase 5 — Implementare

Segui l'ordine di dipendenza: ogni passo si verifica da solo, e i successivi
poggiano sul risultato del precedente. Senza filetype non si carica nessun ftplugin;
senza parser non esistono i textobject tree-sitter; senza server non c'è niente da
mappare. Procedere in quest'ordine evita di inseguire un guasto che viene da due
livelli più in basso.

1. **Riconoscimento** — `ftdetect/<lang>.lua`, solo se la Fase 1 ha mostrato un
   filetype vuoto o sbagliato.
2. **Tree-sitter** — il linguaggio nella tabella `languages` di
   `plugin/40_plugins.lua`, sotto il separatore `-- Tree-sitter ===`. È una lista che
   alimenta un macchinario agnostico, quindi è il posto giusto. Riavvia una volta e
   aspetta la fine dell'installazione del parser prima di aprire quei file.
3. **Server di linguaggio** — `after/lsp/<server>.lua`, più il nome dentro
   `vim.lsp.enable({ ... })` nella sezione `-- Language servers ===` di
   `plugin/40_plugins.lua`.
4. **Editing** — `after/ftplugin/<ft>.lua`, solo per ciò che il ftplugin del runtime
   non fa già. Qui vanno anche le config buffer-local di MINI.
5. **Build e test** — se esiste un compiler plugin nel runtime, `:compiler <tool>` e
   basta. Se non esiste, il posto dove definirlo è un `compiler/<tool>.lua`
   (`:h write-compiler-plugin`), **non** `'makeprg'` ed `'errorformat'` impostati
   dentro il ftplugin: nel compiler plugin sono riusabili da altri filetype,
   documentabili, e reversibili con `:compiler make`; nel ftplugin restano legati a
   un solo linguaggio e invisibili a chi cerca da dove viene il comando.
6. **Il resto** degli assi che la Fase 3 ha marcato come necessari.
7. **Health check**: `lua/config/health.lua` esiste — si aggiunge un
   `check_<lang>()` e lo si chiama da `M.check()`, sul modello di `check_rust()`;
   `assets/health.lua` resta lo scheletro per una config che non ce l'abbia ancora.
   Cosa controllare per un linguaggio è in `references/capabilities.md`; la forma del
   file è in `AGENTS.md`.
8. **Changelog e commit**, seguendo `AGENTS.md`. Un linguaggio è quasi sempre più
   commit: parser, server, quickfix e health check risolvono problemi diversi.

Gli altri scheletri in `assets/` coprono i file che ricorrono ogni volta —
`ftdetect`, `ftplugin`, `lsp`, `compiler`, query, snippet — già nella forma che
`AGENTS.md` richiede.

## Verifica

Come si verifica — il criterio, le trappole, le sonde parametrizzate e la
consegna dei passi manuali all'utente — sta tutto nella skill
`nvim-config-testing`, e solo lì. Qui resta cosa un linguaggio deve coprire, che
è un'altra domanda.

Gli assi da interrogare per un linguaggio, con la sonda che risponde:

| Asse | Sonda |
|---|---|
| il filetype viene riconosciuto, e le opzioni del ftplugin sono quelle attese | `buffer_state`, `option_origin` |
| il parser è installato e l'albero è quello atteso | `treesitter` |
| il server si attacca, uno solo, con la configurazione voluta | `lsp` |
| `makeprg` ed `errorformat` vengono dal file giusto, e un errore finisce nel quickfix | `quickfix`, `option_origin` |
| le mapping `<Leader>l` fanno quello che promettono su un simbolo vero | `keymap` |
| `:checkhealth config` dice il vero sulla toolchain | `health` |

I controlli che valgono **solo** per quel linguaggio si scrivono nella sua
reference, non qui: `rust.md` §8 è l'esempio da imitare.

## Fase 6 — Quello che hai imparato resta qui

Viene dopo la verifica perché è lì che si impara metà delle cose. **Ogni volta che
questa skill viene usata per un linguaggio o una piattaforma, la sessione produce
conoscenza che la skill non aveva**: come si comporta davvero un default, cosa un
comando risponde su questa macchina, quale scorciatoia rompe qualcosa in silenzio.
Senza questa fase quella conoscenza muore con la sessione, e la volta dopo si rifà la
stessa indagine e si commette lo stesso errore. Il lavoro è finito quando la skill è
aggiornata, non quando la config funziona.

**Cosa qualifica.** Il criterio è uno: *se l'avessi saputo all'inizio, avrei lavorato
diversamente.* E deve essere **verificato** — un comando eseguito, un file letto, un
comportamento osservato — non deducibile e non ricordato.

**Dove va.** La scelta della sede conta più di quanto sembri:

| Cosa hai imparato | Dove va |
|---|---|
| Vale per **questo** linguaggio: il suo runtime, il suo server, il suo ciclo di lavoro | `references/<lang>.md`, nella sezione che gli compete |
| Vale per **ogni** linguaggio, anche se l'hai scoperto lavorando su uno | `SKILL.md`: una fase, o una regola trasversale |
| È un asse, un'API o un limite di Neovim | `references/capabilities.md`, sotto il suo asse |
| Uno scheletro insegnava qualcosa di sbagliato o incompleto | `assets/`, dove il difetto è stato letto |

L'errore da evitare è archiviare in `references/<lang>.md` qualcosa che vale per
tutti: resta invisibile al linguaggio successivo, che ripete l'errore. Quando una
scoperta sembra specifica e non lo è — "il default del server definisce funzioni che
il mio file cancella" nasce da Rust e vale per ogni server — la sede è `SKILL.md`, e
la reference del linguaggio ci rimanda invece di ripetere.

**Cosa non va scritto.** Questa skill è un indice, e un indice che registra tutto non
indicizza niente:

- il racconto della sessione: cosa è stato provato, in che ordine, cosa non ha
  funzionato per strada;
- ciò che il repository già dice — `AGENTS.md`, i commenti della config, la storia di
  git — che va richiamato con un rimando, mai riassunto;
- una regola dedotta e non osservata: scritta come fatto, è peggio del silenzio;
- ciò che una reference già dice: si corregge quella riga, non se ne aggiunge una
  seconda che col tempo diverge.

**Un linguaggio nuovo si porta dietro il proprio file.** Se `references/<lang>.md` non
esiste, crearlo è parte del lavoro e non un extra: è lì che finisce l'esito delle Fasi
1 e 2, che nessun altro rifarà. La struttura da seguire è in
["La forma di una reference di linguaggio"](#la-forma-di-una-reference-di-linguaggio).

L'aggiornamento della skill è **un commit a sé**, separato da quelli della config:
risolve un problema diverso, come chiede `AGENTS.md`.

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
| Il server si attaccava, e dopo aver riaperto l'applicazione che lo ospita non più | il client è morto con il processo esterno, e nessuno lo richiama | `:edit` sul buffer rifà passare `FileType`, quindi l'attach — `capabilities.md` §17 |
| Il server risponde, ma con simboli che in questo progetto non esistono | due istanze dell'applicazione esterna, **una porta sola**: sei attaccato all'altro progetto | la porta in `:=vim.lsp.config['<server>']` e chi la sta ascoltando — `capabilities.md` §17 |
| Go to definition apre un **buffer vuoto** il cui nome non è un percorso (`jdt://…`) | la risposta del server è un URI, e nessuno sa leggerlo | serve un `BufReadCmd` sullo schema — `capabilities.md` §8 |
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

- `references/capabilities.md` — il catalogo degli assi: cosa dà ciascuno, dove va,
  come scoprire se è già coperto, quali moduli MINI lo toccano.
- `references/rust.md` — Rust come caso completo, e modello per la struttura di una
  reference di linguaggio.
- `references/lua.md` — Lua, cioè il linguaggio in cui questa config è scritta: un
  runtime che non lascia buchi, e un server la cui `library` decide quanto sa.
- `references/angular.md` — Angular, cioè una piattaforma e non un linguaggio: un
  filetype che il runtime non riconosce, due server che si dividono il lavoro, uno
  di essi legato alla versione del progetto, e un compilatore che colora sempre.
- `references/java.md` — Java: un runtime completo a cui manca solo la scelta del
  compiler, un server che va installato con il backend `http:` di `mise`, le
  capability che compaiono solo a caricamento finito, e il primo comando di
  esecuzione della config — la forma da riusare per un linguaggio con più build
  tool.
- `references/cpp.md` — C e C++: un linguaggio in cui i flag di compilazione non
  stanno nel file, quindi il server non è una comodità ma la condizione per
  sapere qualcosa; un compiler plugin da scrivere che ne **eredita** uno del
  runtime invece di ricopiarlo; e lo standard del linguaggio come proprietà del
  progetto e non della config.
- `references/godot.md` — Godot e GDScript: il caso in cui il server non lo avvia
  Neovim ma un'applicazione che l'utente apre a parte, con una porta sola per
  macchina e l'assenza come stato legittimo; un `:make` che risponde a una
  domanda più piccola di quella che sembra; e un set di snippet già attivo e già
  sbagliato, che è il modo in cui la Fase 1 viene saltata senza accorgersene.
- `assets/` — gli scheletri dei file da creare.

### La forma di una reference di linguaggio

`rust.md` non è solo un esempio: è la struttura da riusare, perché ogni sua sezione
risponde a una domanda che ritorna per ogni linguaggio.

1. Cosa il runtime dà già — l'esito della Fase 1, in forma di tabella.
2. Cosa di quello tenere e cosa no, i plugin valutati, e **la raccomandazione** con il
   suo motivo (Fase 2).
3. Installazione della toolchain, con il comando esatto (Fase 4).
4. Cosa implementare, asse per asse, con il codice che finisce nei file (Fase 5).
5. Il ciclo di lavoro quotidiano che ne risulta.
6. Ambiente di progetto, se il linguaggio ne ha bisogno (`.nvim.lua`).
7. Cosa deve dire il health check.
8. Verifica: i controlli falsificabili che valgono solo per questo linguaggio.

Le sezioni senza contenuto si omettono; non se ne aggiungono di nuove senza un motivo,
perché la struttura serve a poter confrontare due linguaggi.
