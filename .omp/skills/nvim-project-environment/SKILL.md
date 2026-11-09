---
name: nvim-project-environment
description: Use when one specific checkout needs something Neovim cannot guess — a language server that has to be launched differently there, a toolchain pinned to that repository, a `:make` that must run on another runtime, an environment variable a server reads, a project whose diagnostics or build behave unlike every other project of the same language. Make sure to use this skill whenever the user says things like "in questo progetto non funziona", "solo qui il server non vede le dipendenze", "configura questo repo", "mi serve un .nvim.lua", "quale JDK/Node usa questo progetto", "non voglio toccare la config globale per un caso solo" — the decision that matters is which of the three levels the setting belongs to, and it is made before a line is written.
---

# Configurare un progetto

Questa skill riguarda **un checkout preciso**: ciò che è vero di quel repository
e falso, o dannoso, in ogni altro. Non è la config, che vale per tutti i
progetti, e non è il supporto di un linguaggio, che vale per tutti i progetti di
quel linguaggio.

Le altre due skill non vengono ripetute qui. Come si verifica qualcosa sta in
`nvim-config-testing`; cosa serve a un linguaggio sta in `nvim-language-support`
e nella reference che gli compete. Qui c'è **dove** va una configurazione di
progetto, **come si sa** che è stata letta, e il registro di cosa è già stato
configurato su questa macchina.

## Regola 1 — Il livello si sceglie prima di scrivere

Tre livelli. La domanda che li separa è una sola: **chi altro ne ha bisogno?**

| Livello | Vale per | Ci va |
|---|---|---|
| La config (`after/lsp/`, `after/ftplugin/`, `plugin/`) | ogni progetto, per sempre | ciò che è vero di un linguaggio o di un server, mai di un repository |
| `mise.toml` **del progetto** | chiunque lo cloni e usi `mise` | le **versioni** dei tool e i comandi del build: JDK, Node, il package manager, i `[tasks]` |
| `.nvim.lua` **del progetto** | solo chi apre quel progetto con questo Neovim | ciò che nessuno dei due sa: una variabile d'ambiente che un server legge, un `makeprg`, un autocomando che vale lì |

L'errore che costa di più va **verso l'alto**: un `-javaagent` di Lombok in
`after/lsp/jdtls.lua` funziona benissimo nel progetto che l'ha reso necessario e
diventa un presupposto falso in ogni altro progetto Java, dove carica un agent
che nessuno ha chiesto. La prova a cui sottoporre ogni riga è: *questa cosa è
ancora vera nel prossimo progetto dello stesso linguaggio?* Se la risposta è no,
non appartiene alla config, per quanto sia scomodo ripeterla.

Anche verso il basso però si sbaglia: una versione di tool scritta in `.nvim.lua`
serve solo dentro Neovim, mentre la stessa riga in `mise.toml` serve anche alla
shell, alla CI e a chi non usa Neovim. **Il `.nvim.lua` è l'ultima spiaggia**, non
la prima.

## Regola 2 — Un file di progetto che non viene letto non dice niente

`:h 'exrc'` è attivo (`init.lua`), quindi i `.nvim.lua` della directory da cui
Neovim parte **e di tutte le sue padre** vengono sorgentati (vedi Trappole) — **ma solo se è fidato**, e la fiducia è un hash
del contenuto conservato in `stdpath('state')/trust`. Ogni modifica al file la
annulla.

Quello che succede dopo è la parte pericolosa, ed è misurata: Neovim **non
chiede niente** in headless, scrive `exrc: Found untrusted code` su stderr,
prosegue, ed esce 0. Tutto ciò che il file impostava semplicemente non c'è. Il
sintomo è identico a quello di una configurazione sbagliata, e si cerca il guasto
nell'ultima modifica invece che nella fiducia decaduta.

Quindi: **dopo ogni edit, riautorizzare**, e non a memoria.

```powershell
nvim --headless -u NONE <file> -c 'trust' -c 'qa!'   # -u NONE: non leggerlo mentre lo si autorizza
sha256sum <file>; cat "$env:LOCALAPPDATA\nvim-data\trust"
```

## Regola 3 — Degradare, mai fallire

Un `.nvim.lua` è codice di configurazione a tutti gli effetti, quindi vale la
regola di `AGENTS.md`: **mai `error()`**. Un errore lanciato lì interrompe il
resto del file e lascia il progetto configurato a metà, con la parte mancante
invisibile.

