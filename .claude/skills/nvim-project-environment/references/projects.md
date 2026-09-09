# I progetti configurati su questa macchina

Un progetto per sezione, con quello che serve a rifarlo altrove. Ogni sezione
risponde alle stesse tre domande: **cosa ha di diverso**, **cosa è stato
configurato e dove**, **cosa deve esistere fuori dal repository**.

Ciò che vale per il linguaggio e non per il progetto non sta qui: sta nella
reference di quel linguaggio in `nvim-language-support`, richiamata con un
rimando.

## `~/workspace/GDPR/riesame-privacy-be`

Backend Spring Boot 2.3.1, Maven, Java 8, Lombok ovunque (93 `@Getter`, 79
`@Data`, 32 `@Slf4j` alla data di questa riga). È il progetto che ha reso
necessaria questa skill.

**Cosa ha di diverso**: **Lombok**, e ormai nient'altro. Il build gira su Java 8
— la Lombok 1.18.12 che Spring Boot 2.3.1 tira dentro muore su qualunque JDK più
nuovo della 15 — e questo è un fatto del progetto. Che `jdtls` pretenda una 21 è
un fatto del server, non di qui, e da quando se la prende da sé non lascia più
traccia in questo checkout.

| Dove | Cosa | Perché |
|---|---|---|
| `mise.toml` (non versionato) | `java = "temurin-8"`, `maven = "3.9"` | una JDK sola, quella del build. `[tasks]` senza pin: con la 8 dichiarata per tutto il checkout, un `tools = { java = "temurin-8" }` per task ripeterebbe la stessa decisione in cinque punti |
| `.nvim.lua` | `vim.env.JDTLS_JVM_ARGS = '-javaagent:…/lombok-1.18.36.jar'` | senza, `jdtls` non espande Lombok e riporta **ogni** membro generato come inesistente. Misurato su `AnswerService.java`: 87 errori senza, 0 con. Il perché completo è in `references/java.md` §6 di `nvim-language-support` |
| `.nvim.lua` | autocomando `FileType java` che imposta `makeprg = 'mvn --batch-mode'` | solo per togliere spinner e ANSI dall'output, che l'`errorformat` di `compiler maven` non sa leggere. Deve essere un autocomando perché `after/ftplugin/java.lua` esegue `compiler maven`, che scrive `makeprg` **dopo** la lettura del `.nvim.lua` |

NOTE: fino al 2026-09-09 entrambi i file portavano un rimedio a `jdtls` — il
`mise.toml` dichiarava `["temurin-21", "temurin-8"]` per mettere la 21 sul PATH,
e ogni comando Maven (i `[tasks]` e il `makeprg`) doveva ripinnare la 8 per non
morire dentro Lombok. Tolto tutto: la config del server si porta la propria JDK
(`MISE_JAVA_VERSION`), quindi qui resta solo la 8 e `mvn` la risolve da sé.
Riverificato dopo la semplificazione — `makeprg = "mvn --batch-mode"`, `mise
exec -- java -version` risponde `1.8.0_504`, e `AnswerService.java` ha 0
diagnostiche di errore, cioè Lombok è ancora espanso.

**Fuori dal repository**: `~/.local/share/java/lombok-1.18.36.jar`, copiato a mano
da `~/.m2`. Il `.nvim.lua` controlla che esista e avvisa con `notify_once` se non
c'è, perché il sintomo della sua assenza sembra un progetto rotto.

**Non versionati** e quindi da rifare su una macchina nuova: `.nvim.lua`,
`mise.toml` e `/bin/` sono in `.git/info/exclude`. Il repository che il resto
della squadra legge con altri editor non li vede.

## `~/workspace/GDPR/riesame-privacy-fe`

Frontend Angular dello stesso prodotto.

