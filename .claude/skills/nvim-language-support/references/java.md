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

Niente di obbligatorio. `JAVA_HOME` arriva al server dallo shim di `mise`, quindi
un progetto che pinna il proprio JDK nel suo `mise.toml` è già a posto. Il
`.nvim.lua` serve solo per ciò che nessuno dei due sa: `vim.env.JDTLS_JVM_ARGS`
per agganciare Lombok (`-javaagent:.../lombok.jar`), che 'nvim-lspconfig' legge
nel suo `cmd`.

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
  `jdtls` risponde comunque ma solo sul file aperto.
