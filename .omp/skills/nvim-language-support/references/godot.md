# Godot 4 / GDScript

L'esito delle Fasi 1 e 2 per GDScript, già svolte e verificate su questa macchina
(Neovim 0.12.5, Windows, Godot 4.7.2-stable e GDScript Toolkit 4.5.0, entrambi da
`mise`). Le fasi successive seguono la procedura di `SKILL.md`; qui c'è solo ciò che
è specifico della piattaforma.

L'analisi funzionale da cui nasce l'implementazione sta nel repository della config
(`docs/analisi_funzionale_godot.md`): quella dice *perché* ogni asse è stato scelto,
questa dice *cosa è risultato vero* eseguendola.

**L'ambito è GDScript.** Il C++ di GDExtension eredita tutto da `cpp.md`, e ciò che
gli è proprio — il riconoscimento di `.gdextension`, il `compile_commands.json` che
per `godot-cpp` nasce da SCons — resta fuori finché non entra.

## 1. Fase 1 — cosa il runtime dà già

Aprendo un `.gd` dentro una directory con `project.godot`, e leggendo con
`:verbose setlocal`, che nomina il file responsabile:

| Cosa | Dettaglio |
|---|---|
| Filetype | `.gd` → `gdscript`, `.gdshader` → `gdshader`, `.tscn` e `.tres` → `gdresource`. **`.gdshaderinc` e `.gdextension` non sono riconosciuti** |
| Commenti | `commentstring=# %s` da `$VIMRUNTIME/ftplugin/gdscript.vim:24` |
| Indentazione | `noexpandtab`, `tabstop=4`, `shiftwidth=0` dallo stesso file, riga 29. `shiftwidth=0` non è un'omissione: fa seguire l'indentazione a `tabstop`, e i tab sono ciò che Godot raccomanda |
| `gf` | `suffixesadd=.gd` (riga 23) |
| Rientro e fold | `indentexpr=<SNR>_GDScriptIndent()` da `$VIMRUNTIME/indent/gdscript.vim:26`, più un `foldexpr` con `foldmethod=indent` dal ftplugin |
| `makeprg`, `errorformat` | **vuoti**: nessun compiler plugin viene scelto, e non ne esiste uno per Godot fra i 135 di `getcompletion('', 'compiler')` |

Il livello dei plugin già installati, che qui vale più del runtime — ed è la metà
che una stesura dell'analisi aveva dato per nota invece di misurare, sbagliando due
assi su tredici:

| Livello | Cosa dà |
|---|---|
| 'nvim-lspconfig' | `lsp/gdscript.lua`: `cmd` **funzione** costruita con `vim.lsp.rpc.connect('127.0.0.1', GDScript_Port or 6005)`, `filetypes = { 'gdscript' }`, `root_markers = { 'project.godot', '.git' }`. È l'**unico** file di tutto il plugin che usa `rpc.connect` invece di `rpc.start` (`capabilities.md` §17) |
| 'nvim-treesitter' | parser `gdscript` disponibile e non installato, **tier 3** (nessun `maintainers` in 'parsers.lua'). `gdshader` dichiara i filetype `gdshader` **e** `gdshaderinc`, `godot_resource` dichiara `godot_resource` e `gdresource`: la tabella di 'plugin/filetypes.lua' è additiva rispetto al nome del parser, non sostitutiva |
| 'friendly-snippets' | **25 snippet già attivi** da `snippets/gdscript.json`, cinque dei quali espandono sintassi Godot 3 |
| 'conform.nvim' | conosce già `gdformat` ed esegue su stdin: `available=false` solo perché il binario mancava |

## 2. Fase 2 — cosa di questo tenere

**Tutto ciò che il runtime imposta come opzione**, senza eccezioni: sono le leve su
cui poggiano 'mini.comment' (`commentstring`), `gf` (`suffixesadd`), l'indentazione e
i fold. Nessun `after/ftplugin/gdscript.lua` le tocca.

Il `syntax/gdscript.vim` del runtime resta sotto al parser e qui conta più del
solito, perché il parser è **tier 3**: senza manutentore dichiarato, il fallback è
una rete e non un residuo.

