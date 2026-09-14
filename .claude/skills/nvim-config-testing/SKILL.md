---
name: nvim-config-testing
description: Use when verifying that a change to this Neovim configuration actually works — running a headless check, reproducing an interactive behaviour, probing windows, mappings, options, autocommands, folds, highlights, LSP, quickfix, tree-sitter, health or startup time, or writing the manual steps to hand back to the user. Make sure to use this skill whenever the user says things like "verifica", "testa", "controlla che funzioni", "prova questa modifica", "è rotto qualcosa?", "fammi vedere che si apre giusto", and whenever a change under `configs/` is about to be called done — this repository has no test suite, and every rule about how to check something correctly lives here and nowhere else.
---

# Verificare una modifica a questa config

Questo repository non ha una suite di test: la verifica è manuale, deliberata, e
tutta la sua procedura sta qui. `AGENTS.md`, le altre skill e i commenti della
config rimandano a questo file e non ripetono niente, perché una regola di
verifica scritta in due posti diverge al primo aggiornamento, e da quel momento
nessuno dei due sa più cosa sia vero.

Gli obiettivi sono tre, in ordine:

1. **Controllare quello che può essere falso**, non quello che è comodo
   guardare.
2. **Farlo una volta sola**, con il banco di prova in `assets/`, invece di
   riscrivere ogni volta lo stesso comando sbagliato in un modo diverso.
