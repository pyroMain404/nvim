# Analisi funzionale: supporto Godot 4 / GDScript

Documento unico per l'implementazione del supporto Godot in questa config. Segue il
metodo di `nvim-language-support`: inventario prima, scelta esplicita degli assi,
nessuna duplicazione del runtime o dei plugin già installati.

L'ambito deliberato è **GDScript per progetti Godot 4**. Il C++ per GDExtension non è
escluso per principio: ha il suo documento, `analisi_funzionale_cpp.md`, ed è da fare
**prima** di questo (§7). Il debug DAP resta fuori.

## Come leggere questo documento

Tutto ciò che segue è stato misurato il 2026-09-13 su questa macchina, con Neovim
0.12.5 e la config reale (`%LOCALAPPDATA%\nvim` è un symlink a `configs/nvim-0.12`),
aprendo un `player.gd` dentro una directory con `project.godot`. **"Misurato" significa
un comando che ha risposto, non una deduzione**, e non va rifatto: va usato.

Dove il documento dice **"da misurare"** c'è un riquadro: sono i punti che non vanno
scritti a memoria. **Ne resta uno**, §9.2, che decide se il cursore arriva sulla riga
giusta e che richiede una sessione grafica. Quello di §6, che decide `:make`, è stato
eseguito lo stesso giorno, subito dopo l'installazione di Godot: il suo esito è nel
testo, e il riquadro è sparito perché la risposta c'è.

> **Storia delle revisioni.** Una stesura precedente aveva eseguito l'inventario sul
> solo runtime di Neovim, non sui plugin già installati, e ne erano derivate quattro
> affermazioni false: il parser `gdshader` dichiarato inutilizzabile, gli snippet
> GDScript dichiarati inesistenti, una versione stantia di `gdtoolkit`, e lo stato
> della macchina mai verificato. Sono corrette qui, e le misure che le smentiscono sono
> nelle tabelle di §2. Le stesure precedenti e la loro valutazione sono state rimosse:
> conservavano solo l'errore.
>
> Una seconda revisione, dello stesso giorno, ha installato Godot con `mise` ed
> eseguito le misure che la sua assenza bloccava. Cambiano §1 (il canale di
> installazione non è più WinGet), §4.3 (due editor aperti non ottengono due server),
> §4.4, §6 (il comando di `:make`, il suo `errorformat` e i suoi limiti veri), §8, §11
> e §13, che perde un rinvio. Anche qui la stesura precedente è sostituita.
>
> Una terza revisione ha letto il sorgente di `godotdev.nvim` per decidere se adottarlo
> (§14). Il verdetto non è cambiato, ma quattro assi che nessuna stesura aveva — e che
> la skill `nvim-language-support` non elencava — sono entrati da lì: §4.5, la
> riconnessione in §4.3, e due rinvii nuovi in §13.

## Risultato atteso

Aprendo un `*.gd` appartenente a una directory con `project.godot`, Neovim deve
offrire:

- il comportamento di editing che Neovim già spedisce per GDScript;
- highlighting Tree-sitter e i textobject che il parser rende disponibili;
- completion, diagnostica e navigazione LSP dal server TCP di Godot in esecuzione;
- formattazione esplicita con `gdformat` tramite le mapping già presenti;
- snippet che producano **Godot 4**, non Godot 3;
- `:make` che dica se lo script aperto si parsa, con gli errori nel quickfix — non se il
  progetto intero compila, che il motore non sa rispondere (§6.2);
- un health check che dica se Godot, formatter e parser sono disponibili.

Godot deve essere aperto sullo stesso progetto: è Godot a possedere il server LSP.
L'assenza dell'editor grafico degrada il solo LSP, senza impedire di aprire o
modificare un file.

## 1. Passo zero: Godot si installa con `mise`

Era il passo bloccante di tutto il documento — senza motore non c'è LSP, non c'è `:make`
e tre controlli di §12 non si possono eseguire. **È stato eseguito.** Misurato prima e
dopo:

```text
prima  vim.fn.executable('godot')  → 0        nessuna voce in `winget list`
dopo   vim.fn.executable('godot')  → 1
       vim.fn.exepath('godot')     → %LOCALAPPDATA%\mise\shims\godot.EXE
       godot --version             → 4.7.2.stable.official.ed1daf0bf
```

Il canale è **`mise` e non WinGet**, e la condizione che sposta la decisione era già
scritta nella stesura precedente: *«se un giorno servissero due versioni del motore per
due giochi»*. È il caso normale, non l'eccezione — un progetto resta sulla versione con
cui è stato scritto, e aprirlo con una più nuova ne converte i file. La versione
appartiene quindi al **progetto**, non alla macchina, ed è esattamente la condizione che
le convenzioni di questa macchina indicano come obbligo di `mise`.

### 1.1 I due comandi, e cosa non serve

```powershell
mise use -g godot@4           # il default della macchina
mise use godot@4.5.1-stable   # dentro un gioco: scrive il suo 'mise.toml'
```

Il primo scrive in `modules/tools/mise/config.toml` di `pyro-resources`, che è sotto
git: su una macchina nuova Godot torna con `mise install`. `@4` e non `latest` perché
`latest` un giorno attraverserà una major — la stessa ragione per cui `node = "20"`.
Misurato: `mise use -g godot@4` risolve a `4.7.2-stable` e scrive `godot = "4"`.

**Non serve nessun `[alias]`.** La guida da cui nasce questo capitolo dichiara
`godot = "asdf:mkungla/asdf-godot"`, che era necessario quando `mise` non conosceva
Godot. Oggi lo conosce:

```text
mise registry godot → aqua:godotengine/godot
```

È il backend `aqua`, che scarica i binari ufficiali dalle release GitHub del motore. Un
alias `asdf:` aggiungerebbe un plugin di terze parti, e su Windows i plugin `asdf` sono
script POSIX: si pagherebbe una dipendenza per ottenere di meno.

### 1.2 Cosa dà, e cosa non dà

| Fatto misurato | Conseguenza |
| --- | --- |
| L'install contiene `Godot_v4.7.2-stable_win64.exe`, `..._win64_console.exe` e una copia `godot.exe` | Lo shim `godot` è l'eseguibile **completo**, editor grafico incluso: `--headless` è una scelta di riga di comando, non un pacchetto diverso. `mise` non installa "solo applicazioni CLI" |
| Due copie da 181 MB per versione, più il launcher da console | ~360 MB per ogni versione dichiarata. È il costo del multi-versione, e va saputo prima di pinnare cinque giochi |
| `mise ls-remote godot` elenca **solo** le `-stable`, di 3.x e 4.x | Niente beta e RC, e soprattutto **niente variante .NET/Mono**: un gioco in C# non si serve da qui. Resterebbe un `[tools]` con `url` esplicito, come fa `dart` in questo repository |

### 1.3 Lo shim risolve la versione dalla directory corrente

È il fatto che attraversa il resto del documento, e non è ovvio. Misurato, con il
motore installato e funzionante:

```text
cwd dentro un progetto che dichiara godot     godot --version → 4.7.2.stable…
cwd fuori da qualunque dichiarazione          mise ERROR No version is set for shim: godot
```

Il secondo caso è stato misurato **prima** di aggiungere il default globale di §1.1, che
è precisamente ciò che oggi lo evita: chi rifà questa prova su questa macchina deve
partire da una directory dove nessun `mise.toml`, globale incluso, nomini `godot`.

E `--path` **non rimedia**: quell'argomento dice a Godot quale progetto aprire, mentre
la versione la sceglie `mise` prima che il motore parta, guardando da dove è stato
invocato. Tre conseguenze, tutte in questo documento:

- `:make` eredita la directory corrente di Neovim, quindi eredita anche la *versione*
  del motore: §6.4;
- l'health check deve distinguere "Godot non è installato" da "lo shim non sa quale
  versione": §8;
- il default globale (§1.1) è ciò che tiene lo shim funzionante fuori da un progetto,
  per il project manager e per un `godot --version` a mano.

## 2. Inventario

### 2.1 Cosa dà il runtime di Neovim

