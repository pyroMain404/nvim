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

`:h 'exrc'` è attivo (`init.lua`), quindi un `.nvim.lua` nella directory da cui
Neovim parte viene sorgentato — **ma solo se è fidato**, e la fiducia è un hash
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

Le due cose che ci finiscono più spesso:

- **una variabile d'ambiente per un server** — `JDTLS_JVM_ARGS` è il caso vero di
  questa macchina (il perché sta in `references/java.md` di
  `nvim-language-support`, `capabilities.md` "Build, test e quickfix");
- **un'opzione che l'ftplugin della config imposta e qui va cambiata** — allora
  serve un autocomando `FileType`, non un'assegnazione: l'ftplugin gira **dopo**
  il `.nvim.lua`, e un valore assegnato al momento della lettura viene
  sovrascritto senza lasciare traccia;
- **una variabile che un comando della config legge quando viene invocato**, e
  qui l'ordine non è un problema: `:Run` (il contratto di `lua/config/run.lua`)
  consulta `vim.g.run_command` al momento della chiamata, quindi una lista o una
  funzione assegnata qui vince sul comando che il linguaggio avrebbe scelto,
  senza autocomandi. Misurato su un progetto Maven: `{ 'mvn', 'spring-boot:run',
  '-Dspring-boot.run.profiles=local' }` arriva intatta, e gli argomenti di
  `:Run -X` le si aggiungono senza modificarla. La forma a funzione riceve quegli
  argomenti e può rifiutare — `return nil, 'questo progetto avvia solo il
  backend'` — che è come un monorepo dice quali dei suoi filetype si eseguono.

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
| Un valore assegnato nel `.nvim.lua` viene sovrascritto dall'ftplugin, che gira dopo | autocomando `FileType`, non assegnazione. È il motivo per cui il `makeprg` di 'riesame-privacy-be' è scritto così |
| `b:<compiler>_makeprg_params` dei compiler plugin del runtime **appende** dopo il comando: non serve a mettere un prefisso davanti (`mise exec … --`) | riscrivere `makeprg` intero nell'autocomando |
| Un jar o un tool preso da `~/.m2` (o da `node_modules`, o da una cache) è lì per caso: se il progetto pinna un'altra versione nessun build manager lo riscaricherà mai | copiarlo in un posto stabile e nominare la versione nel percorso, così quale sia è leggibile senza aprire niente |
| `mise.toml` di un progetto può essere **anche** non versionato (`.git/info/exclude`): allora non segue chi clona, ed è una configurazione locale quanto il `.nvim.lua` | guardare `git check-ignore -v mise.toml` prima di dire "chiunque lo cloni ce l'ha" |
| In una directory che contiene più repository, il `mise.toml` di un repo è **più vicino** di quello padre e ne sovrascrive il tool: un rimedio messo al livello padre non si applica se Neovim viene aperto da dentro il repo, e il sintomo è identico a non averlo mai applicato | misurare da **entrambe** le directory prima di dire fatto (`mise exec -- java -version` nelle due). Se il rimedio regge solo da una, è al livello sbagliato: è un requisito del server, e va nella config |
| Passare `JAVA_HOME` (o qualunque variabile che `mise` gestisce) a un programma lanciato da uno **shim** non serve a niente: lo shim la **ricalcola** dai tool della sua directory e sovrascrive quella ereditata. Misurato: `JAVA_HOME=<21> mise exec -- printenv JAVA_HOME` risponde con la 11 del progetto | usare la leva di `mise`, non quella del programma: `MISE_<TOOL>_VERSION=<versione>` nell'ambiente del figlio fa risolvere allo shim quella versione **per quel processo solo**, e `JAVA_HOME` ne segue coerente |
| Neovim eredita l'ambiente della shell che l'ha avviato: una variabile esportata in un terminale rende un progetto "funzionante" lì e rotto se aperto da un'icona | ciò che serve al progetto va nel `.nvim.lua`, non nel profilo della shell; il sintomo "funziona solo dal terminale" è questo. Una variabile che il progetto non può contenere (una password) va invece resa **persistente a livello utente** — su Windows `[Environment]::SetEnvironmentVariable(…, 'User')` — che è l'unico modo perché la erediti anche un server LSP lanciato da un Neovim aperto da un'icona |
| `:h 'exrc'` cerca il `.nvim.lua` nella directory corrente **e in tutte quelle padre** (da Neovim 0.11; fino alla 0.10 leggeva solo la corrente). Chi ricorda la regola vecchia mette un loader in ogni checkout di un workspace multi-repo | un file solo alla radice del workspace basta. E i loader non sono neutri: quello che sorgentava il file padre lo faceva eseguire **due volte** — misurato, due `BufEnter` identici registrati aprendo Neovim da dentro un repo |
| Il file passato come argomento a `nvim` viene aperto **prima** che `exrc` sia sorgentato, quindi il suo primo `BufEnter`/`FileType` non passa mai da un autocomando del `.nvim.lua`. In headless non ne arriva un altro, e il rimedio sembra non applicato affatto | oltre all'autocomando, una passata iniziale sul buffer corrente, schedulata perché l'avvio sia finito: `vim.schedule(function() applica(vim.api.nvim_get_current_buf()) end)` |
| Un `pattern` di autocomando è confrontato con il nome del buffer **come lo scrive Windows**, con i backslash, mentre ogni percorso costruito con `vim.fs` usa `/`. I due non si incontrano mai, e un pattern che non aggancia niente è silenzioso | confronta dentro la callback: `vim.startswith(vim.fs.normalize(vim.api.nvim_buf_get_name(args.buf)), dir .. '/')` |
| Un `BufEnter` registrato dal `.nvim.lua` **non** vince su quello di un plugin caricato da `Config.later()`: quello parte da un timer dopo l'avvio, quindi è registrato dopo ed esegue dopo. È il caso di `MiniMisc.setup_auto_root()`, il cui `chdir()` disfa un `lcd` appena messo — e `chdir()` sovrascrive anche la directory **locale di finestra** | `vim.schedule()` dentro la callback, che sposta l'effetto al tick successivo, dove la catena dell'evento è finita. Misurato: il nostro handler è la voce 1 di `BufEnter`, `Find root and change current directory` la 3 |
| Ciò che un server legge **una volta sola all'avvio** non arriva da `settings`: Neovim la usa per rispondere a `workspace/configuration` e per `didChangeConfiguration`, entrambi dopo `initialize`. La config si legge giusta (`:=vim.lsp.config['<server>']` la mostra) e non cambia niente | passala **anche** in `init_options`, che è ciò che viaggia dentro `initialize`. Il caso vero è `java.configuration.maven.userSettings` di `jdtls`; il dettaglio sta in `references/java.md` di `nvim-language-support` |

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

Vale la stessa regola di `nvim-config-testing`, con lo stesso criterio: *se
l'avessi saputo prima di cominciare, avrei fatto diversamente*, e deve essere
**osservato**, non dedotto.

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