**'godotdev.nvim' valutato sul sorgente e non adottato.** Su Windows sostituisce il
`cmd` ereditato con `{ 'ncat', host, port }` — un programma che qui non esiste, per
fare ciò che libuv fa da sé — usa l'API `master` di 'nvim-treesitter' dentro un
`pcall` (questa config è su `main`, dove `configs.lua` non esiste: fallisce in
silenzio), formatta a ogni `:w` con un formatter diverso, e mette `.git` fra i
`root_markers`. Non copre snippet, quickfix né `ftdetect`. Ma quattro assi che la
skill non aveva vengono da lì: `capabilities.md` §17, §18 e §19.

## 3. Fase 4 — toolchain

```powershell
mise use -g godot@4                  # il default della macchina
mise use -g pipx:gdtoolkit@4.5.0     # gdformat, e con lui gdlint, gdparse, gdradon
mise use godot@4.5.1-stable          # dentro un gioco: la versione è del progetto
```

`mise` e non WinGet, ed è la regola e non l'eccezione: un gioco resta sulla versione
con cui è stato scritto, e aprirlo con una più nuova ne converte i file. Il registry
conosce già il motore (`mise registry godot` → `aqua:godotengine/godot`), quindi non
serve nessun `[alias]` verso un plugin `asdf`.

Tre conseguenze misurate:

- l'install contiene l'eseguibile **completo**, editor grafico incluso: `--headless`
  è una scelta di riga di comando, non un pacchetto diverso. Sono ~360 MB per
  versione dichiarata;
- `mise ls-remote godot` elenca solo le `-stable`, e **nessuna variante .NET/Mono**:
  un gioco in C# non si serve da qui;
- **lo shim risolve la versione dalla directory corrente.** Fuori da qualunque
  dichiarazione risponde `mise ERROR No version is set for shim: godot` ed esce 1,
  mentre `vim.fn.executable('godot')` vale comunque 1. È il motivo per cui l'health
  check separa la presenza dalla versione (§7).

## 4. Fase 5 — cosa implementare

```text
configs/nvim-0.12/
├── plugin/40_plugins.lua           'gdscript' in languages, in vim.lsp.enable(), in formatters_by_ft, BufReadCmd su res://
├── after/lsp/gdscript.lua          solo root_markers
├── after/snippets/gdscript.json    correzione dei cinque prefissi Godot 3
├── after/ftplugin/gdscript.lua     :make dalla radice, :Run, :GodotDoc, :GodotReconnect
├── compiler/godot.lua              makeprg ed errorformat
└── lua/config/health.lua           check_godot()
```

### 4.1 Il server appartiene all'editor Godot

È il caso completo di `capabilities.md` §17, e l'unico di questa config. Quello che
va scritto è **solo** `root_markers = { 'project.godot' }`: una lista è un valore e
viene sostituita intera, quindi il `.git` ereditato sparisce — ed è ciò che conta,
perché con lui un `.gd` qualunque dentro un repository qualunque si attacca al Godot
che sta girando e risponde con i simboli di un altro gioco.

`cmd` non si scrive **mai** qui: è la funzione che apre il socket.

### 4.2 Build: `:make` controlla un file, non il progetto

`compiler/godot.lua`, con

```text
makeprg=godot --headless --path . --check-only $* --script %:p:S
errorformat=%ESCRIPT ERROR: %m,%Z%.%#(res://%f:%l),%-G%.%#
```

Quattro cose che la misura ha deciso, e nessuna è deducibile:

- **`--check-only` senza `--script` non risponde** (`Couldn't detect whether to run
  the editor, the project manager or a specific project`, exit 1). Quindi `:make`
  controlla il file del buffer, e "questo progetto compila?" non è una domanda che il
  motore risponda da riga di comando: niente equivalente di `cargo check`;
- **è un controllo di parsing, non di tipi.** `n.no_such_method()` su un `int`: nessun
  output, **exit 0**. La diagnostica semantica viene solo dal server, cioè solo con
  l'editor aperto. Va detto all'utente, perché una quickfix vuota qui promette meno
  di quanto sembri;
- il candidato scartato era `--editor --quit`, che guarda il progetto intero: non
  nomina il file rotto, esce comunque 0, e colora ogni riga senza chiedere;
- **file e riga stanno sulla riga successiva al messaggio**, quindi `%E`…`%Z`. I due
  spazi di `SCRIPT ERROR: ` vanno scritti `\ ` perché `CompilerSet` è un `:set`; una
  troncatura lì lascia la quickfix vuota, che si legge come "il file si parsa".
  Nessun `%c`: il motore dà file e riga e basta.

