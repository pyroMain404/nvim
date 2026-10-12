---
name: nvim-language-support
description: Use when adding or extending Neovim support for a programming language, platform, or file format. Entry point for the complete procedure: inventory and built-in evaluation, scope and contracts, mise toolchain installation, layered implementation, verification, and language references. Trigger on "aggiungi il supporto per <linguaggio>", "configura rust/python/go/zig", "voglio compilare/testare da dentro nvim", or "far aprire i file a nvim da <applicazione>". Use it even when the request names only one component, because language support must remain coherent across the whole configuration. For an already-configured language that misbehaves, use nvim-language-troubleshooting.
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
non è la strada: parti da ["Quando qualcosa non funziona"](../nvim-language-troubleshooting/SKILL.md#quando-qualcosa-non-funziona),
che va dal sintomo al livello da interrogare.

- Fase 1–2: `nvim-language-inventory`.
- Fase 3: decidere l'ambito e i contratti, qui sotto.
- Fase 4: `nvim-mise-toolchain`.
- Fase 5–6: implementare, verificare e conservare ciò che hai imparato, qui sotto.
- Troubleshooting: `nvim-language-troubleshooting`.

## Fase 3 — Decidere l'ambito

Non tutti gli assi meritano di essere attivati per ogni linguaggio. Uno che serve a
leggere qualche file altrui ha bisogno di riconoscimento e highlight; quello in cui
si lavora ogni giorno merita tutto.

Per ogni asse decidi **serve / non serve / è già gratis**; dove va ciascuno lo dice
il suo "Dove va" in `references/capabilities.md`.

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
`capabilities.md` "LSP: la semantica" e `capabilities.md` "Navigazione della codebase". `crates.nvim` è l'esito opposto e vale quanto gli altri: i
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
| `:Run` | esegui **questo progetto**, in un terminale | un resolver in `after/ftplugin/<ft>.lua` (`capabilities.md` "Eseguire il programma, e le viste che non sono file") | questa config |
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
(`capabilities.md` "Documentazione, REPL, terminale") è il solo candidato con la stessa forma, e vale meno perché
non ogni linguaggio ne ha uno. "Eseguire i test" **non** è un candidato per quanto lo
sembri: lì il contratto c'è già ed è `:make`, e dove manca qualcosa manca un compiler
plugin.

**Le decisioni che cambiano le abitudini dell'utente** — una mapping nuova, un
formatter che scatta al salvataggio, un `textwidth` diverso — si propongono, non si
prendono.

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

Come si verifica — il criterio e la consegna dei passi manuali all'utente — sta
nella skill `nvim-config-testing`; le sonde parametrizzate e le trappole del banco
stanno in `nvim-headless-probes`, le trappole della shell in `nvim-shell-traps` e
quelle di Neovim e dei plugin in `nvim-runtime-traps`. Qui resta cosa un linguaggio deve coprire, che
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
reference, non qui: `rust.md` "Verifica" è l'esempio da imitare.

## Fase 6 — Quello che hai imparato resta qui

Viene dopo la verifica perché è lì che si impara metà delle cose. **Ogni volta che
questa skill viene usata per un linguaggio o una piattaforma, la sessione produce
conoscenza che la skill non aveva**: come si comporta davvero un default, cosa un
comando risponde su questa macchina, quale scorciatoia rompe qualcosa in silenzio.
Senza questa fase quella conoscenza muore con la sessione, e la volta dopo si rifà la
stessa indagine e si commette lo stesso errore. Il lavoro è finito quando la skill è
aggiornata, non quando la config funziona.

**Cosa qualifica e cosa non va scritto**: stesse regole di
`nvim-config-testing` ("Auto-miglioramento"), con il criterio *se l'avessi saputo
all'inizio, avrei lavorato diversamente*.

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

**Un linguaggio nuovo si porta dietro il proprio file.** Se `references/<lang>.md` non
esiste, crearlo è parte del lavoro e non un extra: è lì che finisce l'esito delle Fasi
1 e 2, che nessun altro rifarà. La struttura da seguire è in
["La forma di una reference di linguaggio"](#la-forma-di-una-reference-di-linguaggio).

Un commit a sé, separato da quelli della config.

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