| Asse | Cosa esiste già | Decisione |
| --- | --- | --- |
| Filetype | `*.gd` è riconosciuto come `gdscript`. | Nessun `ftdetect` per `.gd`. |
| Editing | `$VIMRUNTIME/ftplugin/gdscript.vim` imposta `commentstring=# %s`, `expandtab=false`, `tabstop=4`, `shiftwidth=0`, `suffixesadd=.gd`. | Nessun `after/ftplugin/gdscript.lua` per queste. |
| Indentazione e fold | `$VIMRUNTIME/indent/gdscript.vim` imposta `indentexpr=<SNR>_GDScriptIndent()`; il ftplugin imposta `foldexpr=<SNR>_GDScriptFoldLevel()` con `foldmethod=indent`. | Niente da aggiungere. Rafforza la riga precedente. |
| Build/test | Il runtime non seleziona un compiler; `makeprg` è vuoto. | Vedi §6. |
| Syntax legacy | Il runtime ha `syntax/gdscript.vim`. | Resta il fallback, e conta più del solito: vedi il tier del parser. |

`shiftwidth=0` non è un'omissione: fa seguire l'indentazione a `tabstop`. Godot
raccomanda i tab, e il valore effettivo è quindi già quello desiderato.

### 2.2 Cosa danno i plugin già installati

È la metà che la stesura precedente aveva dato per nota invece di misurare, ed è dove
sono nati tutti e quattro gli errori.

| Plugin | Misura | Esito |
| --- | --- | --- |
| `nvim-lspconfig` | `:=vim.lsp.config['gdscript']` | `cmd` è una **funzione** (`vim.lsp.rpc.connect`), `filetypes = { 'gdscript' }`, `root_markers = { 'project.godot', '.git' }`. Porta da `GDScript_Port`, default `6005`. |
| `nvim-treesitter` | `get_filetypes('gdscript')` | `gdscript`. Parser **tier 3**: nessun `maintainers` in `parsers.lua`. |
| `nvim-treesitter` | `get_filetypes('gdshader')` | **`gdshader, gdshaderinc`** — entrambi. Il parser copre i normali `*.gdshader` senza nessuna associazione aggiuntiva. |
| `nvim-treesitter` | `get_filetypes('godot_resource')` | `godot_resource, gdresource`, che coincide con il filetype di `*.tscn` e `*.tres`. |
| `friendly-snippets` | `MiniSnippets.expand({ match = false, insert = false })` in un `.gd` | **25 snippet già caricati**, da `snippets/gdscript.json`, via `gen_loader.from_lang()` di `plugin/30_mini.lua`. |
| `conform.nvim` | `get_formatter_info('gdformat')` | Conosciuto, esegue su stdin. Non disponibile solo perché il binario manca. |
| MINI | — | `mini.comment` legge già `commentstring`, `mini.completion` usa i client LSP, `mini.ai` userà i capture del parser. Nessuna configurazione specifica. |

### 2.3 Filetype dell'ecosistema Godot

```text
a.gd            → gdscript
a.gdshader      → gdshader
a.tscn          → gdresource
a.tres          → gdresource
a.gdshaderinc   → nessun match
a.gdextension   → nessun match
```

Gli ultimi due sono l'unico buco di riconoscimento, e si chiudono in un file solo (§7).

## 3. Assi scelti

| Asse | Stato | Motivazione e sede |
| --- | --- | --- |
| Riconoscimento `.gd` | Già gratis | Nessun file nuovo. |
| Editing, indentazione, fold | Già gratis | Conservare il ftplugin e l'indent del runtime. |
| Tree-sitter `gdscript` | **Da aggiungere** | `gdscript` nella lista `languages` di `plugin/40_plugins.lua`. |
| Tree-sitter `gdshader`, `godot_resource` | **Scelta d'ambito, non ostacolo tecnico** | Entrambi funzionano oggi. Si aggiungono quando si scrivono shader o si modificano scene a mano. Vedi §4.2. |
| Query Tree-sitter | Non serve ora | Nessuna query personalizzata finché `:Inspect` non mostra un difetto concreto. |
| LSP | **Da aggiungere** | `gdscript` in `vim.lsp.enable()`, più `after/lsp/gdscript.lua` per la root stretta. |
| Diagnostica, completion, navigazione | Già gratis con LSP | Restano le impostazioni e le mapping LSP globali. |
| Formattazione | **Da aggiungere** | `gdformat` nel `formatters_by_ft`. Nessun format-on-save. |
| Snippet | **Da correggere** | Non mancano: sono attivi e producono Godot 3. Sede: `after/snippets/gdscript.json`. Vedi §5. |
| Build / quickfix | **Da aggiungere**, comando e formato ora misurati | `compiler/godot.lua`: controlla **un file per volta**, non il progetto, e va eseguito dalla root. Vedi §6. |
| Lint esterno | Non serve ora | `gdlint` è **già sulla macchina** — arriva con gdtoolkit, misurato `executable('gdlint') → 1` — ma cambia le regole diagnostiche e non serve al formatter. Si adotta solo se la CI del gioco lo usa. |
| `ftdetect` | **Da aggiungere se entra GDExtension o uno shader** | `.gdextension` e `.gdshaderinc` non sono riconosciuti. Vedi §7. |
| Navigazione per path `res://` | Da rinviare | LSP e `suffixesadd=.gd` coprono la navigazione. Un `includeexpr` per `preload()` va progettato su esempi reali. |
| Debug | Da proporre separatamente | Godot espone DAP, ma Neovim core non ne è client: richiede `nvim-dap` e una scelta di workflow. |
| Server di un'applicazione esterna | **Vincolo, non asse opzionale** | Il server è dentro l'editor Godot: porta unica per macchina, ciclo di vita non nostro, assenza legittima. Vedi §4.3 e `capabilities.md` §17. |
| Documentazione della classe | **Da aggiungere**, costa cinque righe | L'hover LSP la dà solo con Godot aperto, cioè non mentre si legge. Vedi §4.5. |
| Esecuzione del progetto | **Da proporre** | `godot --path <root>` come comando buffer-local, non come `:make`. Vedi §6.6 e `capabilities.md` §19. |
| Neovim come editor esterno di Godot | Fuori da questo repository | Vive nell'avvio di Neovim e nelle impostazioni di Godot. Vedi §9 e `capabilities.md` §18. |
| Vista sull'albero delle scene | Rinviata | Un `.tscn` si legge come testo; una vista strutturata è un asse vero ma non urgente. Vedi §13. |
| Health check | **Da aggiungere** | Sezione Godot in `lua/config/health.lua`. |

## 4. Architettura e implementazione

```text
configs/nvim-0.12/
├── plugin/40_plugins.lua           parser, server abilitato, formatter
├── after/lsp/gdscript.lua          solo la differenza dal default LSP
├── after/snippets/gdscript.json    correzione dei prefissi Godot 3
├── after/ftplugin/gdscript.lua     solo `:compiler godot`
├── compiler/godot.lua              `:make` su un file, più la root (§6)
├── ftdetect/godot.lua              solo se entrano GDExtension o gli shader
└── lua/config/health.lua           sezione Godot
```

Non sono parte di questa modifica:

- `plugin/42_format.lua`: stabilisce il *range* da formattare, non il formatter;
- `ftdetect/gdscript.lua`: il filetype `.gd` è già corretto;
- un `mise.toml` dentro questo repository: il formatter è uno strumento globale, e la
  versione del motore appartiene al repository del **gioco** (§1.1), non a quello della
  config;
- una pipe o un server RPC creato al caricamento di un buffer (§9).

### 4.1 Tree-sitter

Aggiungere `'gdscript'` alla lista `languages` della sezione Tree-sitter di
`plugin/40_plugins.lua`. Il meccanismo esistente installa il parser quando manca e
avvia Tree-sitter per il filetype che il parser dichiara.

```lua
-- Il parser di Godot. `readme_note = 'Godot'` e nessun `maintainers` in
-- 'parsers.lua' di 'nvim-treesitter': è tier 3, cioè senza manutentore
-- dichiarato. È la ragione per cui il 'syntax/gdscript.vim' del runtime resta
-- un fallback che vale la pena avere, e non un residuo.
'gdscript',
```

Non sono necessarie query, fold o highlight group custom. Se una query diventasse
necessaria, deve iniziare con `; extends` e correggere una capture osservata con
`:Inspect`; non deve fissare colori.

### 4.2 Shader e risorse: una scelta, non un ostacolo

**Correzione di una stesura precedente**, che escludeva `gdshader` sostenendo che il
parser dichiarasse solo `gdshaderinc` e che l'highlight non si sarebbe ottenuto. È
falso. Misurato:

```text
vim.treesitter.language.get_filetypes('gdshader') → gdshader, gdshaderinc
vim.filetype.match({ filename = 'a.gdshader' })   → gdshader
```

L'origine dell'equivoco è in `nvim-treesitter/plugin/filetypes.lua`:

```lua
gdshader = { 'gdshaderinc' },
```