Ciò che sta fuori dal repository — un jar, un binario, una directory — si
controlla prima di usarlo e la sua assenza si riporta con `vim.notify_once()`
(`WARN`), perché il costo di non saperlo è alto: è precisamente il caso in cui il
server continua a rispondere e a mentire.

```lua
local agent = vim.fs.normalize('~/.local/share/java/lombok-1.18.36.jar')
if vim.uv.fs_stat(agent) ~= nil then
  vim.env.JDTLS_JVM_ARGS = '-javaagent:' .. agent
else
  vim.notify_once('lombok.jar mancante: ' .. agent, vim.log.levels.WARN)
end
```

## Quando viene letto, e cosa se ne può fare

Misurato: una `vim.env` scritta nel `.nvim.lua` **arriva al `cmd` di un server
LSP**, che parte dopo. Questo è ciò che rende il file il posto giusto per tutto
ciò che un server legge dall'ambiente e che la config non può sapere.

Ogni riga di un `.nvim.lua` è la stessa cosa: **il valore di un default che questo
progetto sovrascrive**. Cambia solo *chi lo legge*, e da quello dipende il meccanismo:

- **Lo legge Neovim, il runtime o un plugin** (`'makeprg'`, `vim.env`, `vim.lsp.config`,
  `vim.g.maven_makeprg_params`): è già un contratto, scritto in `:h` e col suo default.
  Si assegna con l'API di Neovim e non si dichiara niente. Un `set()` qui duplicherebbe
  la documentazione e coprirebbe solo i percorsi che passano dalla config: per `makeprg`
  lascerebbe fuori i `:compiler` chiamati dai ftplugin del runtime (`python.vim` →
  `pytest`, `rust.vim` → `cargo`/`rustc`, `sh.vim` → `shellcheck`, misurato con grep su
  `$VIMRUNTIME/ftplugin`). Resta da scegliere il **momento** della scrittura.
- **La legge questa config, con una forma sua** — `run`, `start`: è un **contratto**,
  dichiarato con `require('config.project').set(nome, spec)` (`lua/config/project.lua`
  ne elenca la forma). Il `set()` dà ciò che un'assegnazione non dà: validazione, il
  `.nvim.lua` più vicino che vince, la forma a funzione, e nessun problema di momento.
  `run` si legge quando `:Run` viene invocato: una lista (a cui gli argomenti della
  chiamata si aggiungono) o una funzione vince sul comando che il linguaggio avrebbe
  scelto. La funzione riceve quegli argomenti e risponde come un resolver, ma `nil`
  significa **"non è roba mia, usa il comando del linguaggio"**, non "rifiuta": il
  messaggio di un `return nil, '…'` viene scartato (`M.command` fa
  `project_command(args) or resolved`, in `lua/config/run.lua`). `start` si legge una
  volta all'avvio, prima che la schermata sia costruita. Per ogni contratto vale il
  `set()` del file più vicino: non c'è sovrascrittura da parte del padre, e un secondo
  `set()` dello stesso contratto nello stesso file avvisa e viene ignorato.

Un valore nuovo diventa contratto solo se la config lo **legge** in una forma sua.
Se lo legge Neovim, la forma c'è già e la tabella dice dove vive il default.

**La tabella dei campi**, per non dover rileggere la prosa sopra ogni volta:

| Cosa il progetto vuole cambiare | Default: da dove viene | Chi lo legge | Meccanismo nel `.nvim.lua`, e perché quel momento |
|---|---|---|---|
| Una variabile che un server legge al proprio avvio | l'ambiente della shell che ha lanciato Neovim | `vim.lsp`, al lancio del `cmd` | `vim.env.<NOME> = ...`, assegnazione diretta: il file è letto **prima** di ogni server |
| `makeprg` / `errorformat` | il compiler plugin del filetype — `:compiler` da `ft.build` (`after/ftplugin/`) o dai ftplugin del runtime — altrimenti `make` | `:make`/`:lmake` di Neovim e `:Make`/`:LMake` (`lua/config/make.lua`, `vim.o.makeprg`/`errorformat`): **la stessa opzione** | autocomando `FileType` con `vim.bo`, riscrivendo l'opzione **per intero**. `:compiler` scrive il valore **buffer-locale**, che oscura il globale (`:h :compiler`): `vim.o.makeprg = …` nel file perde (misurato su `typescript`) |
| Gli argomenti che un compiler plugin del runtime aggiunge al proprio comando (`maven_makeprg_params`, `javac_makeprg_params`, …) | il compiler plugin, `:h compiler-maven` | il compiler plugin, mentre viene sorgentato da `:compiler` | `vim.g.<compiler>_makeprg_params = ...`, assegnazione diretta: letta molto dopo il file. **Appende**, non serve per un prefisso |
| Un'altra opzione che un ftplugin della config imposta anche | il ftplugin | Neovim | `vim.api.nvim_create_autocmd('FileType', …)`: l'assegnazione diretta viene oscurata o sovrascritta |
| Il comando che `:Run` esegue | il resolver del linguaggio (`after/ftplugin/<ft>.lua`) | `:Run`, al momento della chiamata | `require('config.project').set('run', { ... })` (lista) o `set('run', function(args) ... end)` (per dipendere dal buffer; `nil` = lascia al linguaggio): nessun autocomando |
| La schermata iniziale di un progetto | il menu di base di `lua/config/starter.lua` | `config.starter`, una volta all'avvio, dopo il `.nvim.lua` | `require('config.project').set('start', { strategy, header, items })`, forma in 'lua/config/project.lua': nessun autocomando |
| Una versione di tool o un task di build | `mise.toml` | `mise`, la shell, la CI | **non qui** — `mise.toml` del progetto: un `.nvim.lua` la nasconderebbe a tutti loro |

Il file si scrive con lo stile della config (`AGENTS.md`): intestazione a box che
dice **perché quel progetto è diverso**, separatori di sezione, e le quattro
keyword usate per quello che significano. Non è versionato: sta in
`.git/info/exclude` del progetto, così il repository che il resto della squadra
legge con altri editor non lo vede.

## La procedura

1. **Riprodurre il sintomo e attribuirlo.** Un progetto che si comporta male non
   dice da solo se il colpevole è la config, il linguaggio o il checkout. La
   domanda che decide: *lo stesso file, in un altro progetto dello stesso
   linguaggio, si comporta così?* Se sì, non è lavoro di questa skill.
2. **Scegliere il livello** con la Regola 1, prima di scrivere.
3. **Scrivere**, degradando (Regola 3). Ciò che sta fuori dal repository va in un
   posto stabile e nominato: `~/.local/share/java/` per i jar, `mise` per i
   programmi. Mai un percorso dentro `~/.m2`, `node_modules` o una cache: sono
   contenuti che spariscono senza preavviso.
4. **Riautorizzare** il file (Regola 2). Salta questo passo e il resto della
   verifica misura il nulla.
5. **Verificare** con `nvim-config-testing`, e pretendere due cose: che il
   sintomo sia sparito, e che sia sparito **per la ragione giusta** — la prova che
   il file è stato letto si stampa nella sonda (`before = "print(...)"`), perché
   un controllo che passerebbe comunque non è un controllo.
6. **Registrare** il progetto in `references/projects.md`, con quello che serve a
   rifarlo su un'altra macchina.

## Trappole

