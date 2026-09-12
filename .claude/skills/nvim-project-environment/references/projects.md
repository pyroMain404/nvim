# I progetti configurati su questa macchina

**La macchina è `LAPTOP-LCQB9OC7`** — Windows 11 Pro (10.0.26200), utente
`gaeesp`. Sta scritto perché "questa macchina" è la premessa di ogni riga del
file e smette di essere ovvia appena il file viene letto altrove: su un'altra
macchina niente di quanto segue è vero finché non lo si rifà, ed è esattamente a
questo che servono le voci *fuori dal repository* e *non versionati*.

Un progetto per sezione, con quello che serve a rifarlo altrove. Ogni sezione
risponde alle stesse tre domande: **cosa ha di diverso**, **cosa è stato
configurato e dove**, **cosa deve esistere fuori dal repository**.

Ciò che vale per il linguaggio e non per il progetto non sta qui: sta nella
reference di quel linguaggio in `nvim-language-support`, richiamata con un
rimando.

NOTE: i checkout stanno su `W:\` — il Dev Drive, ReFS da 50 GB, etichetta
`Workspace` — e i titoli qui sotto lo dicono.
Le sezioni scritte prima dello spostamento nominavano `~/workspace/...`, che non
esiste più; lo spostamento ha anche invalidato la fiducia di `:h 'exrc'` di ogni
`.nvim.lua`, che è indicizzata per percorso assoluto — la trappola è in
`SKILL.md`.

## `W:\GDPR\riesame-privacy-be`

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

## `W:\GDPR\riesame-privacy-fe`

Frontend Angular dello stesso prodotto.

**Cosa ha di diverso**: niente che Neovim debba sapere — nessun `.nvim.lua`, e
non serve. Il `mise.toml` (anch'esso non versionato) dichiara `node = "20"` e
`"npm:@angular/language-server" = "17"`: il pin del server è la regola descritta
in `AGENTS.md` per un server che carica una libreria dal progetto, ed è ciò che lo
allinea alla major di Angular di questo checkout invece che alla più nuova.

## `W:\GDPR\registro-trattamenti-fe`

Frontend Angular **8.2** di Registro Trattamenti — l'applicazione più vecchia del
workspace GDPR, ferma a webpack 4 e TypeScript 3.5.

**Cosa ha di diverso**: la versione di Node non si deduce dal framework. Angular 8
è contemporaneo a Node 12, ma il `package-lock.json` committato è
`lockfileVersion 3`, cioè prodotto da npm >= 7: con Node 12 (npm 6) il primo
`npm install` riscriverebbe l'intero lock a `lockfileVersion 1`. La versione
compatibile con *questo checkout* è quindi **Node 20**, la stessa con cui sono
già stati costruiti i pacchetti di rilascio.

**Configurato**: `mise.toml` (non versionato) con `node = "20.20.2"` e, in
`[env]`, `NODE_OPTIONS = "--openssl-legacy-provider"`. Il flag è un HACK con la
sua scadenza scritta: webpack 4 hasha i chunk con MD4, che OpenSSL 3 (Node >= 17)
non espone più, e sparisce quando il progetto salirà ad Angular >= 12. In
`package.json` lo imposta solo lo script `start`, per giunta come
`SET NODE_OPTIONS=...`, che funziona unicamente in cmd.exe: da PowerShell o da
Git Bash quello script non lo applica affatto, e `build` non lo applica in nessun
caso. Nel `mise.toml` vale per ogni shell e ogni script.

NOTE: nessun pin di `@angular/language-server`, al contrario di
`riesame-privacy-fe`: il pacchetto esiste solo da Angular 9 in poi, quindi per
questo checkout non c'è versione allineabile e il server Angular non si usa.

**Verificato**: `mise current node` risponde `20.20.2` dentro il checkout e
`NODE_OPTIONS` arriva sia via `mise exec` sia via **shim** (`node -v` nudo); da
`W:\GDPR` la variabile torna `undefined`, cioè il `[env]` non sfugge al progetto.

**Fuori dal repository**: niente da installare a mano oltre a `mise install`.

**Non versionato** e da rifare su una macchina nuova: `mise.toml`, con la sua
riga in `.git/info/exclude`.

## `W:\RGI`

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
| `.nvim.lua` | **uno solo, alla radice**, e copre tutti e quattro i repo perché `exrc` risale le directory padre. Tre cose, tutte discendenti dalle settings Maven PASS — sotto |

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

**Il `.nvim.lua`, e perché ce n'è uno** (2026-09-10). Tutto quello che c'è dentro
discende da un fatto solo: `~/.m2/settings.xml` — quello che legge un Maven a cui
non si dice niente — contiene soltanto il redirect di `localRepository` sul Dev
Drive. Nessun repository RGI, nessuna credenziale. Le settings vere sono
`~/.m2/settings-paas.xml`, e vanno consegnate a mano a tre destinatari diversi:

| Cosa | Perché |
|---|---|
| `init_options.settings` **e** `settings` di `jdtls`, entrambe con `java.configuration.maven.userSettings` | il Maven interno di jdtls legge quella chiave una volta sola, quando parte m2e. `settings` da sola risponde a `workspace/configuration` e a `didChangeConfiguration`, che arrivano **dopo** `initialize`: config perfetta, effetto nessuno — misurato, i `.lastUpdated` che Maven lasciava dietro nominavano ancora `repo.maven.apache.org` |
| `vim.g.maven_makeprg_params = '-s <settings>'` | `$VIMRUNTIME/compiler/maven.vim` **appende** questa variabile a `mvn --batch-mode`, e appendere qui va bene: `-s <file>` è un argomento, non un prefisso, quindi i goal che `:make` aggiunge cadono dopo. Letta mentre `:compiler maven` viene sorgentato, cioè molto dopo il `.nvim.lua`: basta un'assegnazione, senza autocomando |
| un `BufEnter` che fa `lcd` sulla directory Angular del portale | vedi la sezione del portale qui sotto |

**Verificato** su `assimoco-pass-platform-batch`, con la workspace di jdtls
cancellata e i `.lastUpdated` azzerati: import riuscito (`java.project.getAll`
elenca `batch-ext`, `batch-jib`, `batch-zip`), compliance **11** come il
`pom.xml`, `NopeType` inserito apposta segnalato alla riga giusta mentre
`javax.servlet.ServletRequest` risolve in silenzio, e **zero** `.lastUpdated`
nuovi, cioè ogni download è arrivato dai repository RGI.

**Fuori dal repository**: `~/.m2/settings-paas.xml`, e le due variabili
d'ambiente che referenzia. `RGI_REPO_PWD` e `RGI_NPM_AUTH` sono variabili
**utente persistenti** (`[Environment]::GetEnvironmentVariable(…, 'User')`), non
export di shell: è ciò che le fa ereditare anche a un Neovim aperto da un'icona,
e quindi a jdtls. `GIT_TOKEN` non è settata e serve solo al
`maven-release-plugin`. Il `.nvim.lua` controlla che il file esista e avvisa con
`notify_once` se non c'è, perché la sua assenza si presenta come un progetto rotto.

**Non versionati** e da rifare su una macchina nuova: il `.nvim.lua` e il
`mise.toml` padre — stanno in una directory che non è un repository, quindi basta
ricrearli (il primo va poi autorizzato con `:trust`) — e i quattro `mise.toml`
dei repo, ognuno con la sua riga in `.git/info/exclude`.

NOTE: la cancellazione della workspace di jdtls
(`stdpath('cache')/jdtls/workspace/<progetto>`) fa parte del rimedio, non è
igiene. Un import fallito resta **cachato lì dentro**: sistemate le settings, il
server continuava a rispondere da progetti senza source path, con
`java.project.listSourcePaths` vuoto e **nessuna** diagnostica su un errore
inserito apposta — che è indistinguibile da un file corretto.

## `W:\RGI\assimoco-passportal-client`

Il portale PASS, uno dei quattro repository qui sopra, e l'unico che non è Java:
**zero file `.java`**, 547 `.ts`, 417 `.html`. Angular 15 con accanto un layer
AngularJS legacy (322 `.js` sotto `passportal-client/src/main/angularjs/`,
costruito da `portal-architect-cli`), Node 14.21.3, e Maven come guscio che
orchestra `npm` e le immagini Docker. Il progetto vero, per Neovim e per i due
server, è `passportal-client/src/main/angular` — quattro directory sotto la
radice del checkout, ed è lì che stanno `angular.json`, `tsconfig.json`,
`.eslintrc.json` e `node_modules`.

**Cosa ha di diverso**: due versioni di Node che non possono essere la stessa. Il
build vuole la 14.21.3 — Angular 15 è l'ultima major che la regge, quindi quel
pin è un **soffitto**, non un pavimento — mentre
`typescript-language-server` 6 vuole almeno la 18. Il rimedio non sta in questo
checkout: è un requisito del server, come la JDK 21 di `jdtls`, e sta in
`after/lsp/ts_ls.lua`. Qui non ne resta traccia.

Quello che resta al progetto è **la major del language server di Angular**, che è
una proprietà del checkout e di nessun altro:

| Dove | Cosa | Perché |
|---|---|---|
| `mise.toml` (non versionato) | `java = "temurin-11"`, `maven = "3.6.3"`, `node = "14.21.3"` | la toolchain dell'onboarding, invariata |
| `mise.toml` | `"npm:@angular/language-server" = "15"` | `ngserver` carica `@angular/language-service` **dal progetto**. Il globale è la 17, che pretende `typescript/lib/tsserverlibrary` ≥ 5.0 mentre qui TypeScript è 4.9.5: misurato, `Error: Failed to resolve 'typescript/lib/tsserverlibrary' with minimum version '5.0'` |
| `.nvim.lua` | quello di `W:\RGI`, con un `BufEnter` che porta la directory della finestra su `passportal-client/src/main/angular` | nessuna variabile d'ambiente c'entra: quello che serve è **la directory corrente**, vedi sotto |

**La directory corrente è una configurazione, qui.** `MiniMisc.setup_auto_root()`
la mette sulla radice del repository, che è quattro livelli sopra il progetto
Angular. Da lassù `npx --no-install ngc` — il `makeprg` di `compiler/ngc.lua` —
non trova nessun `node_modules` e risponde `not found: ngc`, lasciando il
quickfix vuoto: identico a un `:make` andato bene. `-p <tsconfig>` non è la via
d'uscita, perché `ngc` continua a stampare ogni percorso relativo al tsconfig e
da lì le voci del quickfix puntano a file che non esistono. Restava l'`lcd`, e
metterlo al posto giusto ha richiesto due misure:

- **`BufEnter`, non `FileType`**: `auto_root` chiama `vim.fn.chdir()` da un
  `BufEnter` suo, e `chdir()` sovrascrive anche la directory locale di finestra;
- **schedulato**, perché l'ordine di registrazione non basta: `setup_auto_root()`
  parte da `Config.later()`, cioè da un timer **dopo** l'avvio, quindi il suo
  handler è registrato dopo il `.nvim.lua` e gira dopo. `vim.schedule()` sposta
  l'`lcd` al tick successivo, dove auto_root non lo insegue;
- **più una passata iniziale**, perché il file passato come argomento a `nvim`
  viene aperto **prima** che `exrc` sia sorgentato: quel primo `BufEnter` non
  passa mai dall'autocomando, e in headless non ne arriva un altro.

**Verificato** headless con cwd sulla **radice del checkout** — il caso che
prima falliva: `:make` su un errore di tipo inserito apposta produce 30 voci, la
prima con `bufnr` e riga giusti. E, da una verifica precedente con cwd già sulla
directory `angular`: due client attaccati (`angularls` e `ts_ls`); una
diagnostica `ngtsc` dentro un template su una proprietà che la classe non
dichiara — cioè il language service del progetto è caricato e compatibile, che è
la prova che il pin serve; e una diagnostica `typescript` su un errore di tipo in
un `.ts`.

NOTE: `:make` su questo progetto parte già rosso, e non è un guasto: delle 30
voci una sola era l'errore inserito. Le altre 29 sono errori preesistenti degli
`.spec.ts` sotto `src/app/ext/` e di due `@types` in `node_modules`, che
`tsconfig.json` include.

**Fuori dal repository**: niente da installare a mano oltre a `mise install`.

NOTE: installare un pacchetto npm con `mise` **va in timeout dentro questo
checkout**, e la causa non è `mise`. `~/.npmrc` reindirizza l'intero registry al
Nexus RGI, che risponde solo in VPN, quindi `mise use npm:<pacchetto>` interroga
un host irraggiungibile e muore dopo 20 s con `Failed to install`. Il rimedio è
per quel comando soltanto: `$env:npm_config_registry = 'https://registry.npmjs.org/'`
prima di lanciarlo. Il `.npmrc` non va toccato — è quello che fa risolvere gli
`@rgi/*` al progetto.

NOTE: aprendo un file di questo progetto, `ts_ls` lancia un
`npm install --ignore-scripts types-registry` per l'*automatic type acquisition*,
che finisce sullo stesso registry irraggiungibile. È rumore, non un guasto — il
processo esce da solo e le diagnostiche arrivano comunque — ma è ciò che spiega
un `node.exe` in più subito dopo l'apertura di un `.ts`.

**Non versionato** e da rifare su una macchina nuova: `mise.toml`, con la sua
riga in `.git/info/exclude`.