Quella tabella registra i filetype **in più** rispetto al nome del parser, che è già un
filetype di suo: è additiva, non sostitutiva. È lo stesso errore di categoria che la
skill descrive per `after/queries/` e per `after/lsp/`, applicato alla tabella di un
plugin.

Entrambi i parser sono quindi aggiungibili oggi, con una riga ciascuno, e la decisione
torna a essere quella giusta — *si scrivono shader? si modificano scene a mano?* — e non
un problema tecnico inventato:

```lua
-- Aggiungere quando si scrivono shader: il parser copre sia `gdshader` sia
-- `gdshaderinc`, ed è tier 2 con manutentore, a differenza di `gdscript`
'gdshader',
-- Aggiungere quando si modificano '.tscn' e '.tres' a mano invece che
-- dall'editor Godot. Dichiara `gdresource`, che è il filetype che Neovim
-- assegna a entrambe le estensioni
'godot_resource',
```

Il solo difetto reale in quest'area è l'opposto di quello descritto prima:
`*.gdshaderinc` **non è riconosciuto da Neovim**, mentre il parser lo coprirebbe. Si
risolve in §7.

### 4.3 LSP

`nvim-lspconfig` possiede già la configurazione adatta:

```lua
cmd = vim.lsp.rpc.connect('127.0.0.1', tonumber(os.getenv('GDScript_Port') or '6005'))
filetypes = { 'gdscript' }
root_markers = { 'project.godot', '.git' }
```

Il cambiamento minimo è aggiungere `'gdscript'` alla chiamata esistente a
`vim.lsp.enable()`. Questo tiene `cmd`, porta e filetype sotto manutenzione di
nvim-lspconfig. **`cmd` è una funzione** (misurato: `:=vim.lsp.config['gdscript']` dà
`cmd:function`): riscriverlo come lista lo distruggerebbe.

La raccomandazione è restringere l'attivazione ai soli progetti Godot, perché il server
a `6005` appartiene a uno specifico editor Godot già aperto. Creare
`after/lsp/gdscript.lua` con *soltanto*:

```lua
-- ┌───────────────────┐
-- │ GDScript language │
-- └───────────────────┘
--
-- Godot exposes one LSP endpoint for the project it has open. Restrict the
-- client to a Godot project so an unrelated '.gd' file cannot attach to it.
-- See :h lsp-root_markers and :h vim.lsp.enable().
--
-- Only `root_markers` is set. The inherited `cmd` is a function - the TCP
-- connection to Godot - and writing one here would replace it.

return { root_markers = { 'project.godot' } }
```

**Verificato che questo funzioni davvero**, perché la trappola era plausibile:
`vim.tbl_deep_extend('force', …)` fonde in profondità, e su una lista una fusione per
indice avrebbe lasciato sopravvivere `.git`, rendendo l'override inutile. Misurato:

```text
vim.lsp.config('x', { root_markers = { 'project.godot', '.git' } })
vim.lsp.config('x', { root_markers = { 'project.godot' } })
  → vim.lsp.config['x'].root_markers = { "project.godot" }
```

Neovim tratta una tabella-lista come un valore. L'override sostituisce la lista intera
ed eredita il resto.

Se invece si vogliono supportare file GDScript isolati dentro un repository Git, questo
file non va creato e si conserva il default.

La documentazione Godot conferma `127.0.0.1:6005` come porta LSP predefinita e permette
di cambiarla; in quel caso Neovim riceve la stessa porta da `GDScript_Port`.

#### Una porta sola per tutta la macchina

Misurato avviando due editor su due progetti diversi, e guardando chi ascolta davvero:

```text
istanza 1, progetto A              LISTEN 127.0.0.1:6005 e :6006   pid 26968
istanza 2, progetto B              nessuna porta in ascolto        pid  3044
istanza 2 con --lsp-port 6105      LISTEN 127.0.0.1:6105           pid 23228
```

Due fatti, ed entrambi pesano adesso che le versioni possono essere più di una:

- **`--headless --editor` apre comunque LSP e DAP**: 6005 e 6006 rispondono con l'editor
  avviato senza finestra. Non è un dettaglio di questa prova, è ciò che rende reale
  l'ultimo rinvio di §13;
- **la seconda istanza non ripiega su un'altra porta.** Resta viva e semplicemente senza
  server. Un Neovim con la configurazione di default si attacca allora a 6005, cioè
  **all'altro progetto**, e risponde con completion, definizioni e diagnostica di un
  gioco diverso senza un solo messaggio di errore. È il guasto peggiore di tutto il
  documento, perché ha l'aspetto di una configurazione che funziona.

Il rimedio è per progetto e non globale: il secondo gioco avvia Godot con
`--lsp-port 6105` e il suo `.nvim.lua` imposta `GDScript_Port` sullo stesso valore — il
livello che descrive `nvim-project-environment`. In `after/lsp/gdscript.lua` la porta
cambierebbe per tutti i progetti, cioè per nessuno. Resta da confermare in
implementazione che la variabile sia letta abbastanza presto: `cmd` è costruito quando
la configurazione del server viene risolta, e un `.nvim.lua` è sorgentato all'avvio,
prima che un buffer `.gd` la faccia risolvere.

#### Quando Godot si chiude, il client non torna da solo

Chiudere e riaprire l'editor è normale in una giornata di lavoro, e i buffer `.gd`
già aperti restano senza server: non c'è un "riprova" da chiamare, e nessun messaggio
avvisa che da quel momento completion e diagnostica sono mute. Ciò che rifà scattare
l'attach è `:edit` sul buffer, perché ripassa da `FileType`. Vale come comando
buffer-local in `after/ftplugin/gdscript.lua` accanto agli altri, ed è la forma che
usa anche il plugin di §14.

Tutto questo capitolo — assenza legittima, porta condivisa, marker stretti,
riconnessione manuale, nessun ponte esterno — è ora un asse a sé della skill
(`capabilities.md` §17): due di quelle cinque righe nascono dalle misure fatte qui.

#### Tre cose che i tutorial ripetono, e che qui sono sbagliate

Cercando "godot neovim" si trovano quasi solo configurazioni scritte prima di
`vim.lsp.config()`, e ne circolano tre pezzi che vanno riconosciuti e lasciati dove
sono. Nessuno dei tre dà un errore: danno un risultato peggiore, in silenzio.

- **`cmd = { 'ncat', '127.0.0.1', '6005' }`.** La premessa — "su Windows i socket non
  funzionano" — era vera quando `cmd` doveva essere una lista di eseguibili: serviva un
  processo esterno che facesse da ponte fra Neovim e la porta. Oggi il `cmd` ereditato è
  `vim.lsp.rpc.connect`, che apre il TCP con libuv, ed è **misurato qui sopra**.
  Riscriverlo come lista aggiunge una dipendenza esterna per ottenere meno. Vale anche
  per i plugin che la incapsulano: `godotdev.nvim` chiede `ncat` nel `PATH` su Windows.
- **`filetypes = { 'gd', 'gdscript', 'gdscript3' }`.** Solo `gdscript` esiste in Neovim
  (§2.3). Gli altri due non corrispondono a niente e si copiano proprio perché non fanno
  danno visibile.
- **`root_dir = require('lspconfig.util').root_pattern(…)`.** È l'API di
  'nvim-lspconfig' precedente a `root_markers`, e in `after/lsp/` sarebbe per di più una
  **funzione**: il caso in cui la fusione sostituisce invece di unire.

### 4.4 Formattazione e toolchain

Conform già conosce `gdformat` e lo esegue su stdin. Aggiungere questa sola voce al
`formatters_by_ft` di `plugin/40_plugins.lua`:

```lua
-- Il formatter ufficiale di GDScript Toolkit, così che `<Leader>lf` e la riga
-- di comando siano d'accordo. Il server LSP di Godot non formatta, quindi
-- senza questa riga si ricadrebbe su `lsp_format = 'fallback'` che non ha
-- niente da chiamare.
gdscript = { 'gdformat' },
```

`gdformat` fa parte di GDScript Toolkit, la cui linea major 4 corrisponde a Godot 4.
Misurato:

```text
mise ls-remote pipx:gdtoolkit → … 4.2.0  4.2.2  4.3.0 … 4.3.4  4.5.0
```

Pinnare una 4.x esplicita invece di `latest`, che può attraversare una major
incompatibile. **Eseguito**, insieme all'installazione del motore:

```powershell
mise use -g pipx:gdtoolkit@4.5.0
```

```text
gdformat --version            → gdformat 4.5.0
vim.fn.exepath('gdformat')    → %LOCALAPPDATA%\mise\shims\gdformat.EXE
```