**`:make` deve partire dalla radice del progetto**, e il perché, la forma e le due
trappole (gli eventi quickfix non sono buffer-local; `vim.fn.chdir()` e non `:lcd`)
stanno in `capabilities.md` §6, dove valgono per qualunque strumento con percorsi
relativi a un manifesto. `--path` da solo non basta: parla al motore, non a Neovim.

### 4.3 Il resto del buffer

- **`:Run`** è `godot --path <root>` più gli argomenti, quindi
  `:Run res://main.tscn` avvia una scena. Il default non si legge: lo legge il
  motore (`run/main_scene`), e un progetto che non ne dichiara rifiuta con
  `Can't run project: no main scene defined in the project` ed esce 1 — il
  fallimento rumoroso che il contratto chiede, e che arriva all'utente solo
  perché il ramo staccato riporta l'uscita anomala. Due misure che servono a non
  farsi ingannare: quel messaggio il motore lo scrive su **stdout** (65 byte lì e
  0 su stderr, sullo stesso comando che da shell lo stampa a schermo), e il
  motore, eseguendo un progetto su Windows, gira in **due** processi — contarli
  per sapere se il gioco è vivo risponde 2.
  **Staccato**, che è il ramo di `capabilities.md` §19 per un programma con
  finestra propria, ed è una misura e non una preferenza: invocato nella forma
  catturata, il gioco apre un `buftype=terminal` con un job vivo il cui buffer
  resta **vuoto**, mentre l'output esce sullo stdout del processo Neovim — in
  sessione, lo schermo su cui l'interfaccia è disegnata. Attenzione al controllo
  che sembra equivalente e non lo è: `godot --path . | cat` da una shell mostra
  `print()` nella pipe e legittimerebbe la forma sbagliata. Il prezzo del ramo
  staccato è che il gioco sopravvive a `:qa`, ed è il verso giusto: chiudere
  l'editor non è una ragione per uccidere ciò che sta girando.
- **`:GodotDoc`** apre `docs.godotengine.org/en/stable/search.html?q=<cword>`. La
  forma `classes/class_<nome>.html`, che è quella di ogni ricetta in giro, è un
  colpo diretto per una classe e una 404 per tutto il resto — e la maggior parte
  delle parole sotto il cursore non sono classi: `move_and_slide`, `velocity`,
  `PROCESS_MODE_ALWAYS` non hanno una pagina propria mentre la ricerca li trova.
  `stable` è la documentazione dell'ultimo motore rilasciato, non di quello che il
  gioco pinna: la divergenza non ha sintomi.
- **`:GodotReconnect`** fa `:edit`, che ripassa da `FileType` e rifà scattare
  l'attach. È l'unica "riprova" che esiste dopo aver riavviato l'editor
  (`capabilities.md` §17, punto 4). Rifiuta su un buffer modificato invece di
  perderne il contenuto.

### 4.4 `gf` su `res://`

Il progetto era deciso, non scritto: due misure mancavano, ed entrambe hanno cambiato
l'implementazione rispetto a quanto previsto.

**`:` non è in `isfname` di default** (misurato). Senza estenderlo, `gf` con il
cursore su "res" — a sinistra dei due punti — cattura solo `res` e cerca un file con
quel nome. `vim.opt_local.isfname:append(':')` rende `res://scripts/x.gd` una parola
sola qualunque sia la posizione del cursore al suo interno.

**`includeexpr` non entra mai in gioco, ed è un fatto di Vim, non di GDScript.**
`:h 'includeexpr'` promette che `gf` lo consulti "se un nome non modificato non si
trova". Misurato: `findfile('res://scripts/x.gd')` restituisce la stringa
**invariata**, come se il file esistesse, invece di stringa vuota — confermato contro
un nome senza alcuna corrispondenza possibile, che risponde correttamente `''`. Vim
tratta qualunque cosa contenga `"://"` come uno schema di rete e non la verifica sul
filesystem, quindi la condizione "non trovato" da cui dipende `includeexpr` non
scatta mai. Vale per qualunque `schema://` in qualunque linguaggio, non solo per
Godot: registrato in `capabilities.md` §8.

