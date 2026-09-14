# Java

L'esito delle Fasi 1 e 2 per Java, svolte e verificate su questa macchina
(Neovim 0.12.4, Windows, JDK Temurin 21 e Maven 3.9 installati con `mise`). Le
fasi successive seguono la procedura di `SKILL.md`; qui c'è solo ciò che è
specifico del linguaggio.

## 1. Fase 1 — cosa il runtime dà già

Il filetype `java` è riconosciuto senza aggiungere niente; `pom.xml` è `xml` e
`build.gradle` è `groovy`, che sono già le risposte giuste. All'apertura di un
`.java` (`:h ft-java-plugin` — attenzione: **`:h ft-java` non esiste**, i tag
sono `ft-java-plugin`, `ft-java-syntax`, `java-indenting`, `compiler-javac`,
`errorformat-javac`):

| Cosa | Dettaglio |
|---|---|
| Commenti | `commentstring=// %s` e un `comments` che continua i Javadoc `///`, `/* */` su `o` e `<CR>` |
| `gf` sugli import | `includeexpr` che converte `a.b.C` in `a/b/C`, più `suffixesadd=.java` |
| `include` e `define` | pattern completi per `import`, per classi, record, enum e metodi: servono a `:checkpath` e `[I` |
| `formatoptions` | `-t +croql`: manda a capo i commenti, mai il codice |
| Indentazione | `indent/java.vim`, che indenta con `cindent` e quindi **legge `'shiftwidth'`** |
| `b:undo_ftplugin` | presente, con la sua funzione di pulizia |
| Compiler | **nessuno**: `makeprg` ed `errorformat` locali restano vuoti |
| SpotBugs | il ftplugin ha già gli hook pre/post compilazione, attivati da `g:spotbugs_properties` |

`ftplugin/java.vim` porta `Last Change: 2025 May 08` e ha un manutentore attivo
con repository proprio (`zzzyxwvut/java-vim`): non è un file abbandonato.

E in `$VIMRUNTIME/compiler/` ci sono già **`javac`** (2024 Nov 19), **`maven`**
(2025 Nov 18) e **`ant`**, più `checkstyle` e `spotbugs`.

**La differenza con Rust che decide tutto il lavoro**: `ftplugin/rust.vim`
sceglie da sé `:compiler cargo`, `ftplugin/java.vim` non sceglie niente. I
compiler plugin ci sono ma nessuno li attiva, quindi `:make` in un buffer Java
esegue `make` e non trova nessun makefile. È l'unico pezzo mancante del ciclo
build → quickfix, e costa tre righe.

Tree-sitter: il parser `java` è disponibile in 'nvim-treesitter' e non
installato; `xml` idem, e serve per `pom.xml`. 'friendly-snippets' spedisce
`snippets/java/` con tre file — `java.json`, `java-tests.json`, `javadoc.json` —
quindi non c'è niente da scrivere in `after/snippets/`.

## 2. Fase 2 — cosa di questo tenere

**Da tenere tutto.** Il runtime Java non ha la parte invecchiata che ha quello di
Rust: non definisce comandi che duplicano `:make`, non fa navigazione a
espressioni regolari, e le opzioni che imposta sono esattamente quelle su cui
poggiano 'mini.comment', `gf`, `:checkpath` e gli operatori di rientro. L'unico
file superato è `syntax/java.vim`, che il parser sostituisce da sé.

`compiler/maven.vim` in particolare va **letto prima di pensare di riscriverlo**:
riconosce gli errori di `javac` con e senza colonna, i POM non parsabili, i
messaggi di SpotBugs e i blocchi `<<< FAILURE!` di Surefire. Rifarlo sarebbe
novanta righe di `errorformat` da mantenere al posto di una riga di `:compiler`.

### Il livello di 'nvim-lspconfig'

`:=vim.lsp.config['jdtls']` mostra qualcosa che per gli altri server non c'è:

| Cosa | Perché conta |
|---|---|
| `cmd` è una **funzione** | costruisce la directory `-data` sotto `stdpath('cache')/jdtls/workspace/<nome della root>` e aggiunge gli argomenti JVM di `$JDTLS_JVM_ARGS`. Scriverla come lista la cancella, e tutti i progetti finiscono a condividere una workspace |
| `root_markers` sono **due gruppi ordinati** | prima `mvnw`, `gradlew`, `settings.gradle`, `.git`; poi `pom.xml` e i build file Gradle. È ciò che tiene un build multi-modulo su **un solo** client invece di uno per modulo |
| `init_options = {}` | nessun `before_init`, nessun `on_attach`: qui il file locale può contenere solo `settings` e non perde niente |

### I plugin valutati

**[`nvim-jdtls`](https://github.com/mfussenegger/nvim-jdtls)** — è il caso
**esclusivo** della Fase 2: avvia e possiede il client, quindi sostituisce
`after/lsp/jdtls.lua` invece di affiancarlo. Quello che porta in più sono le
estensioni JDT che il protocollo standard non ha: test runner, adapter di debug,
`organizeImports`, extract refactoring, sorgenti decompilate. **Raccomandazione**:
partire dalla configurazione diretta del server, che con il livello di
'nvim-lspconfig' sotto copre completamento, diagnostica, navigazione, rename,
code action e formattazione, e passare a `nvim-jdtls` solo quando servono il
debug o il test runner — migrando la configurazione, non affiancandola.

Leggerne il sorgente cambia due cose in questa valutazione, e nessuna delle due si
vede dal README. La prima è **quanto** sia la lista: `lua/jdtls.lua` implementa a mano
`change_signature`, `extract_variable`/`constant`/`method`, `super_implementation`,
lo spostamento di un file, di un metodo di istanza, di un membro statico e di un
tipo, i generatori di `toString`, dei costruttori, dei delegati e di
`hashCode`/`equals`, più `javap`, `jshell` e `jol` dentro l'editor — ognuno con il
proprio dialogo, perché il server chiede cosa generare (`capabilities.md` §4). È la
metà del refactoring che un IDE Java offre, e nessuna riga di `settings` la avvicina.

La seconda è che **un pezzo si può prendere senza adottare il plugin**. Il go to
definition verso una libreria senza sorgenti allegati risponde con un URI `jdt://`,
e oggi qui apre un buffer vuoto dal nome bizzarro: `plugin/jdtls.lua` risolve il caso
con un `BufReadCmd` su `jdt://*` e `*.class` che chiede `java/classFileContents` al
client già attaccato — una dozzina di righe in `plugin/`, indipendenti da tutto il
resto (`capabilities.md` §8). È il primo lavoro da fare qui se la navigazione nelle
dipendenze diventa quotidiana, e non richiede di migrare niente.

**Un formatter dedicato: no.** Java non ha un formatter ufficiale. `jdtls`
formatta con il formatter di Eclipse e rispetta le impostazioni del progetto,
quindi `lsp_format = 'fallback'` di 'conform.nvim' arriva già alla risposta
giusta senza dichiarare niente in `formatters_by_ft`.
[`google-java-format`](https://github.com/google/google-java-format) esiste nel
registry di `mise` (`aqua:google/google-java-format`) ed è la scelta da
**proporre** solo a chi adotta quello stile: impone una convenzione, non ne
segue una.

## 3. Fase 4 — installazione

```bash
mise use -g java@temurin-21
mise use -g maven@3.9
mise use -g "http:jdtls[url=https://download.eclipse.org/jdtls/milestones/1.61.0/jdt-language-server-1.61.0-202609031315.tar.gz,bin_path=bin]@1.61.0"
```

Il server **non è nel registry di `mise`**, e i backend che ci si aspetterebbe
non lo coprono: `aqua:` non ha una voce per `eclipse-jdtls/eclipse.jdt.ls`, e
`ubi:` elenca le versioni dai tag di GitHub ma quel repository **non pubblica
asset nelle release** — la distribuzione ufficiale è un `tar.gz` su
`download.eclipse.org`. Il backend che risolve il caso è **`http:`**, che scarica
un archivio da un URL, lo estrae e mette sul `PATH` la directory indicata da
`bin_path`. La versione nel nome è arbitraria e serve a `mise` per pinnare:
l'URL vero si ricava da `https://download.eclipse.org/jdtls/milestones/<ver>/latest.txt`,
che contiene il nome del file con il suo timestamp.

Tre conseguenze da conoscere, tutte verificate qui:

- il tarball contiene `bin/jdtls`, `bin/jdtls.py` e `bin/jdtls.bat`, e su Windows
  è il `.bat` che risponde: **`jdtls` è un programma Python**, quindi senza
  `python` il server non parte e il sintomo è un client che non si attacca;
- `bin/jdtls.bat` finisce con un `pause`. Non disturba il server, che vive
  finché vive Neovim, ma **rende pericoloso chiamare `jdtls` in un health check**:
  `jdtls --version` non esiste e qualunque invocazione resta in attesa di un
  tasto. Per questo `check_java()` verifica solo la presenza;
- lo shim di `mise` porta al server l'ambiente del progetto, `JAVA_HOME`
  compreso. È il motivo per cui in `after/lsp/jdtls.lua` `cmd` **non** va scritto
  con un percorso assoluto, che salterebbe lo shim.

`jdtls` 1.61 richiede un JDK 21 o superiore per **girare**, indipendentemente da
quale versione il progetto compila.

## 4. Fase 5 — cosa implementare

**Tree-sitter**: `'java'` e `'xml'` nella tabella `languages`. `xml` è per
`pom.xml`, che in un progetto Maven si legge quanto il codice; installandolo,
'nvim-treesitter' tira dentro anche `dtd`.

### Il server: `after/lsp/jdtls.lua`

**Solo `settings`**, per la regola generale di `SKILL.md` ("I livelli si
sovrappongono"). Per `jdtls` la funzione ereditata da non toccare è `cmd`, non
`on_attach`. Le chiavi sono quelle `java.*` dell'estensione VS Code che guida il
server, e Neovim le consegna quando il server le chiede con
`workspace/configuration`. Quelle che vale la pena mettere sono quelle il cui
default è "spento":

| Impostazione | Default | Perché |
|---|---|---|
| `java.configuration.updateBuildConfiguration = 'automatic'` | `interactive` | con `interactive` il server **chiede** prima di rileggere il `pom.xml`, con una richiesta a cui Neovim non risponde: una dipendenza aggiunta al build resta sconosciuta finché non si riavvia il server |
| `java.maven.downloadSources` e `java.eclipse.downloadSources` | `false` | senza, `<Leader>ls` su un simbolo di una dipendenza apre uno stub decompilato senza nomi dei parametri né commenti. È l'equivalente Java di `rust-src` |
| `java.signatureHelp.enabled = true` | `false` | è ciò che riempie la finestra della firma di 'mini.completion' mentre si scrivono gli argomenti |

Da **proporre** e non decidere: `java.inlayHints.parameterNames`, e
`java.configuration.runtimes`, che dipende da quali JDK ci sono sulla macchina.

### Editing e build: `after/ftplugin/java.lua`

Tre cose, e nessuna ripete il runtime:

- `shiftwidth` e `softtabstop` a 4. Non è gusto: `indent/java.vim` indenta con
  `cindent`, che legge `'shiftwidth'`, e il 2 globale di questa config è la sua
  convenzione per il Lua in cui è scritta;
- fold per struttura con `vim.treesitter.foldexpr()`;
- la scelta del compiler, risalendo alla ricerca del build file:
  `pom.xml` → `maven`, `build.xml` → `ant`, altrimenti `javac`. È lo stesso che
  `ftplugin/rust.vim` fa per `Cargo.toml`, e costa una manciata di `stat`.

**Gradle non ha un compiler plugin nel runtime** (`vim.fn.getcompletion('', 'compiler')`
lo conferma: ci sono `ant`, `javac`, `maven` e nient'altro di Java). Un progetto
Gradle ricade quindi su `javac`, che è sbagliato: lì servirebbe un
`compiler/gradle.lua` scritto apposta, ed è il primo lavoro da fare quando serve.

## 5. Il ciclo di lavoro

Con il compiler scelto dal ftplugin:

| Comando | Cosa fa |
|---|---|
| `:make compile` | compila; gli errori di `javac` finiscono nel quickfix con file, riga e colonna |
| `:make test` | esegue i test; i fallimenti finiscono nel quickfix con il loro messaggio |
| `:make package` / `:make verify` | il resto del ciclo Maven, stesso `errorformat` |
| `:make %` | senza build file: `javac` su un solo file |

`:make` è sincrono, e per Maven l'attesa si sente più che per `cargo check`; vale
la nota della Fase 6 di `capabilities.md` §6 e il TODO già scritto sopra le
mapping `<Leader>l` di 'plugin/20_keymaps.lua'.

### Eseguire l'applicazione non passa da `:make`

Ognuna delle righe qui sopra chiude una domanda e riempie il quickfix. Far **girare**
l'applicazione — `mvn spring-boot:run`, `mvn exec:java`, un `java -jar` sul package
appena costruito — è l'asse separato di `capabilities.md` §19: un processo che vive,
che scrive finché non lo si chiude, e che non produce niente di navigabile. Dato a
`:make`, che è sincrono, tiene l'editor fermo finché l'applicazione non esce, cioè
per tutto il tempo in cui la si vorrebbe usare.

Quale delle due forme di §19 serva qui lo decide il programma, e per un servizio non
c'è scelta: il suo output **è** il log, quindi va catturato e non staccato, e il
processo deve morire con l'editor invece di restare a tenere la porta occupata. È
quello che fa `:Run`, il contratto di §19 (`lua/config/run.lua`); di Java è soltanto
il resolver, in `after/ftplugin/java.lua`:

| Cosa si apre | Cosa parte con `:Run` |
|---|---|
| un POM che dichiara `spring-boot-maven-plugin` | `mvn spring-boot:run` |
| un POM che non lo dichiara | `mvn exec:java` |
| un `build.xml` | `ant run` |
| un `.java` fuori da ogni build | `java <file>`, che dalla 11 non ha bisogno di compilare prima |

Gli argomenti, se ci sono, sostituiscono il goal indovinato (`:Run test -DskipTests`).
Nessun goal è universale in Maven, ed è il motivo per cui va letto dal POM: scegliere
`exec:java` sempre farebbe fallire ogni progetto Spring Boot, e viceversa. Quello che
va oltre — il profilo Spring, la classe `main`, gli argomenti della JVM — non è del
linguaggio: si passa a mano o vive nel `.nvim.lua` del checkout (§6).

**Gradle non c'è, e non è dimenticanza.** Nella tabella `builds` una voce porta due
risposte diverse, il compiler plugin di `:make` e il comando di esecuzione, e per
Gradle la prima non esiste: `:compiler gradle` non è un'operazione nulla ma
`E666: Compiler not supported`, che scatterebbe **mentre il ftplugin si carica**, su
ogni file Java di quel progetto. Per questo `compiler` è facoltativo e solo `run` è
obbligatorio: il giorno che serve, Gradle entra con la sola riga di esecuzione, e il
quickfix resta il lavoro separato del TODO già scritto nel file.

**Il limite da conoscere sui test falliti.** La voce di quickfix di un
fallimento porta il **primo frame** dello stack, che per un `assertEquals` è
dentro JUnit (`AssertionFailureBuilder.java:151`) e non nel test; il frame del
test è qualche voce più sotto, come testo senza file. Il messaggio
dell'asserzione è comunque nella lista e leggibile. **Scartare i frame dei
framework con dei `%-G` non risolve**: verificato, `%-G` chiude il messaggio
multi-riga pendente e a quel punto anche il frame buono viene perso. La strada,
se un giorno serve davvero, è un `errorformat` che riconosca la riga di riepilogo
`[ERROR]   AppTest.greets:10 ...`, che però non contiene un percorso.

## 6. Ambiente di progetto

Il `.nvim.lua` serve per ciò che né la config né `mise.toml` sanno, e in Java
sono due cose: **Lombok** e, su un progetto dietro un repository Maven privato,
**quale `settings.xml` legge l'import**. Dove va un file del genere e come si
verifica che sia stato letto è nella skill `nvim-project-environment`; qui c'è
solo il perché.

Ciò che **non** è lavoro di progetto, per quanto lo sembri, sta subito qui sotto.

### Il `settings.xml` dell'import Maven

`jdtls` importa il build con un Maven **suo**, embedded, che di `mvn -s` non sa
niente: legge `~/.m2/settings.xml` e basta. Su un progetto le cui dipendenze
stanno in un Nexus privato — cioè quasi ogni progetto aziendale — l'import
fallisce, e il modo in cui fallisce è la parte che costa:

- il server **resta attaccato e continua a rispondere**, da un progetto JDK nudo:
  `java.project.getAll` vuoto, la compliance riportata è quella del runtime del
  server (una 21) e non quella del `pom.xml`;
- l'errore vero non è una diagnostica del file Java: sta sul **file di build**,
  ed è `Non-resolvable parent POM … (present, but unavailable)` — Maven che
  rifiuta un POM che ha già in locale, perché l'`_remote.repositories` accanto lo
  attribuisce a un repository che le settings in vigore non dichiarano.

La chiave è `java.configuration.maven.userSettings`, e va data **due volte**:

```lua
local maven = {
  java = { configuration = { maven = { userSettings = '/percorso/settings.xml' } } },
}
vim.lsp.config('jdtls', { init_options = { settings = maven }, settings = maven })
```

`settings` da sola non basta e non lo dice: Neovim la usa per rispondere a
`workspace/configuration` e per `didChangeConfiguration`, entrambi **dopo**
`initialize`, mentre m2e legge quella chiave una volta sola quando parte. Il
sintomo di averla messa solo lì è che i `*.lastUpdated` lasciati dietro da Maven
continuano a nominare `repo.maven.apache.org`.

NOTE: le credenziali restano fuori. Un `settings.xml` che le referenzia con
`${env.X}` funziona anche qui, ma solo se `X` è una variabile **persistente a
livello utente**: un export di shell non arriva a un Neovim aperto da un'icona, e
quindi non arriva alla JVM del server.

NOTE: sistemare le settings non basta se un import è già fallito una volta. Lo
stato sta nella workspace di `jdtls`
(`stdpath('cache')/jdtls/workspace/<progetto>`) e va cancellato, insieme ai
`*.lastUpdated` del repository locale.

### Due JDK, non uno

Un progetto Java ne ha sempre due in gioco, e confonderli costa una diagnosi
intera:

| Quale | Chi lo sceglie | Cosa succede se è sbagliato |
|---|---|---|
| Il JDK **del progetto** — quello contro cui si compila | il `mise.toml` di quel checkout | il codice è validato contro una class library che non è la sua: un metodo aggiunto dopo viene completato e accettato nel buffer, e poi rifiutato dal build vero |
| Il JDK **del server** — quello su cui gira `jdtls` | `after/lsp/jdtls.lua`, per tutti i progetti | `jdtls` 1.61 si rifiuta di partire sotto la **21**, e lo dice solo nel proprio log: `Exception: jdtls requires at least Java 21`. In Neovim non compare niente, nessun client si attacca, e il progetto è sano |

Il secondo non è una versione di progetto e non va cercata lì: è un requisito del
server, vero in ogni progetto Java. Un checkout su Java 8 o 11 — e sono la norma
nei gestionali — lascerebbe il server senza JVM valida. Per questo
`after/lsp/jdtls.lua` la impone da sé con `MISE_JAVA_VERSION` in `cmd_env` (§4).

Nessuno dei numeri in gioco è scritto da qualche parte, ed è il punto: si
chiedono tutti.

| Cosa | A chi si chiede | Perché non si scrive |
|---|---|---|
| Quali JDK esistono | `mise ls java --json` | l'elenco `runtimes` cambia a ogni progetto su una release nuova, e a mano erano **due** copie (config e health check) da tenere uguali |
| Su quale gira il server | la più recente fra quelle installate | il minimo di `jdtls` sta dentro `bin/jdtls.py`, non qui: quando sale si **installa** un JDK, non si modifica un file |
| Contro quale va controllato il progetto | al server, con `java.project.getSettings` | l'ha già risolto lui dal build — Maven, Gradle, Ant o niente — e riparsare il `pom.xml` sarebbe una seconda risposta, peggiore |
| Qual è il minimo di `jdtls` | `bin/jdtls.py`, che lo scrive nel messaggio d'errore (`mise which jdtls` per arrivarci) | un 21 copiato nell'health check resterebbe indietro proprio il giorno in cui serve |

Il prezzo è l'elenco `runtimes`, che smette di essere facoltativo: il server non
gira più per caso sulla stessa JDK del progetto, quindi **ogni** release diversa
dalla sua va dichiarata — non solo quelle più vecchie. Resta un solo passo umano,
e non è automatizzabile perché nessuno può indovinarlo: **installare** il JDK di
quella release, `mise install java@temurin-<major>`.

Un progetto su una release non installata non darebbe errore da solo: verrebbe
controllato contro la JDK del server, cioè completa e accetta metodi che il build
poi rifiuta — lo stesso sintomo di Lombok mancante, e la stessa difficoltà a
riconoscerlo. Per questo `after/lsp/jdtls.lua` lo dice: a import finito
(`language/status` con `type = 'ServiceReady'`) chiede al server contro cosa
compila, e avvisa se nessun runtime dichiarato risponde per quella release.

NOTE: **una risposta di `getSettings` vale solo se il build è stato importato.**
Con un import fallito — un repository irraggiungibile, un parent POM che non
risolve — `jdtls` non tace: ripiega su un progetto JDK nudo e risponde con la
*propria* release, che un runtime ce l'ha sempre. Il controllo va quindi fatto in
due tempi, `java.project.getAll` per primo: lista vuota vuol dire che niente di
ciò che il server dice viene dal build, diagnostiche comprese. Misurato su
'~/workspace/RGI/assimoco-pass-platform-batch' senza credenziali Maven: `getAll`
vuoto, compliance risposta `21`, `pom.xml` che dice 11, e un errore sul `pom.xml`
che nomina il parent non risolvibile.

### Lombok

`jdtls` compila con la propria copia di ECJ dentro la propria JVM, e Lombok
genera i membri **mentre il compilatore gira**: senza il suo agent nessuno di
quei membri esiste per il server. Il sintomo non assomiglia a una configurazione
mancante, assomiglia a un progetto rotto — `The method getFoo() is undefined for
the type Bar` su ogni getter, `log cannot be resolved` su ogni `@Slf4j` — e
riguarda ogni file che tocchi un'entità o un DTO. Misurato su
'riesame-privacy-be', file `AnswerService.java`: **87 errori senza agent, 0 con**.

L'aggancio è una variabile d'ambiente, che 'nvim-lspconfig' legge nel `cmd` che
costruisce per `jdtls`:

```lua
local lombok = vim.fs.normalize('~/.local/share/java/lombok-1.18.36.jar')
vim.env.JDTLS_JVM_ARGS = '-javaagent:' .. lombok
```

Va nel `.nvim.lua` **del progetto che usa Lombok**, non in `after/lsp/jdtls.lua`:
un agent caricato in ogni progetto Java è un presupposto che non si può dare.

Tre cose che non sono ovvie, tutte verificate qui:

- **la versione dell'agent non è quella del `pom.xml`, e spesso non può esserlo.**
  L'agent gira dentro la JVM del server, cioè la JDK 21 che `jdtls` pretende,
  mentre Lombok 1.18.12 — quella che Spring Boot 2.3.1 tira dentro — muore su
  qualunque cosa più nuova della 15. Le annotazioni continuano ad arrivare dal jar
  del build, quindi le due versioni sono indipendenti e solo questa deve stare in
  piedi sulla JDK del server;
- **il jar non si prende da `~/.m2`.** Se il progetto pinna una versione vecchia,
  una più nuova è nel repository locale solo per caso: nessun `mvn` la
  riscaricherà mai, e il giorno che sparisce il sintomo torna. Va copiato in un
  posto stabile — `~/.local/share/java/`, che è la convenzione documentata da
  'nvim-lspconfig';
- **il percorso non può contenere spazi.** 'nvim-lspconfig' spezza la variabile
  sugli spazi bianchi e ne fa un `--jvm-arg=` per pezzo.

## 7. Health check

Le domande a cui `check_java()` deve rispondere: quale JDK vede **questa**
sessione e da quale percorso (lo shim di `mise` o altro), e se è almeno il 21 che
`jdtls` pretende; `javac` e `mvn` con la loro versione; `jdtls` raggiungibile —
**solo presenza**, per il `pause` della §3 — con la riga `mise use -g "http:..."`
come consiglio; `python`, perché il launcher è uno script Python; i parser `java`
e `xml` installati, non solo disponibili.

## 8. Verifica

Oltre a quanto prescrive la skill `nvim-config-testing`, i controlli che valgono
solo qui:

- `:verbose setlocal makeprg?` in un buffer dentro un progetto Maven deve
  nominare `$VIMRUNTIME/compiler/maven.vim`, non un file della config; in un
  file fuori da ogni build deve nominare `compiler/javac.vim`. Se nomina la
  config, qualcosa è stato riscritto inutilmente;
- `:make compile` con un simbolo inesistente deve dare una voce con **file, riga
  e colonna** (`5:24 cannot find symbol`). La prima voce della lista è il
  banner `[ERROR] COMPILATION ERROR :` e non ha file: è normale, e va richiesto
  che *qualche* voce sia navigabile, non la prima;
- `:make test` con un test rotto deve mettere in lista il messaggio
  dell'asserzione, con il limite descritto in §5;
- **le capability di `jdtls` vanno lette a caricamento finito.** Il server
  registra `definition`, `rename`, `formatting` e `codeAction` in modo
  **dinamico**, dopo l'import del progetto: subito dopo l'attach
  `client:supports_method()` risponde `false` per tutte, il che è
  indistinguibile da una configurazione rotta. È il motivo del parametro `ready`
  della sonda `lsp`;
- `signatureHelp` fra le capability supportate è l'unica prova che le `settings`
  sono arrivate al server: il suo default è `false`;
- go to definition da un file di test a uno di `src/main` deve funzionare: è ciò
  che distingue un `root_dir` giusto dalla modalità a file singolo, in cui
  `jdtls` risponde comunque ma solo sul file aperto;
- `:Run` deve esistere **solo** in un buffer Java e scegliere il comando dal build,
  nei quattro casi della tabella di §5. Si verifica senza avviare niente, stubando
  `vim.fn.jobstart` nello `before` della sonda `command` (la skill
  `nvim-config-testing` lo documenta). Due dei quattro casi valgono più degli altri:
  quello **negativo** — `:Run` assente in un buffer di altro filetype e assente fra
  i comandi globali — e quello **fuori da ogni build**, l'unico che legge il nome del
  buffer, e quindi l'unico che si accorge se il comando viene composto dopo aver
  aperto lo split invece che prima (osservato: `java` con il nome vuoto, mentre i tre
  rami del build passavano);
- `:verbose setlocal makeprg?` deve continuare a nominare `compiler/maven.vim`,
  `ant.vim` o `javac.vim` a seconda del build: `:Run` e `:make` leggono la stessa
  tabella, e una modifica all'uno può spegnere l'altro senza che nulla lo dica;
- in un progetto Lombok, che l'agent sia davvero agganciato lo dice la sonda
  `diagnostics` con `absent = 'undefined for the type'`. Da sola però non basta:
  quel controllo passa identico in un progetto che Lombok non lo usa, quindi
  accanto va letta anche la variabile, con
  `before = "print(vim.env.JDTLS_JVM_ARGS)"`.