Il pacchetto porta con sé anche `gdlint`, `gdparse`, `gdradon` e `gd2py`: sono sulla
macchina per conseguenza, non per scelta, e §3 dice perché `gdlint` resti fuori.

Gli shim di `mise` devono essere nel `PATH` di **sistema**, altrimenti un Neovim avviato
dal collegamento Windows non vedrà `gdformat`. Su Windows `mise` non ce li mette da
solo, e il sintomo è quello di un programma non installato.

Non attivare il format-on-save. Le mapping esistenti mantengono la distinzione fra
`<Leader>lf` (solo hunk modificati) e `<Leader>lF` (intero buffer), una scelta più
prudente per un formatter che il proprio progetto avverte possa riscrivere in modo
esteso.

### 4.5 La documentazione, quando Godot non è aperto

Asse che le stesure precedenti non avevano, e non per distrazione: non era nella
tabella degli assi della skill, che l'ha guadagnata proprio leggendo il plugin di §14.

Il punto è che l'hover dell'LSP dà la documentazione di una classe **solo con l'editor
aperto sul progetto**: è la stessa dipendenza di §4.3 e cade insieme a lei. Quando
Godot è chiuso — cioè mentre si legge codice, che è metà del tempo — `K` non ha niente
da dire. La documentazione del motore, però, sta a un URL prevedibile e versionato:

```text
https://docs.godotengine.org/en/stable/classes/class_<nome tutto minuscolo>.html
```

Cinque righe in `after/ftplugin/gdscript.lua`, file che esiste già per il `:compiler`
di §6.5:

```lua
-- La classe sotto il cursore, nel browser. L'hover LSP la dà già, ma solo con
-- Godot aperto sul progetto: questo comando vale anche a editor chiuso, che è
-- quando si legge. `vim.ui.open()` passa dal gestore del sistema e non aggiunge
-- dipendenze (:h vim.ui.open()).
vim.api.nvim_buf_create_user_command(0, 'GodotDoc', function()
  local class = vim.fn.expand('<cword>'):lower()
  vim.ui.open('https://docs.godotengine.org/en/stable/classes/class_' .. class .. '.html')
end, { desc = 'Godot class reference for the word under the cursor' })
```

Tre cose da decidere in implementazione, non qui:

- una parola che **non** è una classe apre una 404. La forma che non sbaglia mai è
  `search.html?q=<parola>`, al prezzo di una pagina in mezzo: si sceglie dopo averle
  provate entrambe su un `Vector2` e su un nome di variabile;
- se `stable` nell'URL debba seguire la versione che il progetto pinna in `mise.toml`
  (§1.1). Sono la stessa informazione scritta in due posti, e divergono in silenzio:
  leggere una pagina della 4.5 lavorando sulla 4.7 non dà nessun sintomo;
- se valga una mapping. Per la Fase 3 della skill è una decisione da proporre.

## 5. Snippet: correggere, non inventare

**Correzione di una stesura precedente**, che classificava questo asse "non serve ora"
perché «la collezione attuale non offre un set GDScript da caricare automaticamente». È
falso due volte. Misurato in un `.gd` reale:

```text
MiniSnippets.expand({ match = false, insert = false }) → 25 snippet
file: …/friendly-snippets/snippets/gdscript.json
```

Sono già attivi oggi, caricati da `gen_loader.from_lang()`. E il contenuto è **Godot
3**:

| Prefisso | Cosa espande | Perché è rotto in Godot 4 |
| --- | --- | --- |
| `class` | `class $1 extends Reference` | `Reference` è stato rinominato `RefCounted` |
| `export` | `export(type) var name setget` | La sintassi è l'annotazione `@export` |
| `var` | `var name = setget` | `setget` non esiste: si usano blocchi `get:` / `set:` |
| `onready` | `onready var name = get_node()` | La sintassi è `@onready` |
| `inpute` | `func _input_event(event)` | In Godot 4 la firma è `(viewport, event, shape_idx)` |

Cinque prefissi che, premuti in un progetto Godot 4, producono codice che il motore
rifiuta. L'asse non è "da non fare": è **già fatto male**, ed è il più economico da
sistemare di tutta l'integrazione.

La sede è `after/snippets/gdscript.json`, e le regole del livello sono quelle già
descritte dalla skill: **stesso prefisso vince** su friendly-snippets, e **un prefisso
senza `body` lo rimuove**. Il file `after/snippets/lua.json` di questa config usa già
entrambe le forme ed è il modello.

```json
{
  "Inner class": {
    "prefix": "class",
    "body": ["class ${1:Name} extends ${2:RefCounted}", "\t$0"]
  },
  "Export variable": {
    "prefix": "export",
    "body": ["@export var ${1:name}: ${2:Type} = ${3:value}"]
  },
  "Onready variable": {
    "prefix": "onready",
    "body": ["@onready var ${1:name}: ${2:Type} = $${3:NodePath}"]
  },
  "Variable with getter and setter": {
    "prefix": "var",
    "body": [
      "var ${1:name}: ${2:Type} = ${3:value}:",
      "\tget:",
      "\t\treturn ${1:name}",
      "\tset(value):",
      "\t\t${1:name} = value"
    ]
  },
  "Remove Godot 3 prefixes": { "prefix": ["inpute"] }
}
```

I body usano `\t`, non spazi: è l'indentazione che Godot raccomanda e che il ftplugin
del runtime già impone con `expandtab=false`.

> **Da decidere durante l'implementazione**, e solo dopo averli usati: se anche
> `process`, `input`, `ready` e `func` vadano sostituiti con le versioni tipizzate di
> Godot 4 (`func _process(delta: float) -> void:`). Non sono *rotti* — sono validi anche
> in Godot 4 — quindi non appartengono a questa correzione, che riguarda ciò che il
> motore rifiuta.

## 6. Build e quickfix: misurato, e meno di quanto si sperava

**Correzione di una stesura precedente**, che rinunciava a questo asse per intero: «il
comando dipende da scena, framework di test, preset di export e policy del singolo
gioco». Resta vero per *esportare* e per i test, ed è falso per il ciclo interno: un
comando che dice se uno script è sintatticamente valido esiste, non chiede niente al
progetto, ed è quello che `:make` deve eseguire.

La misura ha però corretto anche la correzione. La domanda che una stesura successiva
dava per risolta — **"questo progetto compila?"** — dalla riga di comando di Godot **non
ha risposta**, e §6.2 lo mostra: il ruolo che `cargo check` ha per Rust e `ngc --noEmit`
per Angular in questa config, qui non lo copre nessuno. Quello che resta è più stretto,
e vale comunque la pena di averlo.

**Quale fosse il comando non era deciso**, e il riquadro che chiudeva questa sezione è
stato eseguito il 2026-09-13 su un progetto di prova con un errore di sintassi vero —
una stringa non chiusa alla riga 4 di `scripts/broken.gd`. Quello che segue è il suo
esito.

### 6.1 Quale comando risponde: misurato

Candidato A, l'apertura headless dell'editor, che era il più promettente perché
interroga il **progetto intero**:

```text
godot --headless --path <root> --editor --quit
  → [   0% ] ESC[90mESC[1mfirst_scan_filesystem…  Scanning file structure…
  → nessuna menzione del file rotto
  → exit 0
```

**Scartato, e per due ragioni indipendenti.** Non nomina l'errore, e un progetto che non
compila esce comunque 0 — cioè il caso che `:make` deve distinguere è proprio quello che
non distingue. E ogni riga che stampa è avvolta in sequenze di colore ANSI
incondizionate: la stessa trappola che `compiler/ngc.lua` ha già pagato, questa volta
senza niente da guadagnarci.

Candidato B, quello legato a un singolo script:

```text
godot --headless --path <root> --check-only --script scripts/broken.gd
  → SCRIPT ERROR: Parse Error: Unterminated string.
  →    at: GDScript::reload (res://scripts/broken.gd:4)
  → ERROR: Failed to load script "res://scripts/broken.gd" with error "Parse error".
  →    at: load (modules/gdscript/gdscript_resource_format.cpp:46)
  → exit 1
```

Vince. Ma vince con limiti che vanno scritti accanto, perché cambiano ciò che `:make`
può promettere.

### 6.2 Cosa `:make` può promettere, e cosa no