La correzione è la stessa di `jdt://` (`capabilities.md` §8): un `BufReadCmd` sullo
schema, in `plugin/40_plugins.lua` — non nel ftplugin, perché deve esistere **prima**
che un `gf` apra quel buffer, non dopo. Intercetta il nome fittizio, risolve la radice
dal buffer alternato o dalla cwd, apre il file vero e cancella il buffer fantasma.
Fuori da un progetto Godot degrada con un `vim.notify` invece di aprire qualcosa.

**L'autocomando deve essere `nested`, e senza il flag il guasto non si vede.** Gli
autocomandi non ne innescano altri (`:h autocmd-nested`), quindi il `:edit` che il
callback esegue girava con gli eventi bloccati: il buffer risolto prendeva il testo e
nient'altro. Misurato prima in un Neovim isolato — `nested = false` dà `filetype=""` e
nessun `BufReadPost` né `FileType`, `nested = true` dà `gdscript` con entrambi — e poi
in A/B contro la configurazione precedente, sullo stesso `gf` della stessa fixture:
`filetype` vuoto, cursore `(1,0)`, zero client LSP e nessun comando del ftplugin, contro
`gdscript` con l'highlight del parser, la posizione che `MiniMisc.setup_restore_cursor()`
ricorda, un client `gdscript` e `:make` / `:Run` / `:GodotDoc` presenti. Nello stesso
A/B la rotta non `nested` si interrompeva con `Vim:E325` quando un'altra istanza di
Neovim teneva aperto il file di destinazione, e quella corretta no: la correzione vale
quindi anche per un `gf` su un file che qualcun altro ha in editing.

`include` resta impostato per `[i`/`[I`/`:checkpath`, ma lo stesso schema-recognition
di Vim li fa dichiarare "trovato" senza verificare nulla: utile da sapere, non un
difetto da correggere qui.

### 4.5 Snippet: già attivi e già sbagliati

L'asse con il rapporto costo/beneficio migliore, e quello che si archivia per errore
come "non serve ora". Cinque prefissi di 'friendly-snippets' producono codice che
Godot 4 rifiuta: `class` (`Reference`), `export` (`export(type) … setget`), `var`
(`setget`), `onready` (senza `@`), `inpute` (firma di `_input_event` cambiata).

In `after/snippets/gdscript.json`: stesso prefisso **vince**, un prefisso senza
`body` **rimuove**. Verificato dopo: 24 snippet invece di 25, i quattro corretti
espandono sintassi Godot 4, `inpute` non espande più niente.

**Il `$` di GDScript va protetto.** `$NodePath` è la scorciatoia per `get_node()`, e
in un corpo di snippet `$` apre un tabstop: si scrive `\\$` nel JSON, che arriva al
parser come `\$`, l'escape che `:h MiniSnippets-syntax` documenta. Scriverne uno
solo, o due (`$$`), dà un tabstop vuoto invece del carattere.

I body usano `\t`: è ciò che il ftplugin del runtime impone già con `noexpandtab`.

## 5. Ciclo di lavoro

1. Il gioco dichiara la sua versione del motore una volta (`mise use godot@<x.y>`).
2. Aprire il progetto con Godot **dalla directory del gioco**, perché è da lì che lo
   shim risolve la versione. Il suo LSP ascolta su `127.0.0.1:6005`.
3. Aprire un `.gd` dello stesso progetto: completion, diagnostica, hover, definizioni
   e rename dalle mapping `<Leader>l` già presenti. Senza Godot aperto restano
   editing, tree-sitter, `gdformat` e `:make` — e **nessuna diagnostica affatto**.
4. `:make` per sapere se il file corrente si parsa, `]q` e `[q` per camminarne gli
   errori. `:Run` per avviare il gioco, `:GodotDoc` per leggere la documentazione.
5. `<Leader>lf` per una modifica mirata, `<Leader>lF` per l'intero script.
6. Test ed esportazione dipendono dal progetto: la sede sono i task nel `mise.toml`
   del gioco, non questa config. `--export-release` vuole gli export template della
   versione esatta, che `mise` non installa e che su Windows stanno sotto
   `%APPDATA%\Godot\export_templates\<versione>`.

## 6. Ambiente di progetto

Tre casi appartengono al `.nvim.lua` del gioco (`:h 'exrc'`, skill
`nvim-project-environment`) e non a questa config:

- **un secondo gioco aperto insieme al primo.** La porta è una risorsa della
  macchina: la seconda istanza di Godot non ripiega su un'altra porta, resta viva e
  semplicemente non ascolta, e Neovim si attacca allora all'**altro** progetto senza
  un messaggio. Il rimedio ha due metà — `godot --lsp-port 6105` e `GDScript_Port`
  sullo stesso valore — e nessuna delle due sta qui, dove varrebbe per tutti i
  progetti insieme;
- **nascondere i `.gd.uid`**, che da Godot 4.4 affiancano ogni script (vanno
  committati: sono l'identità dello script attraverso le rinomine) e raddoppiano le
  voci di ogni directory nei picker, insieme alla cache `.godot/`;
- **la versione del motore**, che sta nel `mise.toml` del gioco e non in un file di
  Neovim.

## 7. Cosa deve dire l'health check

`check_godot()` **ritorna prima di aprire la sezione** quando il buffer da cui si
arriva non sta in un progetto Godot: una sezione "nessun progetto" non è un
controllo, è rumore in ogni altro rapporto. Il buffer è quello **alternato** e non lo
0, per la ragione che `check_angular()` documenta.

Poi, nell'ordine: la radice del progetto; il motore, **in due voci** — presenza e
versione, perché uno shim `mise` è su PATH qualunque versione risolva o non risolva;
`gdformat`; la porta del server come **informazione**, mai come test — connettersi
trasformerebbe "l'editor è chiuso", che è una scelta, in un guasto — e il parser.

## 8. Verifica

Oltre alla passata generale della skill `nvim-config-testing`, i controlli propri di
GDScript, tutti eseguiti e tutti passati:

- **Il server si può verificare davvero in headless**, ed è la scoperta che cambia
  questa sezione: `godot --headless --editor --path <root>` apre 6005 e 6006 senza
  finestra. Avviato così con `hub`, la sonda `lsp` ha trovato **un** client
  `gdscript` con `root` sul `project.godot`, e una richiesta diretta ha riportato
  2066 item di completion, un hover con la documentazione di `Node` e un
  `documentSymbol` non vuoto. Va fermato alla fine: è un processo che non muore da
  sé.
- `vim.lsp.config['gdscript'].root_markers` è `{ "project.godot" }` e `cmd` è ancora
  una `function`: è la prova che l'override ha sostituito la lista senza toccare la
  connessione. Con `.git` ancora dentro, la prova non sarebbe distinguibile.
- `:make` **da una sottodirectory**, non dalla radice, su uno script rotto: una sola
  voce, riga giusta, e il file della voce deve **esistere su disco** (la sonda
  `quickfix` lo pretende). Subito dopo, la cwd deve essere quella di prima.
- I tre comandi sono `-buffer`: presenti in un `.gd`, assenti in un buffer Lua.
  Misurato confrontando `nvim_buf_get_commands()` nei due buffer, che dice in un
  colpo solo entrambe le metà — `:GodotDoc` in un buffer Lua darebbe `E492`, ma una
  sonda che pretende un errore non distingue le ragioni.
- `<Leader>og` e `<Leader>oG` premuti per davvero in una sessione con PTY, non
  iniettati con `-S`: cursore su una parola vera, `<Leader>og` produce l'URL con
  quella parola (non un placeholder), e `<Leader>oG` su un buffer modificato rifiuta
  con lo stesso `WARN` che il codice promette. Il solo ramo non chiuso così è
  `:GodotReconnect` su un buffer **pulito**: l'automazione della tastiera in una
  sessione interattiva reale ha un costo di fragilità che vale la pena conoscere
  prima di ripeterla — vedi `nvim-config-testing`.
- Un comando che avvia un'applicazione si verifica **sostituendo `vim.fn.jobstart`**
  (o `vim.system`) con uno stub che ne registra gli argomenti. Serve per sapere
  *quale* comando partirebbe, e non basta: dove la domanda è *dove finisce
  l'output* — cioè quale dei due rami del contratto è quello giusto — lo stub non
  risponde, e il comando va invocato davvero. Per il ramo staccato, dove non c'è
  nessun buffer da leggere, la prova è **un effetto sul disco**: una scena che
  scrive un file e chiude, più il controllo che nessuna finestra si sia aperta in
  Neovim (`buftype` vuoto, una sola window).
- Gli snippet: contare quelli attivi (24, non 25) e leggere i body dei quattro
  corretti, non fidarsi del fatto che il file esista.
- `gdformat` attraverso 'conform.nvim' su un file volutamente mal formattato: gli
  spazi diventano tab e il buffer cambia davvero.
- L'health check nelle **tre** forme: dentro un progetto, fuori (la sezione non deve
  comparire affatto), e con lo shim che non risolve — riproducibile con
  `$env:MISE_GLOBAL_CONFIG_FILE` su un file vuoto, che è il modo di far dire a
  `godot --version` `No version is set for shim` senza toccare niente.
