---
name: nvim-language-support
description: Use when adding, extending, or fixing support for a programming language, platform, or file format — LSP server, tree-sitter parser and queries, :make and quickfix, formatter, snippets, ftplugin options, code navigation, debugging, package manager integration, toolchain installation, health check entries. Make sure to use this skill whenever the user says things like "aggiungi il supporto per <linguaggio>", "configura rust/python/go/zig", "manca l'LSP per X", "il quickfix non prende gli errori di X", "voglio compilare/testare da dentro nvim", "installa <server>", or asks where a language specific setting belongs — even when they name only one piece (just the server, just the parser), because the procedure decides what the rest of the config needs in order to stay coherent.
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
:=vim.fn.globpath(vim.o.rtp, 'ftplugin/<ft>.{vim,lua}')
:=vim.fn.globpath(vim.o.rtp, 'indent/<ft>.{vim,lua}')

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
| Textobject e manipolazione | `vim.b.mini*_config` in `after/ftplugin/` | i costrutti del linguaggio meritano operatori propri |
| Gestione dipendenze | plugin dedicato, attivato sul manifesto | il linguaggio ha un manifesto che si modifica spesso |
| Debug del programma | `Termdebug`, o 'nvim-dap' + adapter | serve eseguire passo passo, non solo leggere errori |
| Toolchain e installazione | `mise`, health check | sempre, appena serve un binario esterno |
| Salute | `lua/config/health.lua` | sempre, se hai aggiunto una dipendenza esterna |

Il catalogo completo — cosa dà ciascun asse, come scoprire se è già coperto, e gli
helptag — è in `references/capabilities.md`. Leggilo quando decidi l'ambito, invece
di andare a memoria: citare un `:h` inesistente in un commento è un danno che resta
nel repo.

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
non sia disponibile.

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
del progetto (`:h 'exrc'`, già abilitato), non il suo `mise.toml`.

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
affianca. Se 'nvim-lspconfig' usava `before_init` per riempire le
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
| Highlight che *era* completo e ora è parziale | query che ha sostituito quella del plugin | la **prima riga** dei file in `after/queries/`: manca `; extends` |
| Il server non si attacca | eseguibile assente, o `root_dir` che non trova la radice | `:checkhealth vim.lsp`, `:=vim.lsp.config['<server>']` |
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