| Misurato | Conseguenza |
| --- | --- |
| `--check-only` senza `--script` risponde `Couldn't detect whether to run the editor, the project manager or a specific project` ed esce 1 | `:make` controlla **un file**, quello del buffer. "Il progetto intero compila" non è una domanda che il motore risponda da riga di comando |
| Uno script valido: nessun output, exit 0 | un quickfix vuoto significa davvero "questo file si parsa", che è il presupposto perché la lista vuota non menta |
| Un errore **semantico** — `n.no_such_method()` su un `int` — nessun output, **exit 0** | `:make` non sostituisce la diagnostica. Errori di tipo, simboli inesistenti e firme sbagliate li dà **solo** il server LSP, cioè solo con Godot aperto sul progetto. È l'opposto della divisione dei ruoli che vale per Rust o per Angular, e va detto all'utente |
| `--script` accetta il percorso relativo alla root, la forma `res://` e il percorso Windows assoluto; l'output li normalizza tutti in `res://` | `%:p` nel `makeprg` va bene, ed è l'`errorformat` a dover leggere `res://` |

### 6.3 L'`errorformat`, misurato su quelle righe

File e riga stanno sulla riga **successiva** al messaggio: è un formato multi-riga, e la
voce si chiude con `%Z`.

```lua
-- SCRIPT ERROR: Parse Error: Unterminated string.
--    at: GDScript::reload (res://scripts/broken.gd:4)
[[%ESCRIPT ERROR: %m,%Z%.%#(res://%f:%l),%-G%.%#]]
```

Verificato con la sonda `quickfix` di `nvim-config-testing`, che esegue `:make` vero su
quel file: **una sola voce**, `lnum = 4`, testo `Parse Error: Unterminated string.`, e un
buffer reale sotto.

Una avvertenza sulla trascrizione, perché la misura non la copre: il formato è stato
verificato **assegnandolo direttamente** (`vim.bo.errorformat = …`), che non passa dal
parser di `:set`. In `compiler/godot.lua` passerà invece da `CompilerSet`, che un `:set`
lo è: lì i due spazi di `SCRIPT ERROR: ` vanno protetti (`\ `) o il formato finisce
troncato al primo, in silenzio e con il quickfix vuoto. `compiler/ngc.lua` ha già il
commento che spiega quante volte va ripetuto un backslash.

`res://` è consumato come testo letterale del pattern, quindi `%f` riceve
`scripts/broken.gd`, **relativo alla root del progetto** — vedi §6.4, che è la parte che
questo formato da solo non risolve. Il `%-G` finale scarta il banner di versione e le due
righe `ERROR: Failed to load script`, che ripetono lo stesso errore indicando un file
sorgente del motore; arriva **dopo** che `%Z` ha chiuso la voce, quindi non ricade nel
limite noto dei `%-G` dentro un messaggio multi-riga.

### 6.4 `--path` non basta: conta la directory da cui `:make` parte

Una stesura precedente aveva visto metà del problema — `:make` eredita la directory
corrente di Neovim, che in un progetto Godot è spesso `scripts/` o `scenes/` — e ne
aveva tratto il rimedio sbagliato, cioè che bastasse comporre `makeprg` con
`--path <root>`. Misurato, con `--path` già al suo posto e la stessa sonda eseguita due
volte cambiando solo la directory corrente:

```text
cwd = <root>            qf → <root>\scripts\broken.gd            exists = true
cwd = <root>\scripts    qf → <root>\scripts\scripts\broken.gd    exists = false
```

Nel secondo caso `]q` apre un buffer vuoto con quel nome: nessun errore, nessun
messaggio, e la lettura naturale è che il quickfix sia sbagliato piuttosto che la
directory. Il motivo è che `%f` è relativo alla root del progetto mentre Neovim risolve i
nomi del quickfix rispetto alla **propria** cwd, e `--path` parla solo a Godot. A questo
si somma §1.3: da fuori il progetto, `mise` non sa nemmeno quale versione del motore
lanciare.

Misurato anche il rimedio, con la stessa sonda: eseguendo il `:make` con `lcd` sulla root
e ripristinando subito la directory, la voce punta al file vero (`exists = true`) e il
cursore atterra sulla riga 4.

Il che sposta il problema di sede. Un compiler plugin imposta opzioni e **non** può
cambiare directory: `compiler/godot.lua` può comporre `makeprg` con `--path`, ma ciò che
manca va attorno a `:make`. Le due forme praticabili — un comando buffer-local che fa
`lcd`, `make`, `lcd` indietro, oppure una coppia `QuickFixCmdPre` / `QuickFixCmdPost` —
sono una decisione di implementazione; quello che non è più una decisione è che *qualcosa*
deve farlo, perché senza, `:make` funziona soltanto quando Neovim è stato aperto dalla
root. E `compiler/ngc.lua` **non** è il precedente: `npx` risolve dalla directory
corrente e quel compiler non passa nessuna root. Resta il modello per la *forma* di un
compiler plugin, non per questo problema.

### 6.5 Dove va

Sede: `compiler/godot.lua`, sul modello di `compiler/ngc.lua`, più una riga in
`after/ftplugin/gdscript.lua` — che diventa quindi il solo motivo per creare quel file:

```lua
-- ┌────────────────────┐
-- │ GDScript behaviour │
-- └────────────────────┘
--
-- Everything a GDScript buffer needs for editing is already set by
-- '$VIMRUNTIME/ftplugin/gdscript.vim' and '$VIMRUNTIME/indent/gdscript.vim':
-- `commentstring`, hard tabs, `tabstop=4`, `shiftwidth=0`, `suffixesadd`,
-- `indentexpr` and the fold expression. None of it is repeated here.
-- `:verbose setlocal commentstring? tabstop?` says who set what.
if vim.fs.root(0, { 'project.godot' }) ~= nil then vim.cmd('compiler godot') end
```

Una cosa che la misura ha tolto dal tavolo: la colonna. Godot non la dà — riporta file e
riga e basta — quindi nessun `%c` nel formato, e il cursore atterra in colonna 1. Non è
un difetto da rimediare: è quello che il motore sa dire.

### 6.6 Eseguire il gioco non è compilarlo

Una stesura precedente rinviava anche questo, con la stessa motivazione — "dipende dal
progetto". Per i test e per l'esportazione è vera; per **eseguire** no, e lo mostrano
due implementazioni indipendenti: `emacs-gdscript-mode`, che Godot ospita nella propria
organizzazione, e `godotdev.nvim`. Espongono lo stesso piccolo set di azioni, e a
nessuna delle due il progetto ha dovuto dire niente:

| Azione | Forma del comando |
| --- | --- |
| Eseguire il progetto | `godot --path <root>` |
| Eseguire una scena | `godot --path <root>` più il percorso della scena |
| Aprire il progetto nell'editor | `godot --path <root> --editor` |

Non è `:make` e non produce quickfix: è un processo che si avvia e vive per conto suo,
quindi non passa da `compiler/`. La forma giusta è quella **staccata**
(`vim.system({ … }, { detach = true })`): il gioco ha una finestra propria, il suo
output non serve nel quickfix, e non deve morire quando si chiude Neovim. La variante
catturata — output dentro un buffer — è l'altra scelta possibile, e `capabilities.md`
§19 dice cosa cambia. Se entra, entra come comando buffer-local in
`after/ftplugin/gdscript.lua`, e le mapping che lo richiamerebbero sono una decisione da
proporre, non da prendere — la Fase 3 della skill le mette fra quelle che cambiano le
abitudini dell'utente. A differenza di §6, **questa forma non è stata misurata**: il
progetto di prova non ha una scena principale, quindi non c'è niente da far partire. Gli
argomenti vanno confermati sul primo gioco vero, non copiati da qui.

Restano fuori, e correttamente: i test e l'esportazione. Quelli dipendono davvero dal
progetto — ma ora che il motore arriva da `mise`, hanno una sede migliore di "un
terminale": i **task** nel `mise.toml` del gioco, accanto alla versione che quel gioco
pinna. La guida da cui nasce §1 li usa così, e la forma è

```toml
[tasks."export:windows"]
description = "Export the Godot project for Windows"
depends = ["install-export-templates 4.5.1"]
run = ["mkdir -p build/windows", "godot --headless --export-release Windows build/windows/gioco.exe"]
```

Due avvertenze prima di copiarla. `--export-release` richiede gli **export template**
della versione esatta, che `mise` non installa con il motore e che vanno presi a parte;
e lo script che la guida usa per farlo li mette in `~/.local/share/godot/export_templates`,
che su Windows non è la strada giusta — lì i template stanno sotto
`%APPDATA%\Godot\export_templates\<versione>`. Niente di tutto questo è configurazione di
Neovim: è il `mise.toml` del gioco, e va in quel repository.