| Trappola | Rimedio |
|---|---|
| Modificare il `.nvim.lua` annulla la fiducia, e il file smette di essere letto senza che nessuno lo chieda (Regola 2) | riautorizzare dopo **ogni** edit, e confrontare l'hash |
| Un valore assegnato nel `.nvim.lua` **non vince** su quello che un ftplugin sceglie dopo: `:compiler` scrive l'opzione **buffer-locale**, che oscura il globale (`:h :compiler`), e `vim.o.makeprg = …` nel file scrive il globale. Misurato su `typescript`: l'assegnazione perde, l'autocomando vince | autocomando `FileType`, non assegnazione. È il motivo per cui il `makeprg` di 'riesame-privacy-be' è scritto così |
| `<compiler>_makeprg_params` dei compiler plugin del runtime **appende** dopo il comando: non serve a mettere un prefisso davanti (`mise exec … --`). Letto dai sorgenti di `$VIMRUNTIME/compiler/`: `maven`, `javac`, `pytest`, `ruff` appendono. `ty_makeprg` e `tsc_makeprg` invece **sostituiscono** il comando intero (`ty.vim`, `tsc.vim`) | per un prefisso, riscrivere `makeprg` intero nell'autocomando |
| Un jar o un tool preso da `~/.m2` (o da `node_modules`, o da una cache) è lì per caso: se il progetto pinna un'altra versione nessun build manager lo riscaricherà mai | copiarlo in un posto stabile e nominare la versione nel percorso, così quale sia è leggibile senza aprire niente |
| `mise.toml` di un progetto può essere **anche** non versionato (`.git/info/exclude`): allora non segue chi clona, ed è una configurazione locale quanto il `.nvim.lua` | guardare `git check-ignore -v mise.toml` prima di dire "chiunque lo cloni ce l'ha" |
| In una directory che contiene più repository, il `mise.toml` di un repo è **più vicino** di quello padre e ne sovrascrive il tool: un rimedio messo al livello padre non si applica se Neovim viene aperto da dentro il repo, e il sintomo è identico a non averlo mai applicato | misurare da **entrambe** le directory prima di dire fatto (`mise exec -- java -version` nelle due). Se il rimedio regge solo da una, è al livello sbagliato: è un requisito del server, e va nella config |
| Passare `JAVA_HOME` (o qualunque variabile che `mise` gestisce) a un programma lanciato da uno **shim** non serve a niente: lo shim la **ricalcola** dai tool della sua directory e sovrascrive quella ereditata. Misurato: `JAVA_HOME=<21> mise exec -- printenv JAVA_HOME` risponde con la 11 del progetto | usare la leva di `mise`, non quella del programma: `MISE_<TOOL>_VERSION=<versione>` nell'ambiente del figlio fa risolvere allo shim quella versione **per quel processo solo**, e `JAVA_HOME` ne segue coerente |
| Neovim eredita l'ambiente della shell che l'ha avviato: una variabile esportata in un terminale rende un progetto "funzionante" lì e rotto se aperto da un'icona | ciò che serve al progetto va nel `.nvim.lua`, non nel profilo della shell; il sintomo "funziona solo dal terminale" è questo. Una variabile che il progetto non può contenere (una password) va invece resa **persistente a livello utente** — su Windows `[Environment]::SetEnvironmentVariable(…, 'User')` — che è l'unico modo perché la erediti anche un server LSP lanciato da un Neovim aperto da un'icona |
| `:h 'exrc'` sorgenta **tutti** i `.nvim.lua` dalla directory corrente **e da tutte quelle padre** (da Neovim 0.11; fino alla 0.10 solo la corrente), il più vicino per primo. Chi ricorda la regola vecchia mette un loader in ogni checkout di un workspace multi-repo | un file solo alla radice del workspace basta, e i loader non sono neutri: quello che sorgentava il file padre lo faceva eseguire **due volte** (misurato, due `BufEnter` identici). Due file sulla stessa catena si sommano e su un globale singolo (`vim.g.X`, `vim.env.X`) **vince l'ultimo scritto, cioè il padre**: non assegnare la stessa variabile a più livelli. I contratti di `config.project` (`set('run', …)`, `set('start', …)`) fanno eccezione: vale il primo `set()`, cioè il file più vicino. Il file di un repo vale solo se Neovim parte **da dentro** quel repo |
| Il file passato come argomento a `nvim` è già un buffer quando `exrc` è sorgentato, con `filetype` ancora vuoto: leggere lo stato del buffer **al momento della lettura del file** non dà niente. Gli eventi invece arrivano **dopo** (misurato con file `.lua`, ordine `BufReadPost`, `FileType`, `BufWinEnter`, `BufEnter`, `VimEnter`), quindi un autocomando del `.nvim.lua` lo aggancia come ogni altro buffer | niente passata iniziale per `FileType`/`BufEnter`: serve solo se il codice deve agire sullo stato del buffer **subito**, e allora `vim.schedule(function() applica(vim.api.nvim_get_current_buf()) end)` |
| Un `pattern` di autocomando è confrontato con il nome del buffer **come lo scrive Windows**, con i backslash, mentre ogni percorso costruito con `vim.fs` usa `/`. I due non si incontrano mai, e un pattern che non aggancia niente è silenzioso | confronta dentro la callback: `vim.startswith(vim.fs.normalize(vim.api.nvim_buf_get_name(args.buf)), dir .. '/')` |
| Un `BufEnter` registrato dal `.nvim.lua` **non** vince su quello di un plugin caricato da `Config.later()`: quello parte da un timer dopo l'avvio, quindi è registrato dopo ed esegue dopo. È il caso di `MiniMisc.setup_auto_root()`, il cui `chdir()` disfa un `lcd` appena messo — e `chdir()` sovrascrive anche la directory **locale di finestra** | `vim.schedule()` dentro la callback, che sposta l'effetto al tick successivo, dove la catena dell'evento è finita. Misurato: il nostro handler è la voce 1 di `BufEnter`, `Find root and change current directory` la 3 |
| Ciò che un server legge **una volta sola all'avvio** non arriva da `settings`: Neovim la usa per rispondere a `workspace/configuration` e per `didChangeConfiguration`, entrambi dopo `initialize`. La config si legge giusta (`:=vim.lsp.config['<server>']` la mostra) e non cambia niente | passala **anche** in `init_options`, che è ciò che viaggia dentro `initialize`. Il caso vero è `java.configuration.maven.userSettings` di `jdtls`; il dettaglio sta in `references/java.md` di `nvim-language-support` |
| Il contratto `run` è uno solo per Neovim, ma un Neovim può avere buffer di più repository (un workspace con file nel padre) | funzione, non lista, con guardia dentro: `if not vim.startswith(vim.fs.normalize(vim.api.nvim_buf_get_name(0)), root .. '/') then return nil, nil end`. Senza guardia il comando del repo parte per buffer di altri progetti |
| Un file di progetto deve sapere dove abita (per costruire percorsi, guardie, `lcd`) e `vim.fn.getcwd()` è la directory da cui Neovim è partito, non quella del file | `local root = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))` (`:h lua-script-location`). Percorso assoluto, funziona anche quando il file è trovato risalendo dalle directory figlie |
| `:Run` esegue con cwd = la **radice che il resolver del linguaggio ha trovato** (3° valore: `npm` la dà per `package.json`), altrimenti la directory del **buffer**. Un `set('run', …)` non può sceglierla, e vince sul comando ma **non** sulla radice (misurato: lista di progetto + resolver che dà `C:/LANGUAGE/ROOT` → cwd `C:/LANGUAGE/ROOT`). Un percorso relativo nella lista (`npm --prefix a/b/c`) vale quindi solo se la cwd è quella in cui lo si è scritto | percorso assoluto costruito da `root`, oppure `cd "$root" && …` dentro una shell (`bash -c 'cd "$1" && exec …' _ <dir>`), come fa il `.nvim.lua` di `assimoco-pass-platform` (con `C:/Program Files/Git/bin/bash.exe` per non dipendere dal `bash` nel PATH) |

