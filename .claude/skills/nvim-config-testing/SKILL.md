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
`-Cwd`, `-Appname`, `-Clean`, `-Json`, `-Show`.

Parametri che tutte le sonde leggono: `wait` (come `-Wait`) e `json`. Quasi
tutte accettano inoltre uno **snippet Lua** come parametro (`before`, `between`,
`after`): è quello che le rende riusabili, perché lo stato da cui parte la
verifica è un dato, non l'ennesima copia della sonda.

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
| `quickfix` | `:make` produce voci navigabili? | `make`, `makeprg`, `errorformat`, `min`, `pattern` |
| `health` | `:checkhealth` in forma che uno script può far fallire | `sections`, `fail_on`, `allow`, `show` |
| `startuptime` | quanto costa l'avvio, file per file? | `file`, `budget`, `top`, `filter` |

L'intestazione di ogni file dice cosa fa, perché, e documenta tutti i suoi
parametri: leggila prima di aggiungerne uno, e aggiungilo lì quando manca.

`option_origin` e `lsp` meritano una nota, perché rispondono a **quasi ogni**
guasto di questa config: la prima (`:verbose set`) è l'unica che nomina il file
responsabile, la seconda distingue "non attaccato" da "non ancora attaccato". La
maggior parte dei problemi qui è un livello che ne ha sovrascritto un altro.

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
| `stylua --check` va eseguito **dalla radice del repository** | StyLua cerca `.stylua.toml` a partire dalla directory corrente: da altrove applica i suoi default (tab, doppi apici) e il diff non significa niente |
| Un file scritto con line ending LF fa segnalare a StyLua **l'intero file** | il repo è CRLF (`line_endings = "Windows"` più `core.autocrlf`): converti prima di rileggere il diff |
| Le heredoc di Bash su questa macchina collassano `\\` in `\`, e un `'\''` dentro una stringa Python la tronca | non generare file con backslash da script (usa `vim.fs.dirname`, `[char]92`), e rileggi sempre la riga scritta |
| `Start-Process -ArgumentList` unisce gli argomenti con uno spazio e non ne quota nessuno | un argomento con spazi arriva spezzato: quotalo tu (`Format-Argv` in `run.ps1`) |
| `--startuptime` produce righe a due e a tre colonne, con la prima cumulativa | ordinare tutto insieme mette in cima la fine dell'avvio: classifica solo le righe "sourcing" |

## Antipattern

Errori già commessi in questo repository, con quello che sono costati. Non sono
ipotesi: sono il motivo per cui questa skill esiste.

| Antipattern | Cosa costa | Cosa fare invece |
|---|---|---|
| Cercare a tappeto sul filesystem (`find /`, `Get-ChildItem -Recurse` dalla radice) | due minuti di timeout e un processo orfano, per un file che stava in un posto noto | i plugin stanno in `stdpath('data')/site/pack/core/opt/`, la config è il link `~/AppData/Local/nvim`: parti da lì |
| Lasciare vivo il processo di un test | resta a girare per tutta la sessione, e lo scopre l'utente | usa `run.ps1`, che ha il watchdog; se lanci a mano, uccidi tu e poi verifica |
| Modificare un file con uno script che lo riscrive tutto (Python, `sed -i`) | line ending convertiti in silenzio: `git diff` mostra il file intero e StyLua urla | dopo **ogni** modifica scriptata, `git diff --stat` deve mostrare solo le righe toccate |
| Cercare un blocco di testo senza la sua indentazione o senza il suo line ending | l'`assert` fallisce e si perde un giro a capire perché | normalizza (`replace('\r\n', '\n')`), edita, riconverti; e metti sempre un `assert` **prima** di scrivere |
| Guardare l'output e dire "sembra giusto" | quello che non torna è proprio quello che non si guarda | fai dire alla sonda `PASS`/`FAIL`, con l'evidenza accanto |
| Due passate di verifica perché la prima non copriva un caso | tempo doppio, e l'utente lo vede | elenca i casi **prima** (primo file, secondo file, dopo la chiusura), poi scrivi una sonda sola |
| Testare in una directory che non è un repository git, per una funzione git | ogni comando fallisce per il motivo sbagliato | verifica il presupposto per primo (`git -C <dir> rev-parse`), o usa questo repository |
| Implementare prima di aver deciso quale delle due letture della richiesta sia quella giusta | si verifica benissimo la cosa sbagliata | vedi Regola 1: se non sai cosa distinguerebbe il successo dal fallimento, chiedi |
| Prendere per guasto della config un'aspettativa sbagliata della sonda | si va a cercare un bug che non c'è | quando una sonda fallisce, il primo sospetto è il parametro che le hai dato (un `pattern` sensibile alle maiuscole, un server non abilitato) |

## Chiudere la verifica

Prima di dire che è finita:

- nessun processo lasciato in giro (`Get-Process nvim`, e i job in background);
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