## 7. GDExtension, `ftdetect` e il C++

Il C++ per GDExtension ha un documento proprio, `analisi_funzionale_cpp.md`, e **va
implementato prima di questo**. La ragione è che GDExtension non aggiunge quasi nulla:
eredita `clangd`, `clang-format`, i parser e il quickfix dal supporto C++
generalizzato, e ciò che gli è proprio si riduce a due cose.

La prima è il riconoscimento dei file. Misurato:

```text
vim.filetype.match({ filename = 'a.gdextension' })  → nessun match
vim.filetype.match({ filename = 'a.gdshaderinc' })  → nessun match
```

`.gdextension` è il file che dichiara la libreria al motore, ed è nella forma di un INI.
Entrambi si risolvono in un solo file, che è il primo file nuovo da creare se entra
GDExtension o se entrano gli shader:

```lua
-- ftdetect/godot.lua
vim.filetype.add({
  extension = {
    -- Dichiarazione di una libreria GDExtension: forma INI, che Neovim
    -- riconosce come `confini` per ogni altro file dello stesso tipo
    gdextension = 'confini',
    -- Il parser `gdshader` dichiara già questo filetype; è Neovim a non
    -- assegnarlo all'estensione
    gdshaderinc = 'gdshaderinc',
  },
})
```

La seconda è la sorgente del `compile_commands.json`, che per `godot-cpp` nasce da SCons
e non da CMake. È trattata in `analisi_funzionale_cpp.md` §9, riquadro incluso.

## 8. Health check

Aggiungere `check_godot()` a `lua/config/health.lua` e richiamarla da `M.check()`. Il
controllo si applica solo quando il buffer **alternato** appartiene a un progetto con
`project.godot`; altrimenti ritorna prima di aprire una sezione — una sezione "nessun
progetto" non è un controllo applicabile.

Il buffer alternato e non il buffer 0: durante `:checkhealth` il buffer corrente è uno
scratch senza nome, e `vim.fs.root()` risponde `nil`. È l'errore che `check_angular()`
ha già commesso e corretto, e il suo commento su `vim.fn.bufnr('#')` è il modello da
copiare.

Quando applicabile, la sezione deve riportare:

1. **`godot`** — presenza e versione, riusando `report()`, con `mise use godot@4` (nel
   progetto) e `mise use -g godot@4` (sulla macchina) nell'advice. È il primo controllo
   perché è il prerequisito di tutto il resto. Entrambi ora **passano**: il controllo
   che conta è il successivo;
2. **quale versione risolve lo shim**, che con `mise` è un guasto a sé (§1.3). Se
   `godot --version` risponde `mise ERROR No version is set for shim: godot`,
   `executable('godot')` vale comunque 1 e il binario esiste: quello che manca è la
   dichiarazione nel progetto. Un check che si ferma a `executable()` dice che va tutto
   bene mentre `:make` e l'editor non partono, ed è la ragione per cui questa voce è
   separata dalla prima;
3. **`gdformat`** — presenza e versione, con il comando `mise use -g` esatto;
4. il **parser `gdscript`**, con lo stesso controllo usato dal codice che lo installa in
   `plugin/40_plugins.lua`;
5. la **configurazione LSP risolta** (`vim.lsp.config['gdscript']`), come informazione
   diagnostica — e, se `GDScript_Port` è impostata, il suo valore, perché è l'unico modo
   di accorgersi che questo progetto parla con un altro editor (§4.3).

Non deve testare `vim.v.servername` né tentare una connessione al server Godot. Due
ragioni distinte, entrambe misurate:

- `serverstart()` aggiunge un **listener secondario** e **non modifica**
  `vim.v.servername` (verificato su Neovim 0.12.5). Un controllo
  `vim.v.servername ~= pipe_path` non esprime quindi lo stato del listener creato, e
  quel valore descrive comunque il listener di Neovim, non la raggiungibilità
  dall'editor Godot;
- l'assenza della sessione grafica è una scelta legittima dell'utente, non un guasto. Il
  check deve descrivere l'ambiente, non interpretarlo.

## 9. Godot come editor esterno

Questo ponte non è una proprietà del filetype e non va inizializzato da un ftplugin.
La forma generale — perché un ftplugin arriva sempre tardi, TCP contro named pipe, il
socket da non creare dentro il repository, la base della riga da verificare — è ora un
asse della skill (`capabilities.md` §18), scritto a partire da questa sezione. Qui
resta ciò che è proprio di Godot. Sono due direzioni indipendenti:

| Direzione | Soluzione | Confine |
| --- | --- | --- |
| Neovim → Godot | Il client LSP TCP di §4.3. | Parte quando Godot è aperto sul progetto. |
| Godot → Neovim | Godot invoca un editor esterno con `{project}`, `{file}`, `{line}`, `{col}`. | È una scelta di avvio dell'editor e vive nelle impostazioni Godot. |

### 9.1 Impostazioni dentro l'editor Godot

Tre pannelli, e nessuno di questi appartiene a questo repository: sono passi di macchina
da applicare e documentare a parte.

| Pannello | Impostazione | Nota |
| --- | --- | --- |
| `Editor → Editor Settings → Network → Language Server` | Remote Host `127.0.0.1`, Remote Port `6005` | Sono i default documentati; il DAP, se un giorno servisse, sta accanto sulla `6006`. La porta si cambia anche da riga di comando con `--lsp-port`, e in quel caso va cambiata insieme a `GDScript_Port` sul lato Neovim. |
| `Editor → Editor Settings → Network → Language Server` | `Use Thread: true` | Fa girare il server in un thread proprio, così un'operazione pesante dell'editor non sospende le risposte a Neovim. Raccomandata in modo indipendente dalle due integrazioni Neovim più complete in circolazione. |
| `Editor → Editor Settings → Network → Language Server` | `Enable Smart Resolve: true` | Migliora la risoluzione dei simboli dinamici. È una raccomandazione, **non** una condizione per stabilire il trasporto LSP. |
| `Editor → Editor Settings → Text Editor → Behavior` | `Auto Reload Scripts on External Change` | È ciò che fa rileggere a Godot un file salvato da Neovim. Senza, le due viste divergono in silenzio. |
| `Editor → Editor Settings → Text Editor → External` | `Exec Path`, `Exec Flags` | Vedi sotto: è la parte fragile. |

`Exec Path: nvim` funziona **solo se il processo Godot eredita un `PATH` che contiene
`nvim.exe`**. Su Windows, dove Godot si avvia da un'icona, è più robusto indicare il
percorso completo dell'eseguibile.

E sull'altro verso — quello che apre l'editor — `mise` aggiunge una condizione che con
WinGet non esisteva. Un collegamento sul desktop o una voce del menu Start lancia
l'eseguibile di *una* installazione e non sa niente del `mise.toml` del gioco: la
versione che quel gioco dichiara si ottiene solo avviando il motore **dalla sua
directory** (§1.3), con `godot --editor` da lì. Un collegamento che punta dritto a
`%LOCALAPPDATA%\mise\installs\godot\<versione>\godot.exe` funziona, ma inchioda il gioco
a quella versione e scade al primo aggiornamento — cioè rinuncia proprio a ciò per cui
si è passati a `mise`.

Dalla 4.5 Godot compila da sé gli `Exec Flags` per gli editor che documenta — VS Code,
Emacs, Vim, Rider. **Neovim non è in quell'elenco**: i flag di §9.2 vanno scritti a
mano, e un campo lasciato vuoto resta vuoto.

### 9.2 Il riuso di un'unica istanza Neovim

Per riusare un'istanza già aperta, quella istanza va avviata **prima** con un endpoint
a cui Godot possa collegarsi con `--server`. Le forme valide sono due, e la seconda è
preferibile:

```text
nvim --listen //./pipe/nvim-godot      named pipe, nella forma che Windows vuole
nvim --listen 127.0.0.1:55432          endpoint TCP, identico su ogni sistema
```

Il TCP evita la forma `//./pipe/`, che è specifica di Windows e altrove si scrive
diversamente, e soprattutto non lascia niente sul disco. È la differenza con la ricetta
che circola più spesso, `--listen {project}/server.pipe`: quella crea un file **dentro
il repository del gioco**, che poi va escluso dal controllo di versione e nascosto in
ogni picker — due problemi creati per risolverne uno.

Cosa **non** fare, e perché — è la proposta che una stesura precedente aveva avanzato:

- **La pipe non va creata da un `after/ftplugin/gdscript.lua`.** Un ftplugin parte solo
  dopo l'apertura di un `.gd`, mentre Godot deve connettersi *prima* per chiedere di
  aprirlo. Arriva sempre troppo tardi per la prima richiesta.
