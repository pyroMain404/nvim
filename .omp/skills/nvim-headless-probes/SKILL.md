---
name: nvim-headless-probes
description: Use when writing or running a headless Neovim probe with run.ps1 or lib.lua (win_layout, keymap, lsp, quickfix and the other probes), reading probe output, or encountering a probe-bench trap. Points to nvim-shell-traps for Windows/shell traps and nvim-runtime-traps for Neovim/plugin traps. Use for "sonda headless", "esegui una sonda", "leggi l’output della sonda", or "trappola headless".
---

# Le sonde headless

Cosa verificare e quando sta in `nvim-config-testing`; qui c'è come.

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
assets/run.ps1 <sonda> -File <file> -Params @{ ... }

# Il caso vero da cui è nato questo banco: dove finiscono le finestre quando si
# aprono tre file di seguito da un patch di `:Git diff`
assets/run.ps1 win_layout -File README.md -Params @{
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
`-Cwd`, `-Appname`, `-Clean`, `-Show`, più `-Session` / `-Reset` /
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
$R = 'assets/run.ps1'
& $R lsp_request -File 'plugin/20_keymaps.lua' -Session lua `
    -Cwd $repo -Reset -Params @{ find = "^nmap_leader\('ba'"; count = 2 }
& $R diagnostics -File 'lua/config/health.lua' -Session lua `
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
Le trappole Windows/shell sono in `nvim-shell-traps`, quelle Neovim/plugin in `nvim-runtime-traps`.

| Trappola | Rimedio |
|---|---|
| `nvim --headless -l script.lua` **non carica `init.lua`**: niente plugin, niente autocomandi, e ogni attesa di un evento va in timeout | non usare `-l`: apri il file come argomento e inietta il codice con `-S`, che è quello che fa `run.ps1` |
| Il codice dentro `Config.later()` parte su un timer dopo l'avvio: un `+qa` immediato esce prima che sia mai girato | `P.run()` aspetta `wait` ms; alzalo quando il pezzo dipende da un plugin da scaricare |
| L'exit code è 0 anche quando un `setup()` lancia un errore | fai fallire esplicitamente (`cquit`) e leggi anche stderr: `run.ps1` cerca `Failed to run` e i traceback |
| Headless parte a 80x24, e ogni misura di layout è falsa | `-Columns` / `-Lines`, già impostati a 200x60 |
| All'avvio `v:errmsg` contiene `Couldn't find a watcher matching key and callback`, e la sonda `startup` fallisce | non viene dalla modifica: è `MiniMap.gen_integration.builtin_search()` che al caricamento esegue `silent! call dictwatcherdel(v:, 'hlsearch', ...)` su un watcher che la prima volta non esiste. Il messaggio è di `dictwatcherdel()`, e `silent!` lo nasconde all'utente ma **non azzera `v:errmsg`**. Compare solo dopo i `later()` (misurato: assente con `-Wait 0`, presente a 327 ms): passa `allow = @('watcher matching key')` |
| La sonda `command` esegue `after` solo quando le è stato dato anche `run` | uno snippet che deve girare comunque va passato come `before` |
| `--startuptime` produce righe a due e a tre colonne, con la prima cumulativa | ordinare tutto insieme mette in cima la fine dell'avvio: classifica solo le righe "sourcing" |
| `nvim --server ... --remote-expr` senza `--headless` **sul client** restituisce il valore sepolto nelle sequenze di escape del terminale | `--headless` anche sul client: `Invoke-Remote` in 'run.ps1' lo fa |
| Aprire un file cambia la directory corrente (`MiniMisc.setup_auto_root()` in 'plugin/30_mini.lua'), quindi un path relativo significa un'altra cosa alla sonda successiva | passa path assoluti; in sessione il driver li rende assoluti da solo |
| Il parametro `find` è una **regexp di Vim**, non un pattern Lua: lì `(` è letterale e `\(` apre un gruppo — un pattern sbagliato lancia `E54` | scrivi `^nmap_leader('ba'`, non `^nmap_leader\('ba'`; la sonda riporta l'errore come parametro invalido, non come guasto |
| Il parametro `expect` — e `pattern` della sonda `quickfix`, che è lo stesso caso — è un **pattern Lua**, non una regexp: `\.` non è un punto letterale e l'alternanza `a|b` non esiste (`|` è un carattere qualsiasi), così un pattern scritto con la sintassi delle regex non aggancia mai e il `FAIL` accusa la config invece del pattern | usa la sintassi Lua: `textwidth=85 .*after.ftplugin.lua%.lua`, non `after[\/]ftplugin[\/]lua\.lua`; per più alternative, una sonda per ciascuna |
| In sessione, `print()` dentro uno snippet finisce sullo stdout dell'istanza persistente e **non torna al chiamante** | riporta attraverso lo stato: `vim.b.<nome>` letto con `vars`, oppure `vim.g.probe_note` riletto da una sonda successiva |
| La sonda `lsp` aspetta il **primo** client e poi legge: dove due server si attaccano allo stesso buffer riporta quello arrivato per primo, e `clients = 2` fallisce a caso | passale un `before` che aspetta il numero voluto: `vim.wait(40000, function() return #vim.lsp.get_clients({ bufnr = 0 }) >= 2 end)` |
| Il watchdog di `run.ps1` uccide Neovim, **non il server di linguaggio che ha avviato**: dopo un giro di sonde su `jdtls` restavano due JVM vive, e `Get-Process nvim` diceva che era tutto pulito | a fine giro cerca anche il processo del server (`Get-CimInstance Win32_Process` per vedere la riga di comando), non solo `nvim` |
| `methods` della sonda `lsp` dice `false` per un server che registra le capability **dopo** l'attach (`client/registerCapability`), e il rapporto è identico a quello di una config rotta | passa `ready = true`, che aspetta la fine del caricamento prima di leggerle; senza, un client appena attaccato non ha ancora quasi niente |
| La sonda `highlight` non risponde per `ColorColumn`, `CursorLine`, `CursorColumn`, `Whitespace`: `vim.inspect_pos()` elenca capture, extmark e sintassi, cioè ciò che colora un *carattere*, mentre questi gruppi sono dipinti dal renderer anche su celle vuote | leggi il gruppo con `nvim_get_hl()` e riporta il contrasto contro `Normal` come numero; se serve la cella davvero disegnata, attacca una UI (`--embed` + `nvim_ui_attach`) e leggi il grid con `nvim__inspect_cell` |
| `buffer_state` legge `vars` **dal buffer corrente alla fine** dello snippet: uno snippet che passa da un buffer all'altro lascia le sue `vim.b.<nome>` sparse, e la sonda le riporta come non impostate | accumula in una tabella locale e scrivi **una** `vim.b.<nome>` alla fine, oppure usa `vim.g` |
| Con `scope = 'global'`, `Last set from` nomina l'ftplugin del file aperto anche quando il valore globale non è cambiato: un `:setlocal` registra comunque la provenienza per la voce globale. Sembra la prova della perdita che si sta cercando | guarda il **valore**, non l'origine: `foldmethod=indent` attribuito a 'after/ftplugin/markdown.lua' è sano, `foldmethod=expr` dallo stesso file no. Un ftplugin che scrive con `vim.wo[0][0]` finisce così in ogni caso |
| L'evidenza di `option_origin` stampa `Last set from` con i separatori di Windows, quindi un `expect` scritto con la barra normale non combacia mai e il `FAIL` sembra della config | scrivi il pattern sul solo nome del file (`ftplugin.lua%.lua`), che è l'unica parte stabile |
| La sonda `health` esce 1 da una fixture di progetto finta pur avendo passato tutti i suoi controlli: un server abilitato per quel filetype (`ts_ls`) fallisce `initialize` su un 'node_modules' vuoto, e il suo traceback arriva su stderr | leggi la riga `--- N lines, M failed` prima di credere all'exit code. Una fixture serve a far scattare un ramo del check, non a far partire i server: se anche quelli devono girare, il progetto deve essere vero |
| Uno snippet che prova più casi di seguito eredita la finestra che il caso precedente ha aperto: dopo un patch di `:Git`, `:only` tiene quella del patch, e la chiamata `buf_id = 0` che segue chiede del buffer `minigit://`. Risponde `Buffer is not a file on disk` — il warning giusto sul buffer sbagliato, indistinguibile da un guasto | salva il buffer di partenza e rimettilo (`nvim_win_set_buf`) alla fine di ogni caso, non solo `:only` |
| Il `find` delle sonde cerca **in avanti dal cursore** posato su (1,1), quindi un testo che sta sulla prima riga non viene mai trovato: la sonda `fold` risponde `FAIL \`class Prova\` found in the buffer / 0` su un buffer che quel testo ce l'ha | ancora il `find` a una riga che non sia la prima (`void f` invece di `class Prova`), oppure conta le righe della fixture prima di scriverlo |
| Nessuna sonda controlla la **forma** di un parametro, e PowerShell ne sbaglia due in silenzio. Una lista dove si vuole una stringa (`absent = @('vim')`, che con un elemento solo sembra innocua) fa stampare `no message matches \`table: 0x...\`` e dà un `PASS` che non ha controllato niente; un array dove si vuole una tabella indicizzata (`levels = @(1, 1)` invece di `@{ '0' = 1; '1' = 1 }`) diventa offset 1..N e produce `FAIL` su righe scelte a caso, identici a un `foldexpr` rotto | rileggi l'intestazione della sonda per la forma di ogni parametro, e prima di credere a un esito guarda cosa la riga cita: il pattern con `table: 0x...` dentro, o un `FAIL` sulla riga sbagliata, accusa la chiamata e non la config |
| I parametri di ricerca delle sonde (`expect`, `absent`, `pattern`, `allow`) sono **pattern Lua**, non regex: sono passati a `string.find()`. `C\+\+17` non trova `a C++17 extension` — in un pattern Lua l'escape è `%`, quindi `\+` significa "un backslash seguito da un carattere qualsiasi" — e `\.` in `compiler[\\/]cmake\.lua` non trova `compiler\cmake.lua`. Il rapporto è un `FAIL` con accanto l'evidenza che contiene proprio la stringa cercata: si legge come un guasto della config, ed è la sonda a chiedere la cosa sbagliata | scrivi `C%+%+17`, `compiler.cmake%.lua`, `^path=%.,,`. Il segnale che accusa la chiamata invece della config è l'evidenza stampata sotto il `FAIL`: se contiene il testo che il pattern doveva trovare, il pattern è sbagliato |
| La sonda `keymap` con `press` fotografa `after` subito dopo i tasti: per una mapping il cui effetto è asincrono (un `vim.system()`, uno `vim.schedule()`) il rapporto mostra `before` e `after` identici, indistinguibile da una mapping che non fa niente | leggi l'effetto nello snippet `after`, dopo un `vim.wait()` sulla condizione vera (`vim.fn.arglistid() ~= 0`). I `print()` di quello snippet escono su stderr **senza andare a capo**: il separatore va messo nella stringa |
| `P.wait_lsp()` non aspetta abbastanza per l'import di `jdtls`: risponde `workspace loaded` dopo 10 s mentre l'import Maven sta ancora girando, e `java_toolchain` riporta `the build was imported: none` su un progetto sano. L'accusa cade sulla config, che è a posto | prima di crederci, leggi il log del server — `stdpath('cache')/jdtls/workspace/<progetto>/.metadata/.log`: `Progressive import: reporting N new project(s)` senza errori Maven dice che l'import è passato e che a mentire è l'attesa. Su una workspace già costruita la sonda risponde giusto in 1 s, quindi la seconda esecuzione è essa stessa la misura |
| La sonda `command` con `run` **esegue davvero** ciò che il comando fa, e per un comando che avvia un'applicazione (`:Run` di 'after/ftplugin/java.lua') quello che partirebbe è l'applicazione, dentro un Neovim che il watchdog uccide poco dopo | verifica **quale** comando sarebbe partito, non l'applicazione: nello `before` sostituisci `vim.fn.jobstart` (o `vim.system`) con uno stub che ne registra gli argomenti in una `vim.g.<nome>`, e leggila in `after`. L'assegnazione a `vim.fn.<nome>` funziona — verificato con `-u NONE` — ed è ciò che rende falsificabile la scelta del comando: tre fixture, tre `PROBE_CMD` diversi. Vale anche per un `:make` che gira a lungo |

## Reference

- `assets/run.ps1` — il driver, con la documentazione dei suoi parametri in testa.
- `assets/lib.lua` — la libreria condivisa dalle sonde.
- `assets/<operazione>.lua` — le sonde; l'intestazione di ognuna documenta i suoi
  parametri e il motivo per cui esiste.
- `../nvim-shell-traps/SKILL.md` — le trappole Windows, shell e strumenti.
- `../nvim-runtime-traps/SKILL.md` — le trappole di Neovim e dei plugin.