**Cosa ha di diverso**: niente che Neovim debba sapere — nessun `.nvim.lua`, e
non serve. Il `mise.toml` (anch'esso non versionato) dichiara `node = "20"` e
`"npm:@angular/language-server" = "17"`: il pin del server è la regola descritta
in `AGENTS.md` per un server che carica una libreria dal progetto, ed è ciò che lo
allinea alla major di Angular di questo checkout invece che alla più nuova.

## `~/workspace/RGI`

Non un repository ma una **directory che ne contiene diversi**
(`assimoco-pass-platform`, `assimoco-passportal-client`,
`assimoco-pass-platform-batch`, `assimoco-pass-platform-bom`), con un `mise.toml`
al livello della directory padre — che quindi non è ignorato da nessun repo,
perché non sta dentro nessuno di essi.

**Cosa ha di diverso**: niente che riguardi Neovim. È il progetto che ha reso
evidente un difetto della **config**, non un progetto con un bisogno proprio, e
la distinzione è tutta la lezione.

| Cosa | Valore |
|---|---|
| Toolchain | `java = "temurin-11"`, `maven = "3.6.3"` — le versioni che l'onboarding pretende |
| Node | non globale: i task che ne hanno bisogno pinnano `node = "14.21.3"` per sé |
| `[env]` | `PASS_MVN_SETTINGS` punta al `settings-pass.xml` in `~/.m2`, usato da ogni build con `mvn -s` |
| `[tasks]` | `verify`, `platform:build-first`, `platform:build`, `platform:run`, `portal:build`, `portal:serve-local`, `portal:serve-trt`, `batch:build`, `bom:build` |
| `mise.toml` per repo | uno in ciascuno dei quattro, `java = "temurin-11"` (più `node` nel portale), ognuno in `.git/info/exclude` |
| `.nvim.lua` | **nessuno**, e non serve |

**La storia, perché è il tipo di errore che si ripete**: qui `jdtls` non partiva —
nessun client, nessun errore, progetto sano. Il primo rimedio è stato dichiarare
`java = ["temurin-21", "temurin-11"]` nel `mise.toml` padre e pinnare la 11 nei
`[tasks]`. Funzionava, ed era al livello sbagliato per due motivi che si vedono
solo misurando: reggeva **solo** aprendo Neovim dalla directory padre — da dentro
un repo il suo `mise.toml` è più vicino e vince — e comprava al server la sua JVM
cambiando la toolchain di un workspace di lavoro, che è esattamente ciò che la
Regola 1 chiama errore verso il basso.

Il requisito è del **server**: `jdtls` gira solo su una JDK 21+, in ogni progetto
Java, e un gestionale su Java 8 o 11 è la norma, non l'eccezione. Sta quindi in
`after/lsp/jdtls.lua` (`MISE_JAVA_VERSION` in `cmd_env`, e i `runtimes` derivati
dai JDK installati), e questo workspace è tornato a `temurin-11` ovunque, senza
pin e senza vincoli su da dove si apre l'editor. Verificato headless da entrambe
le directory: client attaccato, con Java 11 attiva in tutte e due.

**Fuori dal repository**: niente da installare a mano. `temurin-21` (per il
server), `temurin-11`, `temurin-8`, `maven 3.6.3` e `node 14.21.3` sono tutte
versioni `mise`, e l'health check della config avvisa se manca la JDK su cui
`jdtls` dovrebbe girare.

**Non versionati** e da rifare su una macchina nuova: il `mise.toml` padre — sta
in una directory che non è un repository, quindi basta ricrearlo — e i quattro
`mise.toml` dei repo, ognuno con la sua riga in `.git/info/exclude`.

NOTE: `~/.m2/settings-pass.xml` esiste ma le tre variabili d'ambiente che
referenzia (`RGI_REPO_PWD`, `RGI_NPM_AUTH`, `GIT_TOKEN`) non sono settate, quindi
nessun build Maven di questi repository è ancora stato eseguito. Il `mise.toml` di
ognuno è dichiarato, non provato.

NOTE: **finché quelle variabili non ci sono, `jdtls` qui non sta leggendo il
progetto vero.** Senza credenziali il parent POM `com.rgigroup.cm:
model-project-assimoco` non risolve, l'import Maven fallisce e il server ripiega
su un progetto JDK nudo: misurato su `assimoco-pass-platform-batch`,
`java.project.getAll` risponde vuoto e la compliance risulta **21** mentre il
`pom.xml` dice 11. Diagnostiche, completamento e `gd` valgono quello che vale un
progetto senza dipendenze. La config lo dice all'apertura (`no project was
imported…`) e la sonda `java_toolchain` fallisce su questo controllo; sparirà da
sé alla prima build andata a buon fine, non c'è niente da configurare.