- **`{project}/godot.pipe` non è una named pipe Windows valida.** Su Windows
  `serverstart()` vuole la forma `//./pipe/<nome>`, non un path di file.
- **`pcall(serverstart, …)` senza gestione va evitato.** Nasconde un errore operativo
  proprio quando l'utente deve sapere che Godot non potrà aprire il file; `AGENTS.md`
  richiede `vim.notify()` per un'azione degradata, non una soppressione silenziosa.

Il salto a file, riga e colonna è invece un problema risolto, che una stesura precedente
dava per più difficile di quanto sia. La forma che funziona, da mettere negli
`Exec Flags` accanto all'`Exec Path`, è:

```text
--server 127.0.0.1:55432 --remote-send "<C-\><C-N>:e {file}<CR>:call cursor({line},{col})<CR>"
```

Il limite resta, ma va ridimensionato a quello che è: `--remote-send` non tratta in modo
affidabile i percorsi con caratteri speciali, e un wrapper esterno serve solo se i path
del progetto ne contengono, o se va deciso *quale* istanza debba ricevere il file. Il
fallback semplice — aprire una nuova istanza con il file richiesto — resta possibile
dalle impostazioni di Godot, ma non soddisfa il requisito di riuso.

> **Risolto in `nvim-language-support/references/godot.md` §8.** Il motore invia la
> riga 1-based (`p_line` reale, confermato da `godotengine/godot#118228`), quindi
> `cursor({line},{col})` — la forma già configurata — è corretta. Non serve `+1`.
> Resta un bug distinto di Godot per cui un secondo click su uno script già caricato
> può inviare `p_line=-1`: per quello il riferimento ha la misura e il workaround.

### 9.3 I file che Godot lascia nel progetto

Non è una configurazione da scrivere, ma è ciò che si vede aprendo il progetto, ed è
meglio saperlo prima che dopo.

Da Godot 4.4 ogni script ha accanto un `<nome>.gd.uid`, generato dal motore e **da
committare**: è l'identità stabile dello script attraverso rinomine e spostamenti. In
'mini.files' e nei picker questo raddoppia le voci di ogni directory di codice, e la
cartella `.godot/` — cache di import, questa da non committare — aggiunge il resto.

Nasconderli è legittimo, ma non appartiene a questa config: è una preferenza del singolo
progetto, quindi la sede è il `.nvim.lua` del gioco, secondo la skill
`nvim-project-environment`. In `plugin/` sarebbe un filtro su un'estensione dentro un
file condiviso, che è precisamente ciò che i "Non-goals" di `AGENTS.md` escludono.

## 10. Ciclo di lavoro risultante

1. Il gioco dichiara la sua versione del motore: `mise use godot@4.5.1-stable` nella sua
   root, una volta sola, e da quel momento `godot` significa quella (§1).
2. Aprire il progetto con Godot **dalla directory del gioco**; il suo LSP ascolta su
   `127.0.0.1:6005`. Se un secondo progetto è già aperto, quella porta è sua: §4.3.
3. Aprire un `.gd` dello stesso progetto in Neovim.
4. Completion, diagnostica, hover, definizioni, riferimenti e rinomina dalle mapping LSP
   già presenti. Senza Godot aperto restano editing, Tree-sitter e il fallback syntax —
   e nessuna diagnostica affatto, perché `:make` non ne dà (§6.2).
5. `:make` per sapere se **il file corrente** si parsa, `]q` e `[q` per camminare gli
   errori.
6. `<Leader>lf` per una modifica mirata, `<Leader>lF` per riformattare l'intero script.
7. Per eseguire, testare ed esportare, i task nel `mise.toml` del gioco (§6.6).

## 11. Ordine di implementazione

1. ~~`mise use -g godot@4` e `mise use -g pipx:gdtoolkit@4.5.0`~~ — **fatto**, ed è
   registrato in `modules/tools/mise/config.toml` di `pyro-resources`. Resta da
   verificare che `%LOCALAPPDATA%\mise\shims` sia nel `PATH` di **sistema**, che è
   un'altra cosa dal `PATH` di una shell.
2. Parser, server abilitato e formatter: tre modifiche a `plugin/40_plugins.lua`.
3. `after/lsp/gdscript.lua`.
4. `after/snippets/gdscript.json` — l'asse con il rapporto costo/beneficio migliore,
   perché è già attivo e già sbagliato.
5. `compiler/godot.lua` con il comando e l'`errorformat` di §6, **più** ciò che porta
   `:make` a partire dalla root (§6.4), e `after/ftplugin/gdscript.lua`. La misura che
   questo passo aspettava è stata fatta.
6. Nello stesso `after/ftplugin/gdscript.lua`, i comandi buffer-local: la
   documentazione della classe (§4.5) e la riconnessione dell'LSP (§4.3). Sono cinque
   righe ciascuno e non dipendono da niente del resto.
7. `check_godot()` nell'health check, con la voce separata per lo shim (§8).
8. Configurare l'editor Godot (§9.1), che non è un passo di questo repository.

Parser, server, snippet, quickfix e health check risolvono problemi diversi: sono commit
distinti, con la forma del soggetto che `AGENTS.md` prescrive — il problema, non la
soluzione. E l'aggiornamento della skill `nvim-language-support` — una
`references/godot.md` con l'esito delle fasi 1 e 2 — è un commit ancora a parte, come
prescrive la sua Fase 6.

## 12. Verifica

La passata finale segue `nvim-config-testing`, che è l'unica sede delle regole su come
si verifica. Gli esiti specifici a GDScript sono:

- il buffer `*.gd` ha `filetype=gdscript` e conserva le opzioni del runtime;
- il parser `gdscript` è installato e `:InspectTree` mostra un albero, non il solo
  syntax fallback;
- con Godot aperto sul progetto, `:checkhealth vim.lsp` mostra **un solo** client
  `gdscript` con root su `project.godot` — **e non sulla directory del `.git`**, che è la
  prova che `after/lsp/gdscript.lua` ha sostituito la lista di marker — e una richiesta
  LSP su un simbolo reale riceve risposta;
- `:ConformInfo` dichiara `gdformat` disponibile, e il format di un file di prova
  modifica soltanto l'intervallo richiesto da `<Leader>lf`;
- **in un buffer `.gd`, `class`, `export`, `onready` e `var` espandono sintassi Godot
  4**, e `inpute` non espande più niente. È la prova che l'override di `after/snippets/`
  ha vinto su friendly-snippets;
- `:make` su uno script con un errore di sintassi riempie il quickfix e `]q` salta alla
  riga giusta. Va provato con un progetto che **non** compila, non con uno che compila —
  e **da una sottodirectory**, non dalla root, perché è lì che §6.4 si rompe: il
  controllo che conta è che il buffer aperto da `]q` sia il file vero e non un buffer
  vuoto con il nome giusto;
- `:checkhealth config` segnala correttamente Godot, formatter e parser quando il
  progetto Godot è aperto, e distingue il motore mancante dallo shim che non risolve
  (§8): il secondo caso si riproduce aprendo un `.gd` che non sta sotto nessun
  `mise.toml`;
- i comandi buffer-local di §4.5 e §4.3 **esistono nel buffer `.gd` e non altrove**:
  `:GodotDoc` deve rispondere `E492` in un buffer Lua. È l'unico modo di provare che
  sono `-buffer` e non mapping globali travestite;
- la direzione Godot → Neovim si verifica in una sessione grafica reale, inclusi
  percorsi con spazi, perché non è affidabile né utile simularla in headless.

## 13. Decisioni rinviate

Queste non sono omissioni: richiedono un caso d'uso o una scelta dell'utente.

- parser per shader e risorse — **disponibili e funzionanti**, in attesa del bisogno;
- `gdlint` come linter separato;
- test ed esportazione del gioco: dipendono dal progetto, e la loro sede è il `mise.toml`
  del gioco (§6.6), non questa config. **Eseguirlo non è più fra i rinvii**: ha una forma
  universale, ed è in §6.6;
- conversione dei path `res://` per `gf`;
- debug DAP con `nvim-dap` — sapendo che sotto c'è un gradino che non costa niente: la
  parola chiave `breakpoint` di GDScript ferma il debugger di Godot sulla riga in cui è
  scritta, e con `Debug with External Editor` attivo nella Script view è Godot a portare
  l'editor esterno su quella riga. È anche la ragione per non avere fretta: l'unica
  integrazione che Godot ospita, `emacs-gdscript-mode`, ha un debugger **solo per Godot
  3**;