## Il registro

`references/projects.md` — un progetto per sezione: cosa ha di speciale, cosa è
stato configurato e dove, cosa serve installato fuori dal repository. È la
risposta alla domanda che torna sempre — *perché questo progetto ha un
`.nvim.lua`?* — e a quella che arriva su una macchina nuova.

In testa al file sta **il nome della macchina** a cui tutto il resto si riferisce,
con il percorso assoluto di ogni progetto nel suo titolo. Non è cerimonia: il
registro esiste per essere letto da un'altra macchina, dove nessuna di quelle
righe è già vera, e una configurazione descritta senza dire dove viveva è un
indizio invece che una procedura.

Una sezione si aggiunge quando il progetto viene configurato, non "poi": la
conoscenza che non viene scritta subito viene riscoperta indagando, e quella
indagine è il costo che questa skill esiste per non pagare due volte.

## Auto-miglioramento — a ogni progetto

Criterio e cosa non scrivere: come in `nvim-config-testing` ("Auto-miglioramento").

| Cosa hai imparato | Dove va |
|---|---|
| Un comportamento di `exrc`, di `mise`, dell'ambiente o di un file di progetto | tabella [Trappole](#trappole) |
| Un fatto su **questo** progetto: cosa gli serve, perché, cosa installare | `references/projects.md`, nella sua sezione |
| Un fatto su **un linguaggio**, vero in ogni progetto che lo usa | `references/<lang>.md` di `nvim-language-support`, **mai** qui |
| Come si verifica qualcosa | `nvim-config-testing`, **mai** qui |

L'ultima riga è quella che questa skill rischia di violare per prima: la
tentazione di riscrivere qui il comando di verifica appena usato è alta, e una
regola scritta in due posti diverge al primo aggiornamento.

## Reference

- `references/projects.md` — i progetti configurati su questa macchina.
- `assets/nvim.lua` — lo scheletro di un `.nvim.lua`, da copiare nel progetto e
  riempire: intestazione, sezioni, il controllo di ciò che sta fuori dal
  repository, e in coda i due comandi per autorizzarlo.