3. **Lasciare questa skill più precisa** di come l'hai trovata: ogni verifica
   scopre qualcosa su Neovim, sulla macchina o su se stessa, e quella scoperta
   torna qui ([Auto-miglioramento](#auto-miglioramento--a-ogni-test)).

## Regola 1 — Un controllo che passerebbe comunque non è un controllo

È il criterio che genera tutti gli altri. "Il server si attacca" è vero anche
senza il file in `after/lsp/`; "l'highlight funziona" è vero anche con il vecchio
`syntax/`; "la config si avvia" è vero anche se la modifica non è stata salvata.
Un controllo utile **può fallire**, e il suo fallimento **accusa un livello
preciso**.

Da qui tre conseguenze pratiche:

- **Prima di verificare, sapere cosa distinguerebbe il giusto dallo sbagliato.**
  Se due letture della richiesta portano a due esiti diversi ed entrambi
  "funzionano", non è un problema di verifica: è la richiesta che va chiarita
  prima, altrimenti si finisce per testare benissimo la cosa sbagliata.
- **Misurare, non guardare.** Una finestra "a destra" è un'impressione;
  `row=1 col=92 w=108 h=57` è un fatto, ed è quello che smaschera il secondo file
  che si comporta diversamente dal primo.
- **L'evidenza si conserva insieme all'esito.** Un `PASS` senza il valore
  osservato costringe a rifare tutto per sapere cosa era passato.

## Regola 2 — Una sola passata, alla fine

Non eseguire controlli headless mentre lavori: concentra tutto in un passaggio
alla fine del compito. Verificare a metà costa due volte, e la metà che non è
finita produce fallimenti che non significano niente.

La passata finale copre sempre due cose:

1. **l'avvio pulito** (sonda `startup`), perché un file che lancia un errore
   mentre si carica si porta via tutto ciò che sarebbe stato registrato dopo, e
   il sintomo compare altrove;
2. **i controlli mirati sui file toccati**, inclusi i moduli caricati da
   `Config.later()`, che vanno forzati.

Se ti accorgi a metà passata che ne serve un'altra, quella è l'informazione da
scrivere: la sonda o il parametro che mancava va aggiunto qui, non improvvisato
una seconda volta.

## Regola 3 — Ciò che è interattivo si consegna, non si simula

UI, LSP e plugin differiti non si riproducono fedelmente fuori da una sessione
vera. Quando il comportamento da verificare è interattivo — un colore, un popup,
il modo in cui una finestra "si sente" — la cosa giusta è **consegnare
all'utente i passi esatti**, non descriverli e non fingere di averli eseguiti.

I passi si consegnano così: il comando esatto da incollare, il punto preciso su
cui mettere il cursore, e **cosa dovrebbe succedere**, in modo che l'utente possa
dire di no. `run.ps1 -Show` stampa la riga di comando esatta di una sonda, che
vale più di qualunque descrizione.

## Il banco di prova

Tutto sta in `assets/`, ed è fatto di tre pezzi:

- **`run.ps1`** — lancia una sonda dentro un Neovim headless con **questa**
  config caricata. Sistema una volta per tutte le parti che è facile sbagliare:
  la dimensione del terminale, i parametri passati per environment (nessun
  quoting di JSON sopravvive alla shell), l'attesa del caricamento differito,
  stdout e stderr catturati insieme, e un **watchdog** che uccide il processo
  invece di lasciarlo vivo.
- **`lib.lua`** — la libreria condivisa: parametri, `check`/`info`, e soprattutto
  il **codice di uscita**, che va impostato a mano perché Neovim headless esce 0
  anche quando un `setup()` ha lanciato un errore.
- **le sonde** — una per operazione, tutte parametrizzate: nessuna contiene il
  caso particolare che stai verificando, che arriva da `-Params`.

```powershell
# La forma generale
.claude/skills/nvim-config-testing/assets/run.ps1 <sonda> -File <file> -Params @{ ... }

# Il caso vero da cui è nato questo banco: dove finiscono le finestre quando si
# aprono tre file di seguito da un patch di `:Git diff`
.claude/skills/nvim-config-testing/assets/run.ps1 win_layout -File README.md -Params @{
  before  = "vim.cmd('Git diff HEAD~3')"
  between = "vim.fn.cursor(1, 1) vim.fn.search('^@@', 'W') vim.cmd('normal! 2j')"
  keys    = @('<CR>', '<CR>', '<CR>')
  count   = 4
}
```

Parametri del driver, validi per tutte le sonde: `-File` (il buffer da aprire:
senza, niente ftplugin e niente LSP), `-Params` (quelli della sonda), `-Wait`
(millisecondi per il caricamento differito), `-Columns` / `-Lines` (headless
parte a 80x24, troppo piccolo per dire il vero su un layout), `-TimeoutSec`,
`-Cwd`, `-Appname`, `-Clean`, `-Json`, `-Show`, più `-Session` / `-Reset` /
`-StopSession` per riusare un'istanza.

### Riusare un'istanza, quando l'attesa è il costo

Ogni sonda in più è un Neovim in più, e per certe verifiche l'avvio non è il
costo: lo è ciò che deve succedere **dentro** prima che ci sia qualcosa da
guardare. Un server di linguaggio indicizza il workspace una volta per
processo, quindi dieci sonde one-shot pagano dieci indicizzazioni.

`-Session <nome>` avvia un'istanza che resta viva e le manda le sonde sul
socket RPC (`:h --listen`, `:h --remote-expr`); la sonda non esce, lascia il
suo rapporto in `g:probe_result` e il driver lo rilegge. Misurato su questa
config con `lua_ls`: **14 s la prima sonda, 2-4 s ognuna delle successive**,
contro i 40-60 s di ciascuna sonda one-shot.

```powershell
$R = '.claude/skills/nvim-config-testing/assets/run.ps1'
& $R lsp_request -File 'configs/nvim-0.12/plugin/20_keymaps.lua' -Session lua `
    -Cwd $repo -Reset -Params @{ find = "^nmap_leader\('ba'"; count = 2 }
& $R diagnostics -File 'configs/nvim-0.12/lua/config/health.lua' -Session lua `
    -Cwd $repo -Reset -Params @{ insert = @('local _x = Nope'); expect = 'Nope' }
& $R -StopSession -Session lua   # l'istanza sopravvive alla shell: va chiusa
```

Cosa cambia rispetto a una sonda one-shot, e va tenuto a mente:

- **lo stato resta**: buffer aperti, modifiche non salvate, finestre. È il
  motivo per cui la sessione è veloce, ed è anche ciò che rende il secondo
  risultato diverso dal primo. `-Reset` ripulisce i buffer prima della sonda;
  quando serve uno stato davvero pulito, la sessione è lo strumento sbagliato;
- **i path relativi non sono affidabili** fra una sonda e l'altra: il driver
  rende assoluto `-File` proprio per questo (vedi la trappola su `auto_root`);
- l'esito è sempre un exit code, ma la riga finale dice che l'istanza è ancora
  viva: se un giro finisce senza `-StopSession`, il processo resta.

### Aspettare un evento, non un numero

Un `-Wait` più alto non è mai la risposta giusta a "non era ancora pronto": è
una scommessa che costa a ogni esecuzione e che sbaglia comunque il giorno che
la macchina è lenta. Quasi tutto ciò che è asincrono in Neovim ha un segnale, e
`lib.lua` lo incapsula:

| Helper | Aspetta | Segnale |
|---|---|---|
| `P.wait_event(evento, opts)` | un autocomando qualsiasi | `:h events`, con `pattern` e `buffer` |
| `P.wait_lsp(opts)` | client attaccato **e** server non più occupato | `:h vim.lsp.status()`, silenzio prolungato |
| `P.wait_diagnostics(opts)` | le diagnostiche pubblicate e assestate | `DiagnosticChanged`, silenzio prolungato |

Tutti restituiscono anche i millisecondi impiegati: è quello che distingue
"lento" da "bloccato", e nessuna attesa fissa lo dirà mai.

Parametri che tutte le sonde leggono: `wait` (come `-Wait`) e `json`. Quasi
tutte accettano inoltre uno **snippet Lua** come parametro (`before`, `between`,
`after`): è quello che le rende riusabili, perché lo stato da cui parte la
verifica è un dato, non l'ennesima copia della sonda. Uno snippet gira fuori
dallo scope della sonda e **non vede `P`**: quello che deve arrivare nel
rapporto o si lascia in un `vim.b.<nome>` letto con `vars`, o si stampa con
`print()`, che finisce in stderr.

L'esito è una lista di `PASS` / `FAIL` / `INFO` con l'evidenza sotto, e un **exit
code** che vale 0 solo se nessun controllo è fallito: è quello che permette di
incatenare le sonde senza rileggerle a occhio.

## Le operazioni

| Sonda | Risponde a | Parametri principali |
|---|---|---|
| `startup` | la config si carica senza dire niente che non dovrebbe? | `modules`, `forbid`, `expect`, `allow` |
| `deferred` | il modulo caricato da `later()` c'è, e con quale configurazione? | `module`, `force`, `field`, `expect` |
| `option_origin` | **chi** ha impostato un'opzione? | `options`, `scope`, `before`, `expect` |
| `keymap` | la mapping esiste, e cosa fa quando la premi? | `lhs`, `mode`, `press`, `before`, `after` |
| `autocmd` | l'autocomando è registrato, e scatta? | `event`, `group`, `pattern`, `fire`, `after` |
| `command` | il comando utente esiste, e gira senza errori? | `name`, `buffer`, `run`, `expect` |
| `win_layout` | dove sono finite le finestre, dopo ogni tasto? | `before`, `between`, `keys`, `count`, `ignore` |
| `buffer_state` | cosa è diventato il buffer dopo l'azione? | `before`, `keys`, `options`, `vars`, `expect` |
| `fold` | i fold sono quelli che il `foldexpr` promette? | `before`, `find`, `levels`, `closed` |
| `highlight` | quale gruppo colora davvero quel punto, e con che colore? | `find`, `row`/`col`, `group`, `fg`/`bg`, `link` |
| `treesitter` | il parser c'è e l'albero è quello atteso? | `lang`, `find`, `node`, `capture`, `injected` |
| `lsp` | quale server ha risposto, e con quale configurazione? | `server`, `clients`, `methods`, `settings`, `timeout` |
| `lsp_request` | e cosa risponde, su un simbolo vero? | `method`, `find`, `col`, `count`, `expect`, `resolve` |
| `diagnostics` | il server segnala quello che deve, e tace su quello che deve? | `insert`, `count`, `expect`, `absent`, `severity` |
| `quickfix` | `:make` produce voci navigabili? | `make`, `makeprg`, `errorformat`, `min`, `pattern` |
| `health` | `:checkhealth` in forma che uno script può far fallire | `sections`, `fail_on`, `allow`, `show` |
| `startuptime` | quanto costa l'avvio, file per file? | `file`, `budget`, `top`, `filter` |
| `java_toolchain` | su quale JDK gira `jdtls`, e contro quale controlla il progetto? | `release`, `timeout`, `before` |

L'intestazione di ogni file dice cosa fa, perché, e documenta tutti i suoi
parametri: leggila prima di aggiungerne uno, e aggiungilo lì quando manca.

`java_toolchain` è l'unica sonda legata a un linguaggio, e la deroga è
deliberata: il contratto che verifica si rompe **in silenzio** in tutte e tre le
sue forme — il server non parte e nessun client si attacca senza che Neovim dica
niente; il progetto viene controllato contro la class library sbagliata; l'import
del build fallisce e il server continua a rispondere da una JDK nuda. Nessuna
delle tre si vede guardando, e una sonda generica non le può nemmeno formulare.
Prima di aggiungerne un'altra così, chiedersi se il guasto è invisibile davvero:
se si vede, la sonda giusta è già in tabella.

`option_origin` e `lsp` meritano una nota, perché rispondono a **quasi ogni**
guasto di questa config: la prima (`:verbose set`) è l'unica che nomina il file
responsabile, la seconda distingue "non attaccato" da "non ancora attaccato". La
maggior parte dei problemi qui è un livello che ne ha sovrascritto un altro.

Le tre sonde LSP rispondono a domande diverse e si usano in quest'ordine: `lsp`
dice **se e come** il server è configurato, `lsp_request` cosa risponde su un
simbolo preciso (ed è quella che smaschera una `library` incompleta o una
`settings` mai arrivata), `diagnostics` cosa segnala sul buffer — con `absent`,
che è l'unico modo di provare che un globale dichiarato **non** viene segnalato.

## Trappole

Da tenere presenti sia quando scrivi il comando sia quando ne leggi l'output.
`run.ps1` ne neutralizza già parecchie; le altre restano tue.

| Trappola | Rimedio |
|---|---|
| `nvim --headless -l script.lua` **non carica `init.lua`**: niente plugin, niente autocomandi, e ogni attesa di un evento va in timeout | non usare `-l`: apri il file come argomento e inietta il codice con `-S`, che è quello che fa `run.ps1` |
| Il codice dentro `Config.later()` parte su un timer dopo l'avvio: un `+qa` immediato esce prima che sia mai girato | `P.run()` aspetta `wait` ms; alzalo quando il pezzo dipende da un plugin da scaricare |
| L'exit code è 0 anche quando un `setup()` lancia un errore | fai fallire esplicitamente (`cquit`) e leggi anche stderr: `run.ps1` cerca `Failed to run` e i traceback |
| Headless parte a 80x24, e ogni misura di layout è falsa | `-Columns` / `-Lines`, già impostati a 200x60 |
| L'attacco di un server LSP è asincrono: "non attaccato" e "non ancora attaccato" si somigliano | fai polling con `vim.wait`, come la sonda `lsp`; se non arriva, guarda `cmd` e PATH prima di sospettare la config |
| Un server abilitato per un altro filetype non si attacca, e sembra un guasto | qui è abilitato solo ciò che sta in `vim.lsp.enable()` di `plugin/40_plugins.lua`: verifica quello per primo |
| `:make` con un `errorformat` che non riconosce niente lascia il quickfix vuoto, identico a una build riuscita | rompi qualcosa apposta, e pretendi una voce con file e riga |
| L'output asincrono di `TSUpdate` mente ("up-to-date" senza parser installato) | usa la variante sincrona e cerca i `.so` / `.dll` in `stdpath('data')/site/parser/` |
| Percorsi profondi superano MAX_PATH su Windows | falsi fallimenti (checkout falliti, ENOENT sulla cache luac): prova sotto un percorso corto |
| All'avvio `v:errmsg` contiene `Couldn't find a watcher matching key and callback`, e la sonda `startup` fallisce | non viene dalla modifica: è `MiniMap.gen_integration.builtin_search()` che al caricamento esegue `silent! call dictwatcherdel(v:, 'hlsearch', ...)` su un watcher che la prima volta non esiste. Il messaggio è di `dictwatcherdel()`, e `silent!` lo nasconde all'utente ma **non azzera `v:errmsg`**. Compare solo dopo i `later()` (misurato: assente con `-Wait 0`, presente a 327 ms): passa `allow = @('watcher matching key')` |
| Lo stato di 'mini.diff' letto subito è quello di mezzo secondo prima: `vim.b.minidiff_summary` è `nil` appena referenziata una revisione, e `ref_text` arriva **130 ms** dopo l'apertura del file (misurato) | l'attach è asincrono, e l'attesa si fa sulla cosa che serve: `vim.wait(800, function() return (vim.b.minidiff_summary or {}).source_name ~= nil end)`, oppure su `(MiniDiff.get_buf_data(0) or {}).ref_text`. E l'attach da solo non dice che c'è un riferimento: dentro un repository 'mini.diff' si attacca **anche** a un file che Git non traccia, con dati presenti, nessun `ref_text` e zero hunk |
| `gF` dentro un patch contro il working tree apre `minigit://.../edit <file>` e non `show <commit>:<file>` | non è un guasto: lo stato "after" di quel patch è il file su disco. Per lo stato a un commit parti da un patch di commit (`Git show HEAD`, `Git log -p`) |
| La sonda `command` esegue `after` solo quando le è stato dato anche `run` | uno snippet che deve girare comunque va passato come `before` |
| `stylua --check` va eseguito **dalla radice del repository** | StyLua cerca `.stylua.toml` a partire dalla directory corrente: da altrove applica i suoi default (tab, doppi apici) e il diff non significa niente |
| Un file scritto con line ending LF fa segnalare a StyLua **l'intero file** | il repo è CRLF (`line_endings = "Windows"` più `core.autocrlf`): converti prima di rileggere il diff |
| Le heredoc di Bash su questa macchina collassano `\\` in `\`, e un `'\''` dentro una stringa Python la tronca | non generare file con backslash da script (usa `vim.fs.dirname`, `[char]92`), e non cercarne: un blocco `old` che contiene un escape ottale (la NOTE su `core.quotePath` in 'plugin/43_review.lua') arriva a Python già risolto in un carattere accentato, l'`assert` fallisce e la riga sembra identica a quella nel file. Spezza la sostituzione attorno alla riga con il backslash, e rileggi sempre la riga scritta. Un escape corrotto **dentro un commento** non fa fallire nessuna sonda: dopo un'edit scriptata la verifica è `git diff` letto a occhio, non la passata headless |
| Una heredoc lunga (un file Lua intero) fallisce **prima** di scrivere: `unexpected EOF while looking for matching '`, e il file non esiste. Il messaggio nomina una riga che nel sorgente non ha niente di sbagliato | un file nuovo si scrive con lo strumento di edit, non dalla shell; poi `stylua <file>` lo riporta a CRLF, che è anche l'unico modo di non sbagliare la conversione a mano |
| Un file che un altro Neovim tiene aperto fa stampare su stderr `:h E325` (la domanda intera) oppure `W325: Ignoring swapfile from Nvim process N` a seconda di com'è quello swap, e il `bufload()` su quel file **lancia**: la sonda esce 1 con un traceback, identico a una config rotta | prima di indagare, `Get-Process nvim`: se sono editor dell'utente, i loro swap sono legittimi e non si cancellano. E il codice che carica buffer in blocco deve reggerlo (`pcall`), perché una review si legge proprio mentre il codice è aperto altrove |
| `Start-Process -ArgumentList` unisce gli argomenti con uno spazio e non ne quota nessuno | un argomento con spazi arriva spezzato: quotalo tu (`Format-Argv` in `run.ps1`) |
| `--startuptime` produce righe a due e a tre colonne, con la prima cumulativa | ordinare tutto insieme mette in cima la fine dell'avvio: classifica solo le righe "sourcing" |
| `:h vim.lsp.status()` vuoto **non** vuol dire "ha finito": un server apre più token di progresso di seguito (`lua_ls` uno per scope) e fra due token lo stato è vuoto | pretendi un silenzio prolungato, non il primo buco: è ciò che fa `P.wait_lsp()` con `quiet` |
| `nvim --server ... --remote-expr` senza `--headless` **sul client** restituisce il valore sepolto nelle sequenze di escape del terminale | `--headless` anche sul client: `Invoke-Remote` in 'run.ps1' lo fa |
| Aprire un file cambia la directory corrente (`MiniMisc.setup_auto_root()` in 'plugin/30_mini.lua'), quindi un path relativo significa un'altra cosa alla sonda successiva | passa path assoluti; in sessione il driver li rende assoluti da solo |
| Il parametro `find` è una **regexp di Vim**, non un pattern Lua: lì `(` è letterale e `\(` apre un gruppo — un pattern sbagliato lancia `E54` | scrivi `^nmap_leader('ba'`, non `^nmap_leader\('ba'`; la sonda riporta l'errore come parametro invalido, non come guasto |
| Il parametro `expect` — e `pattern` della sonda `quickfix`, che è lo stesso caso — è un **pattern Lua**, non una regexp: `\.` non è un punto letterale e l'alternanza `a|b` non esiste (`|` è un carattere qualsiasi), così un pattern scritto con la sintassi delle regex non aggancia mai e il `FAIL` accusa la config invece del pattern | usa la sintassi Lua: `textwidth=85 .*after.ftplugin.lua%.lua`, non `after[\/]ftplugin[\/]lua\.lua`; per più alternative, una sonda per ciascuna |
| In sessione, `print()` dentro uno snippet finisce sullo stdout dell'istanza persistente e **non torna al chiamante** | riporta attraverso lo stato: `vim.b.<nome>` letto con `vars`, oppure `vim.g.probe_note` riletto da una sonda successiva |
| `:normal <Space>ei` non preme il Leader: `:h :normal` mangia lo spazio iniziale dell'argomento | manda i tasti con `feedkeys` — cioè con `press` della sonda `keymap`, che usa `P.keys()`. Il `lhs` si scrive nella notazione della config (`<Leader>ei`): sia `maparg()` sia `P.keys()` la risolvono, e non va tradotta a mano in `<Space>` |
| In PowerShell le variabili sono case-insensitive: una locale `$json` **è** lo switch `-Json` dello script, e assegnarla lancia una conversione fallita al binding | dai alle locali un nome che non collida con i parametri (`$payload`) |
| Una funzione di comodo definita al volo per misurare può **coprire un alias**, e PowerShell esegue l'alias: una `function R($d)` viene risolta come `Invoke-History`, che risponde `Cannot locate the history for command line <path>`. L'errore nomina il path passato, quindi sembra un problema del filesystem o della directory | dai alle funzioni usa e getta un nome verbo-sostantivo (`Measure-Reads`), che nessun alias occupa; `Get-Alias <nome>` lo dice prima di perderci un giro |
| La sonda `lsp` aspetta il **primo** client e poi legge: dove due server si attaccano allo stesso buffer riporta quello arrivato per primo, e `clients = 2` fallisce a caso | passale un `before` che aspetta il numero voluto: `vim.wait(40000, function() return #vim.lsp.get_clients({ bufnr = 0 }) >= 2 end)` |
| `Start-Process -ArgumentList @('--cmd', 'set columns=200 lines=60', ...)` spezza l'argomento: Neovim apre un buffer chiamato `columns=200`, il file vero non viene mai caricato, e l'inventario risponde "nessun filetype" | passa a `-ArgumentList` **una stringa sola** già quotata, come fa `Format-Argv` in 'run.ps1'. E ripulisci lo swap che quel buffer fantasma lascia in `stdpath('data')/swap` |
| `globpath(&rtp, 'ftplugin/<ft>.{vim,lua}')` risponde vuoto su Windows: le graffe le espande la shell, e `cmd.exe` non le conosce | usa `'ftplugin/<ft>.*'`. Verificato con `-u NONE`, quindi non dipende dalla config |
| `vim.inspect(s:gsub(...))` lancia `attempt to index local 'options' (a number value)`: `gsub` ritorna **due** valori e il secondo finisce nel parametro `options` | metti la chiamata fra parentesi, `(s:gsub(...))` |
| Il watchdog di `run.ps1` uccide Neovim, **non il server di linguaggio che ha avviato**: dopo un giro di sonde su `jdtls` restavano due JVM vive, e `Get-Process nvim` diceva che era tutto pulito | a fine giro cerca anche il processo del server (`Get-CimInstance Win32_Process` per vedere la riga di comando), non solo `nvim` |
| `methods` della sonda `lsp` dice `false` per un server che registra le capability **dopo** l'attach (`client/registerCapability`), e il rapporto è identico a quello di una config rotta | passa `ready = true`, che aspetta la fine del caricamento prima di leggerle; senza, un client appena attaccato non ha ancora quasi niente |
| `vim.opt_local.errorformat:prepend()` **corrompe** l'opzione: `vim.opt` la tratta come una lista di elementi separati da virgola e spezza anche le virgole protette (`%l\,%c`), rimettendole insieme come voci nuove. Il risultato è `E372: Too many %f in format string` da un `errorformat` che funzionava | usa `vim.cmd('setlocal errorformat^=...')`, che passa dal parser di `:set` e rispetta l'escape; nel comando servono `\\` per il backslash e `\ ` per lo spazio |
| Un `%-G` aggiunto a un `errorformat` con messaggi multi-riga non "salta la riga e basta": **chiude il messaggio pendente**. Scartare i frame di stack dei framework per far cadere il `%Z` sul frame del progetto perde anche quel frame | non filtrare dentro un blocco multi-riga: se la voce giusta non si ottiene, il limite è del formato e va documentato, non aggirato |
| Un server interrogato in polling con `buf_request_sync` non finisce mai di caricarsi: `lua_ls` ha risposto `Workspace loading: 294 / 330` per tre minuti, mentre da solo chiude in trenta secondi | le richieste sincrone in ciclo affamano il caricamento. Aspetta una volta (`vim.wait`), poi manda **una** richiesta; il log dice quando il preload è finito (`$/progress` con `kind = "end"`, dopo `vim.lsp.log.set_level('debug')` su un buffer di altro filetype e `:edit` del file vero) |
| La sonda `highlight` non risponde per `ColorColumn`, `CursorLine`, `CursorColumn`, `Whitespace`: `vim.inspect_pos()` elenca capture, extmark e sintassi, cioè ciò che colora un *carattere*, mentre questi gruppi sono dipinti dal renderer anche su celle vuote | leggi il gruppo con `nvim_get_hl()` e riporta il contrasto contro `Normal` come numero; se serve la cella davvero disegnata, attacca una UI (`--embed` + `nvim_ui_attach`) e leggi il grid con `nvim__inspect_cell` |
| Un `:terminal` dentro un Neovim headless non produce nessuna cella: il buffer resta vuoto e l'output del figlio finisce sullo stdout del padre | non passare dal `:terminal` per vedere uno schermo; la via che funziona è la UI attaccata via RPC, con `ext_linegrid` **disattivo** (su v0.12.5 Windows fa uscire il figlio con exit 1) e `--listen` su TCP, non su named pipe |
| `buffer_state` legge `vars` **dal buffer corrente alla fine** dello snippet: uno snippet che passa da un buffer all'altro lascia le sue `vim.b.<nome>` sparse, e la sonda le riporta come non impostate | accumula in una tabella locale e scrivi **una** `vim.b.<nome>` alla fine, oppure usa `vim.g` |
| Con `scope = 'global'`, `Last set from` nomina l'ftplugin del file aperto anche quando il valore globale non è cambiato: un `:setlocal` registra comunque la provenienza per la voce globale. Sembra la prova della perdita che si sta cercando | guarda il **valore**, non l'origine: `foldmethod=indent` attribuito a 'after/ftplugin/markdown.lua' è sano, `foldmethod=expr` dallo stesso file no. Un ftplugin che scrive con `vim.wo[0][0]` finisce così in ogni caso |
| L'evidenza di `option_origin` stampa `Last set from` con i separatori di Windows, quindi un `expect` scritto con la barra normale non combacia mai e il `FAIL` sembra della config | scrivi il pattern sul solo nome del file (`ftplugin.lua%.lua`), che è l'unica parte stabile |
| La sonda `health` esce 1 da una fixture di progetto finta pur avendo passato tutti i suoi controlli: un server abilitato per quel filetype (`ts_ls`) fallisce `initialize` su un 'node_modules' vuoto, e il suo traceback arriva su stderr | leggi la riga `--- N lines, M failed` prima di credere all'exit code. Una fixture serve a far scattare un ramo del check, non a far partire i server: se anche quelli devono girare, il progetto deve essere vero |
| Una mapping che apre un picker non si verifica premendola: in headless lo stdin è a EOF, il ciclo di lettura tasti di 'mini.pick' finisce subito e il picker è già chiuso quando la sonda guarda. `MiniPick.is_picker_active()` risponde `false`, `after` vede il buffer di partenza, e il rapporto è identico a quello di una mapping che non fa niente | sostituisci `MiniExtra.pickers.<nome>` in `before` con uno stub che stampa i suoi `local_opts` e chiama `opts.source.choose(item)` su un item finto. È anche il controllo giusto: quello che la config decide è **cosa** passa al picker e cosa fa la scelta, non il picker |
| Un `choose` di 'mini.pick' che apre una finestra la apre dentro quella del picker: gira mentre il picker è ancora corrente (`:h MiniPick-source.choose`) | rimanda con `vim.schedule()`, oppure passa da `MiniPick.get_picker_state().windows.target`. Per verificarlo serve un `vim.wait()` dopo la scelta: senza, la sonda guarda prima che lo `schedule` sia girato |
| `MiniNotify.get_all()` è indicizzata per id, non è una lista: `ipairs` non la percorre e `table.sort` sul suo risultato confronta due `nil` | raccoglila con `pairs` in una lista di `{ id, msg }` e ordinala per id; è l'unico modo di leggere le notifiche nell'ordine in cui sono arrivate |
| Il server di linguaggio scrive nella **stessa** storia delle notifiche (`lua_ls: Loading workspace 0/231`), quindi "le note nuove dall'ultima volta" attribuisce i messaggi alla chiamata sbagliata e ogni etichetta risulta sfalsata di uno | scarta le note del server (`msg:find('^lua_ls')`) prima di leggerle, e aspetta il messaggio atteso invece di contarli |
| Uno snippet che prova più casi di seguito eredita la finestra che il caso precedente ha aperto: dopo un patch di `:Git`, `:only` tiene quella del patch, e la chiamata `buf_id = 0` che segue chiede del buffer `minigit://`. Risponde `Buffer is not a file on disk` — il warning giusto sul buffer sbagliato, indistinguibile da un guasto | salva il buffer di partenza e rimettilo (`nvim_win_set_buf`) alla fine di ogni caso, non solo `:only` |
| `Config.review.close()` cancella i buffer di cui 'mini.git' ha appena preso in carico lo stato: se il suo `update_git_status` schedulato non è ancora girato, stderr riceve `Invalid buffer id` con traceback, la sonda esce 1 e tutti i suoi controlli sono `PASS` - identico a una modifica che ha rotto qualcosa | è il ritmo della sonda, non la config: nessuno apre e chiude una review nello stesso tick. Lascia girare lo schedule prima di ogni chiusura (`vim.wait(700, function() return false end)`) e ripeti: se i traceback spariscono, erano quello |
| `vim.wo.<opzione>` su un'opzione di sola finestra scrive come `:set`, non come `:setlocal`: sposta anche il valore globale, e ogni finestra aperta dopo lo eredita. Con `after/ftplugin/java.lua` un `:new` dopo un buffer Java parte con `foldmethod=expr` e il `foldexpr` di tree-sitter, e `option_origin -scope global` lo attribuisce all'ftplugin | in un ftplugin usa `vim.wo[0][0].<opzione>`, che scrive come `:setlocal` e lega il valore al buffer dentro quella finestra (`:h vim.wo`). Il controllo che lo distingue è `before = "vim.cmd('new')"` con `scope = 'all'`: senza aprire una seconda finestra i due modi danno lo stesso rapporto. `vim.wo[win]` con l'id di una finestra **non** corrente resta invece locale (misurato: globale `noscrollbind` dopo la scrittura), quindi non è la stessa cosa e non va corretto |
| `:setlocal <opzione><` non ripristina "quello che c'era": rilegge il **globale**. Eseguito dopo un `:edit`, quindi dopo l'ftplugin del file appena caricato, annulla anche quello che l'ftplugin ha appena impostato - e il sintomo è invisibile, perché un `foldmethod=indent` piega comunque: a cambiare era il solo 'foldexpr' | confronta sempre con lo **stesso file aperto a mano** (due `buffer_state`, uno con `before`/`keys` e uno senza) invece di guardare se il valore è plausibile; e ricorda che un ripristino del genere va messo prima del `:edit`, non dopo |
| Il `find` delle sonde cerca **in avanti dal cursore** posato su (1,1), quindi un testo che sta sulla prima riga non viene mai trovato: la sonda `fold` risponde `FAIL \`class Prova\` found in the buffer / 0` su un buffer che quel testo ce l'ha | ancora il `find` a una riga che non sia la prima (`void f` invece di `class Prova`), oppure conta le righe della fixture prima di scriverlo |
| Nessuna sonda controlla la **forma** di un parametro, e PowerShell ne sbaglia due in silenzio. Una lista dove si vuole una stringa (`absent = @('vim')`, che con un elemento solo sembra innocua) fa stampare `no message matches \`table: 0x...\`` e dà un `PASS` che non ha controllato niente; un array dove si vuole una tabella indicizzata (`levels = @(1, 1)` invece di `@{ '0' = 1; '1' = 1 }`) diventa offset 1..N e produce `FAIL` su righe scelte a caso, identici a un `foldexpr` rotto | rileggi l'intestazione della sonda per la forma di ogni parametro, e prima di credere a un esito guarda cosa la riga cita: il pattern con `table: 0x...` dentro, o un `FAIL` sulla riga sbagliata, accusa la chiamata e non la config |
| La sonda `keymap` con `press` fotografa `after` subito dopo i tasti: per una mapping il cui effetto è asincrono (un `vim.system()`, uno `vim.schedule()`) il rapporto mostra `before` e `after` identici, indistinguibile da una mapping che non fa niente | leggi l'effetto nello snippet `after`, dopo un `vim.wait()` sulla condizione vera (`vim.fn.arglistid() ~= 0`). I `print()` di quello snippet escono su stderr **senza andare a capo**: il separatore va messo nella stringa |
| Modificare il `.nvim.lua` di un progetto **annulla la fiducia** di `:h 'exrc'`, che è un hash del contenuto indicizzato per **percorso assoluto** - quindi anche *spostare* il progetto la perde, con il file identico byte per byte (osservato spostando un checkout su un altro volume: la riga vecchia resta e non vale più per la nuova posizione, che va autorizzata a parte): da quel momento il file non viene più sorgentato e tutto ciò che impostava sparisce. In headless non c'è nessuna domanda: su stderr compare `exrc: Found untrusted code`, l'avvio prosegue, l'exit code resta 0 e la sonda accusa la modifica appena fatta invece della fiducia decaduta (misurato: `vim.env.JDTLS_JVM_ARGS` a `nil` con un hash alterato, il valore giusto dopo `:trust`) | dopo ogni edit di un file di progetto, `nvim --headless -u NONE <file> -c 'trust' -c 'qa!'` — `-u NONE` evita di leggerlo proprio mentre lo si autorizza — e conferma che `sha256sum` combacia con la sua riga in `stdpath('state')/trust` |
| Un `getSettings` di `jdtls` risponde anche quando l'import del build è **fallito**: il server ripiega su un progetto JDK nudo e riporta la *propria* release, che un runtime ce l'ha sempre. Una sonda che legge solo la compliance passa su un progetto in cui non è stato importato niente — diagnostiche comprese | chiedi prima `java.project.getAll`: lista vuota vuol dire che nessuna risposta del server viene dal build. È il controllo che la sonda `java_toolchain` fa per primo, e l'errore vero sta come diagnostica sul file di build |
| Gli shim di `mise` su Windows sono trampolini che rilanciano `mise.exe`, che **non** sta nella cartella degli shim (qui `...\WinGet\Links`): senza di lui `java --version` risponde `mise-shim: failed to execute mise: program not found` e non parte niente. Quindi un `mise` irraggiungibile non può spiegare un rapporto in cui `java` è OK e i JDK di `jdtls` mancano | quando la sezione Java di `:checkhealth config` dà `java` OK e insieme *no JDK of its own* / *told about no JDK at all*, l'ipotesi PATH è già esclusa dalla riga sopra: quello che è fallito è `mise ls java --json` in quel processo, e il valore resta in cache per tutta la sessione perché `vim.lsp.config` risolve una volta sola |
| Cercare i processi rimasti con `Get-CimInstance Win32_Process \| Where-Object { $_.CommandLine -match '<pattern>' }` trova **sé stesso**: la riga di comando di quel PowerShell contiene il pattern. Sembra un residuo che rinasce, con un PID diverso a ogni giro, e si finisce per ammazzare le proprie shell | filtra prima sul nome del processo (`-Filter "Name='java.exe'"`) e solo dopo sulla riga di comando; e prima di uccidere qualcosa guarda `CreationDate` e il padre, perché gli `nvim` dell'utente sono più vecchi del giro di sonde |
| Quello che dipende da un terminale vero è **inerte** in headless, e la sonda passa identica con o senza la modifica: `MiniMisc.setup_termbg_sync()` esce alla prima riga perché nessuna UI headless ha `stdout_tty`, quindi né il suo augroup né il suo warning esistono comunque | è il caso della Regola 3: la passata headless prova solo che l'avvio resta pulito, e il comportamento si consegna all'utente. Il campo che dice in anticipo se una verifica del genere ha senso è `stdout_tty` in `:h nvim_list_uis()` |
| `cat -A` e `grep` di Git Bash **tolgono il CR** di un file CRLF: la riga finisce con `$` invece che con `^M$`, il file sembra a LF e da lì lo si riscrive a LF, che è l'antipattern del line ending. `file` non lo rimedia: la stringa `with CRLF line terminators` la stampa solo per i tipi che **non** riconosce, e per un JSON, un INI o un file Lua scambiato per JavaScript non dice niente - il file sembra a LF anche quando non lo è | per un file tracciato la risposta è `git ls-files --eol`, che dice il fine riga nell'index (`i/`) e nel working tree (`w/`) di ognuno, e per uno solo `tr -cd` dei due caratteri dà i due totali (uguali se il file è coerente). Il conteggio va rifatto **dopo** aver scritto |
| `New-Item -ItemType SymbolicLink` risponde `Administrator privilege required` **anche con Developer Mode attivo** (`AllowDevelopmentWithoutDevLicense` a 1): `powershell` 5.1 non passa `SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE`, e il link della config (`~\AppData\Local\nvim`) non si ricrea. Sembra che serva una shell elevata, e non serve | invoca `pwsh` 7, che il flag lo passa: stesso comando, stesso utente non elevato, link creato. Le junction non sono toccate dal problema, il privilegio non gli è mai servito |
| `cmd_env` di un server LSP viene letto **solo se `cmd` è una lista**. Quando `cmd` è una funzione — `ts_ls` e `angularls` di 'nvim-lspconfig' lo sono — Neovim le passa i dispatcher e si fa da parte, e quella funzione chiude con `vim.lsp.rpc.start({ cmd, '--stdio' }, dispatchers)`, senza `extra_spawn_params`: la variabile resta nella config, `:=vim.lsp.config['<server>']` la mostra, e nel processo non arriva mai. Il rapporto è quindi *config giusta, nessun client* — che assomiglia a un file non letto | leggi `cmd` prima di credere a `cmd_env` (`:=vim.lsp.config['<server>'].cmd`, `<function 1>` è la risposta che conta). Se è una funzione, l'ambiente va passato scrivendo il proprio `cmd` con `vim.lsp.rpc.start(..., { env = … })`. La sonda che lo dice in un colpo è `lsp` con `server = '<nome>'` e uno `before` che stampa `cmd` e `cmd_env` |
| Un health check che chiede della radice del progetto con `vim.fs.root(0, …)` risponde sempre `nil`: `:checkhealth` apre **il proprio buffer di report** e ci esegue dentro i check, quindi il buffer 0 è uno scratch senza nome. Il ramo "non sei dentro un progetto" scatta sempre, e con lui spariscono i controlli che stavano lì sotto | parti dal buffer alternato (`vim.fn.bufnr('#')`), che è quello da cui si è arrivati. La cwd **non** è il ripiego che sembra: `MiniMisc.setup_auto_root()` la mette sulla radice del *repository*, e un progetto annidato (misurato: un progetto Angular quattro directory sotto il `.git` di un repo Maven) non si trova risalendo da lì |
| `P.wait_lsp()` non aspetta abbastanza per l'import di `jdtls`: risponde `workspace loaded` dopo 10 s mentre l'import Maven sta ancora girando, e `java_toolchain` riporta `the build was imported: none` su un progetto sano. L'accusa cade sulla config, che è a posto | prima di crederci, leggi il log del server — `stdpath('cache')/jdtls/workspace/<progetto>/.metadata/.log`: `Progressive import: reporting N new project(s)` senza errori Maven dice che l'import è passato e che a mentire è l'attesa. Su una workspace già costruita la sonda risponde giusto in 1 s, quindi la seconda esecuzione è essa stessa la misura |
| In PowerShell `-replace` è **case-insensitive**: un segnaposto `ROOT` interpolato in uno snippet Lua riscrive anche la variabile `root` che lo snippet usa, e quello che torna è `parameter <nome> does not compile / unexpected symbol near ':'` — che accusa il percorso Windows appena inserito, non la sostituzione | usa `-creplace`, o un segnaposto che nessun identificatore dello snippet contiene. Prima di indagare un errore di compilazione, **stampa lo snippet** che stai per passare: la riga citata dal messaggio è quella del testo finale, non del sorgente |
| Un import fallito di `jdtls` resta **cachato nella sua workspace**, e sistemare la configurazione non lo disfa: il server continua a rispondere da progetti senza source path — `java.project.listSourcePaths` vuoto, `java.project.getAll` vuoto e **zero diagnostiche** anche su un errore inserito apposta, cioè lo stato che si legge come "file corretto" | cancella `stdpath('cache')/jdtls/workspace/<progetto>` prima di rimisurare, insieme ai `*.lastUpdated` del repository Maven locale, che sopprimono il ritentativo di ogni download fallito |

## Antipattern

Errori già commessi in questo repository, con quello che sono costati. Non sono
ipotesi: sono il motivo per cui questa skill esiste.

| Antipattern | Cosa costa | Cosa fare invece |
|---|---|---|
| Cercare a tappeto sul filesystem (`find /`, `Get-ChildItem -Recurse` dalla radice) | due minuti di timeout e un processo orfano, per un file che stava in un posto noto | i plugin stanno in `stdpath('data')/site/pack/core/opt/`, la config è il link `~/AppData/Local/nvim`: parti da lì |
| Lasciare vivo il processo di un test | resta a girare per tutta la sessione, e lo scopre l'utente | usa `run.ps1`, che ha il watchdog; se lanci a mano, uccidi tu e poi verifica |
| Modificare un file con uno script che lo riscrive tutto (Python, `sed -i`) | line ending convertiti in silenzio. Con `core.autocrlf` **`git diff` resta pulito**: mostra solo le righe toccate mentre il file su disco è passato a LF, e a dirlo è solo il `warning: LF will be replaced by CRLF` sopra il diff | scrivi con il line ending del file: in Python `newline=''` **in scrittura non basta**, perché la lettura in modalità testo ha già convertito i CRLF in `\n` e li riscrive così. Serve `newline=''` **anche in lettura**, o si lavora in binario. Verifica contando i byte di fine riga o con `stylua --check`, non con `git diff --stat` |
| Cercare un blocco di testo senza la sua indentazione o senza il suo line ending | l'`assert` fallisce e si perde un giro a capire perché | normalizza (`replace('\r\n', '\n')`), edita, riconverti; e metti sempre un `assert` **prima** di scrivere |
| Filtrare l'output di una sonda (un `Select-String` sui soli `PASS` e `FAIL`, un `grep -E`) per accorciarlo | l'evidenza sta nella riga **indentata sotto** l'esito e non contiene nessuna di quelle parole: resta un `FAIL` senza il valore osservato, e si va a cercare nella config un guasto che l'evidenza avrebbe smentito in un colpo. Successo due volte in un giro solo, su `injected` e su `group` | leggi l'esito intero. Se è davvero troppo lungo, filtra con `-Context 0,1` |
| Guardare l'output e dire "sembra giusto" | quello che non torna è proprio quello che non si guarda | fai dire alla sonda `PASS`/`FAIL`, con l'evidenza accanto |
| Due passate di verifica perché la prima non copriva un caso | tempo doppio, e l'utente lo vede | elenca i casi **prima** (primo file, secondo file, dopo la chiusura), poi scrivi una sonda sola |
| Testare in una directory che non è un repository git, per una funzione git | ogni comando fallisce per il motivo sbagliato | verifica il presupposto per primo (`git -C <dir> rev-parse`), o usa questo repository |
| Prendere la baseline con `git checkout --` **del file che si sta modificando**, per una funzione che legge il working tree | il ripristino toglie l'unica modifica non committata che c'era, `:Git diff` non ha più nessuna hunk, il `<CR>` non apre niente e la sonda fotografa il buffer di partenza: un rapporto plausibile che non ha esercitato il percorso | la baseline di una funzione git si prende con il worktree separato e `-Appname` (vedi la riga sopra), che lascia il working tree dirty; e la sonda deve pretendere di essere arrivata da qualche parte (il nome del buffer, la riga del cursore), non solo leggere delle opzioni |
| Verificare un server LSP in una directory scratch senza root marker | il server si attacca e risponde alle richieste, ma resta in single-file mode e per certi server (`lua_ls`) non manda **nessuna** diagnostica: identico a una config sbagliata, e si indaga un guasto che non c'è | dai una radice alla directory di prova (`git init`) o verifica dentro questo repository, e conferma la root letta con `client.root_dir` |
| Implementare prima di aver deciso quale delle due letture della richiesta sia quella giusta | si verifica benissimo la cosa sbagliata | vedi Regola 1: se non sai cosa distinguerebbe il successo dal fallimento, chiedi |
| Prendere per guasto della config un'aspettativa sbagliata della sonda | si va a cercare un bug che non c'è | quando una sonda fallisce, il primo sospetto è il parametro che le hai dato (un `pattern` sensibile alle maiuscole, un server non abilitato) |
| Verificare N mapping con N esecuzioni della sonda `keymap` (una per `lhs`) | N avvii di Neovim per una domanda sola, e dopo una rinomina le mapping da controllare sono il doppio, perché vanno provate anche **assenti** quelle vecchie - cosa che la sonda `keymap` non sa dire, uscendo 1 sul `lhs` che non trova, indistinguibile da un guasto | un inventario in una sonda sola: uno snippet `before` che gira `maparg()` su tutte, presenti e assenti, accumula gli scarti e li lascia in una `vim.b.<nome>`, letta con `vars` e un `expect` che pretende la lista vuota. La sonda `keymap` resta quella giusta per **premere** una mapping, che è un caso per volta |
| Indagare un `FAIL` senza sapere se esisteva già prima della modifica | si cerca la causa nel proprio lavoro, dove non c'è | tieni una baseline accanto: `git worktree add --detach <tmp> HEAD`, una junction da `%LOCALAPPDATA%\nvim-baseline` alla sua `configs/nvim-0.12` e una da `nvim-baseline-data` a `nvim-data` (stessi plugin, nessun download), poi la stessa sonda con `-Appname nvim-baseline`. Due output affiancati dicono in un colpo solo se il comportamento è cambiato |

## Chiudere la verifica

Prima di dire che è finita:

- nessun processo lasciato in giro (`Get-Process nvim`, i job in background, e
  **il processo del server di linguaggio**, che sopravvive a Neovim);
- `git diff --stat` mostra solo quello che intendevi cambiare;
- `stylua --check <file>` dalla radice, sui file Lua toccati;
- l'esito è riportato per quello che è: se un controllo non è stato eseguito, si
  dice; se è fallito, si mostra l'output.

## Auto-miglioramento — a ogni test

**Ogni verifica è anche una verifica di questa skill.** All'inizio, le trappole e
gli antipattern qui sopra vanno **letti**, non ricordati; alla fine, ciò che la
sessione ha scoperto torna qui. Senza questo passo la conoscenza muore con la
sessione e la volta dopo si ripete lo stesso errore — che è esattamente come sono
nate le righe che stai leggendo.

Il lavoro è finito quando la skill è aggiornata, non quando il controllo è
passato.

**Cosa qualifica.** Il criterio è uno: *se l'avessi saputo prima di cominciare,
avrei verificato diversamente.* E deve essere **osservato** — un comando
eseguito, un output letto — non dedotto e non ricordato. In particolare:

- una sonda che ha **mentito**, o che si è rivelata insufficiente;
- un parametro che è servito e non c'era;
- un comportamento di Neovim, della shell o della macchina che ha fatto perdere
  un giro;
- un errore commesso durante la verifica, anche banale, **soprattutto** se
  banale: sono quelli che si ripetono.

**Dove va.**

| Cosa hai imparato | Dove va |
|---|---|
| Neovim, la shell o la macchina si comportano in modo non ovvio | tabella [Trappole](#trappole) |
| Un modo di procedere ha fatto perdere tempo o ha prodotto un esito falso | tabella [Antipattern](#antipattern) |
| Una sonda ha bisogno di un parametro, o un suo default è sbagliato | l'asset, insieme alla sua intestazione di documentazione |
| Serve un'operazione che nessuna sonda copre | una sonda nuova, aggiunta alla tabella delle operazioni; se ne sostituisce una, la vecchia si cancella |
| Riguarda **cosa** verificare in un linguaggio preciso | la reference di quel linguaggio in `nvim-language-support`, **mai** qui |

**Cosa non scrivere.** Questa skill è un indice, e un indice che registra tutto
non indicizza niente:

- il racconto della sessione: cosa è stato provato e in che ordine;
- ciò che il repository già dice (`AGENTS.md`, i commenti della config), che si
  richiama con un rimando e non si riassume;
- una regola dedotta e non osservata: scritta come fatto, è peggio del silenzio;
- una riga che ne ripete un'altra: si corregge quella, non se ne aggiunge una
  seconda che col tempo diverge.

L'aggiornamento di questa skill è **un commit a sé**, separato da quelli della
config: risolve un problema diverso, come chiede `AGENTS.md`.

## Reference

- `assets/run.ps1` — il driver, con la documentazione dei suoi parametri in testa.
- `assets/lib.lua` — la libreria condivisa dalle sonde.
- `assets/<operazione>.lua` — le sonde; l'intestazione di ognuna documenta i suoi
  parametri e il motivo per cui esiste.