- wrapper e politica per il riuso dell'istanza Neovim da Godot (§9.2);
- **avvio headless di Godot solo per LSP — non è più un'ipotesi.** Misurato in §4.3:
  `godot --headless --editor` apre 6005 e 6006 senza finestra, quindi la completion e la
  diagnostica si possono avere senza aprire l'editor grafico. Resta rinviato perché
  quello che manca non è la fattibilità ma la **politica**: chi lo avvia, quando muore,
  e cosa succede quando poi si apre l'editor vero sullo stesso progetto — che, come dice
  la stessa misura, non otterrebbe la porta. Un processo dimenticato è peggio di un
  server assente, perché risponde;
- più progetti Godot aperti insieme: `--lsp-port` e `GDScript_Port` per progetto (§4.3)
  sono la forma del rimedio, ma dove vivano — un `.nvim.lua` per gioco, una convenzione
  sulle porte — è una decisione da prendere quando il secondo gioco esiste davvero;
- **vista sull'albero delle scene.** Un `.tscn` è testo e si legge, ma la gerarchia dei
  nodi con i loro tipi è la struttura su cui si ragiona in Godot, e leggerla a mano da
  un file INI non è la stessa cosa. È un asse legittimo (`capabilities.md` §19) e la
  forma sarebbe un buffer scratch generato dal file, non un file da aprire. Rinviato
  perché costa codice da mantenere e perché la sua metà utile — *quale scena apro?* —
  la copre già un picker;
- **console dell'esecuzione.** Catturare l'output del gioco dentro Neovim invece di
  lasciarlo alla finestra di Godot: si valuta dopo aver usato la forma staccata di
  §6.6, non prima.

## 14. `godotdev.nvim`: perché non entra, e cosa gli è stato preso

Il plugin dedicato più completo in circolazione è stato letto **nel sorgente**, non
solo nel README: era la domanda giusta da porsi prima di scrivere una dozzina di righe
di configurazione a mano. Il verdetto resta **no come drop-in**, ma quattro assi di
questo documento vengono da lì.

### Perché no

| Misurato | Dove | Conseguenza |
| --- | --- | --- |
| `cmd = { "ncat", host, port }` su Windows, `vim.lsp.rpc.connect` altrove | `lua/godotdev/lsp.lua` | Su questa macchina `ncat` è **assente**: nessun LSP. È §4.3 al contrario — il trasporto che oggi funziona nativo, sostituito da una dipendenza esterna. Il README lo mette fra i requisiti |
| `require("nvim-treesitter.configs").setup{…}` dentro un `pcall` | `lua/godotdev/tree-sitter.lua` | È l'API del branch `master`; questa config usa `main`, dove `configs.lua` **non esiste** — verificato nell'installazione reale. Il `pcall` fallisce in silenzio: nessun parser, nessun errore, nessun sintomo |
| `BufWritePost *.gd` → `gdscript-formatter --reorder-code`, sul file su disco | `lua/godotdev/formatting.lua` | Contraddice §4.4 su tre punti insieme: format-on-save, un formatter diverso da `gdformat`, e un riordino del codice a ogni `:w`. E scavalca 'conform.nvim', che governa ogni altro linguaggio |
| `filetypes = { "gd", "gdscript", "gdshader", "gdscript3" }`, `root_markers` con `.git`, `capabilities` ricostruite da zero | `lua/godotdev/lsp.lua` | Due filetype che in Neovim non esistono (§2.3), il server GDScript attaccato anche agli shader, e `.git` fra i marker: **esattamente** il difetto che `after/lsp/gdscript.lua` esiste per togliere |
| `makeprg`, `errorformat`, `setqflist`: nessuna occorrenza. Nessuna directory `compiler/`, `snippets/`, `ftdetect/` | tutto il repository | §5, §6 e §7 — snippet che producono Godot 3, quickfix, riconoscimento di `.gdextension` — restano interamente scoperti. Sono il lavoro vero di questo documento |
| `require("godotdev.lsp").setup(…)` è chiamata incondizionatamente da `M.setup()` | `lua/godotdev/setup.lua` | Non c'è un'opzione per tenere il plugin **senza** la sua configurazione LSP: o si installa `ncat`, o la si sovrascrive dopo. Non è un plugin additivo su quell'asse |
| Dipendenze dichiarate: `nvim-dap`, `nvim-dap-ui`, `nvim-treesitter` | README | Il DAP è fuori ambito per scelta (§13), e qui arriva come requisito |

### Cosa gli è stato preso

Quattro assi che questo documento non aveva **e che la skill non elencava**: il server
posseduto da un'applicazione esterna (§4.3), Neovim come editor esterno (§9),
l'esecuzione del programma (§6.6), la vista sullo stato del progetto (§13). Sono
diventati `capabilities.md` §17, §18 e §19, dove valgono per qualunque piattaforma con
la stessa forma — un motore, un IDE che espone un endpoint, un servizio già acceso. Più
la riconnessione con `:edit` (§4.3), che è la sua soluzione e funziona senza il suo
codice.

Il verso della lezione conta quanto la lezione: un plugin che fa cose fuori dalla
tabella degli assi non sta necessariamente facendo troppo — può essere la tabella a
essere corta. Leggere il sorgente di un plugin che si sta **scartando** è la parte
della valutazione che paga di più.

### Quando avrebbe senso adottarlo

Se servono lo scene tree inspector, il browser della documentazione con cache e
render, la console di esecuzione, gli inlay hint e il DAP preconfigurato, quel lavoro
lì è già fatto e manutenuto. Ma va installato **contro i suoi default** —
`formatter = false`, `treesitter.auto_setup = false`, e la sua configurazione LSP da
correggere dopo, perché disattivarla non si può — cioè come un plugin da configurare, e
non come il drop-in che promette di essere.

## Fonti

- Inventario: misurato su questa macchina, Neovim 0.12.5, config `configs/nvim-0.12`,
  2026-09-13. Le misure di §1, §4.3 e §6 sono della stessa data, con Godot 4.7.2-stable
  installato da `mise` e un progetto di prova costruito apposta per rompersi.
- [Rose, *Managing Godot with mise*](https://cosmicrose.dev/blog/godot-mise/) — origine
  di §1 e dei task di §6.6. Il suo `[alias] godot = "asdf:mkungla/asdf-godot"` **non**
  è stato adottato: il registry di `mise` ha già `aqua:godotengine/godot` (misurato con
  `mise registry godot`), e il suo script per gli export template è scritto per i
  percorsi Linux
- [Godot: editor esterno, LSP e DAP](https://docs.godotengine.org/en/stable/tutorials/editor/external_editor.html)
- [Godot: comandi CLI, `--lsp-port` e `--check-only`](https://docs.godotengine.org/en/latest/tutorials/editor/command_line_tutorial.html)
- [nvim-lspconfig: configurazione GDScript](https://github.com/neovim/nvim-lspconfig/blob/master/lsp/gdscript.lua)
- [Conform: definizione di `gdformat`](https://github.com/stevearc/conform.nvim/blob/master/lua/conform/formatters/gdformat.lua)
- [GDScript Toolkit: ramo Godot 4 e formatter](https://github.com/Scony/godot-gdscript-toolkit)
- [Neovim: `serverstart()` e named pipe](https://neovim.io/doc/user/vimfn.html#serverstart())
- [`emacs-gdscript-mode`, l'integrazione ospitata da Godot](https://github.com/godotengine/emacs-gdscript-mode)
  — riferimento d'ambito: conferma `gdformat`, e il suo debugger è solo per Godot 3
- [Simon Dalvai, *Godot with Neovim*](https://simondalvai.org/blog/godot-neovim/) —
  origine degli `Exec Flags` di §9.2, del gradino `breakpoint` e dei file `.uid`
- [`godotdev.nvim`](https://github.com/Mathijs-Bakker/godotdev.nvim) e
  [la ricetta con `ncat`](https://mb-izzo.github.io/nvim-godot-solution/) — valutati e
  **non adottati**. La valutazione, fatta sul sorgente del plugin (branch `master`,
  2026-08-31) e non sul suo README, è in §14: è anche la fonte dei quattro assi nuovi
- [`shiena/godot-neovim`](https://github.com/shiena/godot-neovim) — Neovim *dentro*
  l'editor Godot, cioè il problema opposto a quello di questo documento
- `:h vim.lsp.config()`, `:h lsp-root_markers`, `:h write-compiler-plugin`,
  `:h treesitter-query-modeline-extends`