- **Il server è stato verificato anche contro l'editor GUI reale**, non solo contro
  l'headless: con Godot aperto per davvero su un progetto (`W:/repos/godot-sandbox`),
  la sonda `lsp` ha trovato lo stesso client, la stessa `root`, la stessa risposta —
  nessuna differenza fra le due forme per quanto riguarda il client Neovim.
- **`:Run` staccato accanto all'editor reale aperto**, non solo in un fixture usa e
  getta: una scena che scrive un file e uscita pulita, **zero finestre aperte** in
  Neovim prima e dopo, e l'editor (stesso PID) ancora vivo alla fine. È il ciclo
  normale "F5 mentre l'editor resta aperto", non un caso speciale.
- **Il gioco sopravvive a `:qa`, e la misura va presa da dentro Neovim**: un
  autocomando `VimLeavePre` che scrive `vim.uv.now()` dice quando Neovim se n'è
  andato (misurato: 3,05 s dopo lo spawn, con il gioco ancora vivo), mentre il
  ritorno della shell arriva 21 s dopo — il processo figlio ha ereditato l'handle
  rediretto e la shell aspetta lui, non Neovim. Lo stesso vale per contare i
  processi: sono due, quindi "ne resta uno" non è la prova che il gioco è vivo.
- **`gf` sul caso limite**, cursore esattamente su "res" e non dentro il percorso:
  senza l'estensione di `isfname` catturerebbe solo `res` e fallirebbe. Con la
  correzione, e con il `BufReadCmd` di `capabilities.md` §8, atterra sul file reale
  (`is real file on disk = true`), e il buffer fittizio `res://…` non resta in giro
  (conteggio buffer verificato prima e dopo). Fuori da un progetto Godot, degrada con
  un `vim.notify` invece di aprire qualcosa.
- **Le impostazioni di Godot erano già tutte corrette meno una**, lette da
  `editor_settings-4.7.tres` senza toccare l'editor in esecuzione: `exec_path`,
  `exec_flags` (identici alla forma raccomandata), `use_external_editor`,
  `network/language_server/remote_port = 6005`, `enable_smart_resolve = true`,
  `use_thread = true`. Assente: `Auto Reload Scripts on External Change`, che è
  disattivata per default in Godot (confermato via la documentazione ufficiale, non
  dedotto) e non compariva affatto nel file — un'impostazione al default non lascia
  una riga nel `.tres`.
- **La base della riga non è 0 vs 1: è un bug noto di Godot**, e non richiede più una
  sessione grafica per essere inquadrato. La documentazione e l'issue
  `godotengine/godot#118228` confermano che il motore invia la riga **reale, 1-based**
  (misurato nel report: `p_line=106` per un errore alla riga 106) — `cursor({line},{col})`
  senza `+1`, cioè la forma già configurata, è quella corretta. Esiste però un bug
  distinto: cliccare un `Parse Error` nel log per uno script **già caricato con
  successo in precedenza** genera una SECONDA chiamata con `p_line=-1`, che sovrascrive
  il salto corretto portando il cursore alla riga 1. L'issue è chiuso come
  `COMPLETED`, ma non è confermato se la correzione sia nella 4.7.2 installata qui:
  resta un controllo pratico da fare aprendo uno script buono, introducendo un errore
  e cliccando il log — se il cursore atterra sulla riga giusta e ci resta, il bug non
  c'è (o è stato corretto); se scatta indietro alla riga 1 dopo esserci arrivato bene,
  c'è, e il rimedio è affidarsi a `:make` per gli errori di parsing invece che al click
  sul log.
- La direzione Godot → Neovim per il resto (il `.nvim.lua` con `serverstart`, la
  fiducia, l'apertura da Godot) è stata eseguita su un progetto vero
  (`W:/repos/godot-sandbox`, skill `godot-project-setup`), ma il click che genera la
  richiesta reale da Godot resta da fare in sessione grafica: non è simulabile in
  headless.
