# C e C++

L'esito delle Fasi 1 e 2 per il C++ — e con esso per il C, che condivide server,
formatter e parser — già svolte e verificate su questa macchina (Neovim 0.12.5,
Windows, LLVM 23.1.1, CMake 4.4.3, Ninja 1.13.2). Le fasi successive seguono la
procedura di `SKILL.md`; qui c'è solo ciò che è specifico del linguaggio.

L'analisi funzionale da cui nasce l'implementazione sta nel repository della config
(`docs/analisi_funzionale_cpp.md`): quella dice *perché* ogni asse è stato scelto,
questa dice *cosa è risultato vero* eseguendola.

## 1. Fase 1 — cosa il runtime dà già

Aprendo un `.cpp`, e leggendo con `:verbose setlocal`, che nomina il file
responsabile:

| Cosa | Dettaglio |
|---|---|
| Filetype | `.cpp .cc .cxx .hpp .hh .ixx .cppm` → `cpp`; `.c` → `c`; `CMakeLists.txt` → `cmake` |
| `.h` | **`cpp`, non `c`**, e non dipende dal contenuto: `M.header()` di `$VIMRUNTIME/lua/vim/filetype/detect.lua` cerca solo marcatori Objective-C, poi ricade su `cpp` se `g:c_syntax_for_h` non è impostata |
| Commenti | `commentstring=// %s` da `$VIMRUNTIME/ftplugin/cpp.vim:17` (che sorgenta `c.vim` e `c.lua`) |
| `gf` sugli include | `include=^\s*#\s*include` e `define` da `ftplugin/c.lua` — ma `path` **vuoto**, quindi si arriva solo a un header di fianco al file |
| Rientro | `cindent` da `$VIMRUNTIME/indent/cpp.vim`, che legge `shiftwidth` |
| Completamento a tag | `omnifunc=ccomplete#Complete` da `ftplugin/c.vim:32`, che l'LSP sostituisce da sé (`:h lsp-defaults`) |
| `makeprg`, `errorformat` | **vuoti**: nessun compiler plugin viene scelto |
| Compiler disponibili | `gcc`, `msvc`, `make` fra i 135 di `getcompletion('', 'compiler')`. **`cmake` non esiste**, e nemmeno `clang` o `ninja` |

**`gcc` imposta solo `errorformat`, nessun `makeprg`** — ed è la riga che conta:
il formato di GCC è anche quello di clang, drive letter compresa, quindi è
riusabile invece di essere riscritto (§4.3).

Il livello dei plugin già installati, che per il C++ ha fatto molto:

| Livello | Cosa dà |
|---|---|
| 'nvim-lspconfig' | `clangd` con `cmd`, `filetypes` (`c`, `cpp`, `objc`, `objcpp`, `cuda`, più le varianti `.doxygen`), `root_markers`, `capabilities`, e **tre funzioni**: `get_language_id`, `on_init`, `on_attach` |
| `on_attach` ereditato | crea `:LspClangdSwitchSourceHeader` (estensione `textDocument/switchSourceHeader`) e `:LspClangdShowSymbolInfo`. Scrivere un `on_attach` in `after/lsp/` li cancella **in silenzio** |
| 'conform.nvim' | conosce già `clang-format`: `available=false` solo perché il binario mancava |
| 'friendly-snippets' | 52 snippet caricati in un buffer `cpp` reale, nessuna correzione necessaria |
| 'nvim-treesitter' | parser `cpp` disponibile e **non** installato; dichiara `requires = { 'c' }`, e `c` è spedito con Neovim |

## 2. Fase 2 — cosa di questo tenere

**Da tenere tutto ciò che il runtime imposta come opzione.** `commentstring`,
`include`, `define` e `cindent` sono esattamente le leve su cui poggiano
'mini.comment', `[I`, `:checkpath` e gli operatori di rientro: sostituirle con un
plugin significherebbe spostare quei comportamenti senza accorgersene.

**Da non usare** `omnifunc`, che precede LSP e che Neovim sostituisce da sé appena
un server si attacca: non è un asse da configurare, è un ripiego che sparisce.

**Nessun plugin esterno.** Gli assi scelti sono coperti dai due livelli già
presenti: il server arriva da 'nvim-lspconfig' (comandi inclusi), la formattazione
da 'conform.nvim', gli snippet da 'friendly-snippets', l'albero da
'nvim-treesitter'. Un plugin di estensioni per clangd avrebbe senso solo per le
funzioni fuori protocollo che nessuno di quegli assi chiede.

**Il compiler plugin va scritto**, ed è l'unico file nuovo che il linguaggio
impone: il runtime non ha `cmake`. È la stessa situazione di Angular, per cui
`compiler/ngc.lua` esiste già.

## 3. Fase 4 — toolchain

```powershell
winget install LLVM.LLVM          # clangd, clang++, clang-format, clang-tidy
mise use -g cmake@4 ninja@1.13
```

**WinGet e non `mise`, ed è l'eccezione già scritta nelle convenzioni**: il canale
ufficiale del linguaggio quando lo strumento è compilato con il compilatore. Una
sola release porta server, compilatore, formatter e linter alla stessa versione,
come `rustup` fa per Rust. Su Windows clang individua da sé l'installazione MSVC e
il Windows SDK presenti, quindi non serve nessun rituale `vcvars`: è il vincolo che
ha escluso MSVC come compilatore di riferimento.

> **Misurato, e costa un'ora se non lo si sa: l'MSI di LLVM non tocca il `PATH`.**
> Dopo `winget install LLVM.LLVM`, né il `PATH` di macchina né quello utente
> contenevano `C:\Program Files\LLVM\bin`, e i quattro programmi sono invisibili a
> ogni processo — Neovim da icona compreso — mentre `:checkhealth config` li
> riporta tutti come non installati. La voce la aggiunge
> `modules/tools/install.ps1` di `pyro-resources`; la ripartizione dei canali sta
> in `docs/GESTIONE_TOOL.md`.

`cmake` e `ninja` in `mise` perché sono strumenti di build che un progetto può
volere pinnati, e perché restino dichiarati. Vale il vincolo Windows di sempre: la
directory degli shim deve essere nel `PATH`, e `mise` non ce la mette.

## 4. Fase 5 — cosa implementare

```text
configs/nvim-0.12/
├── plugin/40_plugins.lua        parser, server abilitato, formatter
├── after/lsp/clangd.lua         solo `cmd`
├── after/ftplugin/cpp.lua       compiler, fold, `path`, `:Run`
├── compiler/cmake.lua           `:make` → `cmake --build`
└── lua/config/health.lua        sezione C++
```

### 4.1 Parser

`'cpp'`, `'c'`, `'cmake'`, `'make'` nella tabella `languages`. `c` si dichiara
anche se spedito con Neovim: il parser `cpp` lo elenca fra i propri `requires`,
e quella tabella è anche ciò che legge l'health check.

### 4.2 Server

`'clangd'` in `vim.lsp.enable()`, e in `after/lsp/clangd.lua` **solo `cmd`**:
`--background-index`, `--clang-tidy`, `--header-insertion=never`. Le tre funzioni
ereditate non si toccano (§1), e `cmd` si può scrivere perché il default è una
tabella, sostituita per intero.

**Lo standard C++ non si scrive qui**, ed è il punto che rende il supporto
utilizzabile su più progetti insieme: il flag arriva al server per unità di
traduzione dal `compile_commands.json`, quindi due progetti su standard diversi
aperti nella stessa sessione sono controllati ciascuno contro il proprio.
Misurato su due fixture con lo stesso sorgente: quella a C++14 riporta
`Structured binding declarations are a C++17 extension`, quella a C++20 non
riporta niente.

Fuori da un database — un file sciolto, un progetto non configurato — clangd
assume lo standard più recente che conosce, quindi **accetta** codice che la build
rifiuta. Le due leve sono del progetto: il suo `.clangd`
(`CompileFlags: Add: [-std=c++17]`), che ogni editor onora, o
`vim.lsp.config('clangd', { init_options = { fallbackFlags = { … } } })` nel suo
`.nvim.lua`.

> **Misurato, senza spiegazione trovata**: con LLVM 23.1.1 e CMake 4.4.3 un
> `set(CMAKE_CXX_STANDARD 11)` produce `-std=gnu++14` nel database. Il valore da
> credere è quello del database, non quello del `CMakeLists.txt`, ed è il motivo
> per cui l'health check stampa il primo.

### 4.3 Build e quickfix

`compiler/cmake.lua`, con `makeprg=cmake --build build $*` e un `errorformat`
**ereditato**: `vim.cmd('runtime compiler/gcc.vim')` prima di rivendicare il nome
(gcc.vim apre con `if exists("current_compiler") | finish`, e `:compiler` unlet
quella variabile prima di sorgentare il file richiesto — è quello che lascia il
passaggio aperto). Ricopiare le sue ventitré righe sarebbe una copia che invecchia.

Quello che gcc.vim non può sapere sono i due guasti di cui parla CMake stessa, ed
entrambi sarebbero silenziosi perché il compilatore non gira affatto:

```text
CMake Error at CMakeLists.txt:3:
  Parse error.  Function missing ending ")".  End of file reached.
Error: C:/path/build is not a directory
```

Il primo è navigabile (`%E` + `%C`, chiuso dal `%-G` finale); il secondo non ha
file né riga, quindi `%+G` lo tiene come messaggio generale — **un quickfix vuoto
si legge come una build passata**, e quella è una build che non è mai partita.
Tutto il resto si scarta: le righe `[1/2]` di Ninja, il `FAILED:`, la riga di
comando che riecheggia, l'estratto sotto ogni diagnostica, `2 errors generated.`.

In `after/ftplugin/cpp.lua` la scelta del compiler risale come fa il ftplugin di
Rust per `Cargo.toml`: `CMakeLists.txt` → `compiler cmake`, `Makefile` →
`compiler gcc` (che imposta `errorformat` e nessun `makeprg`, cioè esattamente ciò
che serve dove il `make` di default è già il comando giusto). Un file che non
appartiene a nessuna build non prende niente, e `:make` fallisce dicendolo.

### 4.4 Resto del buffer

- **Fold** per struttura con `vim.wo[0][0].foldexpr`, come in `after/ftplugin/java.lua`.
- **`path`** con le sole directory del progetto (radice, `include`, `src`, `lib`),
  perché i path di sistema in una config condivisa sono sbagliati per costruzione
  e per quelli la risposta è `gd` del server.

  > **Trappola misurata**: `vim.bo.path` di un buffer che non l'ha mai impostata è
  > la **stringa vuota**, non il valore globale in vigore. Concatenare su quella
  > perde `.` e la directory di lavoro — cioè le due voci che risolvono l'include
  > di un header di fianco — e il rapporto della sonda `option_origin` lo mostra
  > come un `path` che inizia per virgola. Si legge `vim.o.path` e si scrive
  > `vim.bo.path`, che è ciò che fa `:setlocal path+=`.

- **`:Run`** (contratto di `lua/config/run.lua`): quello che un progetto C++ esegue
  è un file che ha prodotto, quindi il default si **legge cercandolo** — sotto
  `build/` e nella radice, saltando `CMakeFiles` che contiene le sonde del
  compilatore — invece di chiederlo a un build tool, perché `cmake --build` solo
  costruisce. Con più programmi li nomina e rifiuta; con nessuno dice di lanciare
  prima `:make`. Il primo argomento seleziona il programma quando ne nomina uno,
  gli altri arrivano al programma.

  Non costruisce prima, e la divisione è quella dei due contratti: `:make` è la
  domanda sincrona che finisce e riempie il quickfix, `:Run` avvia qualcosa che
  vive.

### 4.5 Formattazione

`cpp = { 'clang-format' }` e `c = { 'clang-format' }`: arriva con il server, legge
il `.clang-format` del progetto (che il server non leggerebbe), e senza quel file
ricade sullo stile LLVM a 2 spazi, che è già il default della config.

## 5. Ciclo di lavoro

1. Una volta: `cmake -S . -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`.
2. Aprendo un `.cpp`, clangd si attacca conoscendo i flag reali del progetto.
3. Completamento, diagnostica, clang-tidy, hover, definizioni, riferimenti e
   rinomina dalle mapping `<Leader>l`.
4. `:LspClangdSwitchSourceHeader` per il salto header ↔ sorgente.
5. `:make` per costruire, `]q` e `[q` per camminare gli errori.
6. `:Run` per eseguire quello che la build ha prodotto.
7. `<Leader>lf` sulle righe cambiate, `<Leader>lF` sul buffer intero.

## 6. Ambiente di progetto

Quattro casi che appartengono al `.nvim.lua` del progetto (`:h 'exrc'`, skill
`nvim-project-environment`) e non a questa config:

- **C puro** che vuole `.h` come `c`: `vim.g.c_syntax_for_h = true`;
- **build fuori da `build/`**, o guidata da un preset: lì cambia `makeprg`, non il
  compiler plugin condiviso;
- **standard fuori dal database** (file sciolti, progetto non configurato):
  `.clangd` del progetto, o `fallbackFlags` (§4.2);
- **avvio non ovvio**: `vim.g.run_command`, che ha l'ultima parola su `:Run`.

## 7. Cosa deve dire l'health check

Nell'ordine: `clangd`, `clang++`, `clang-format`, `clang-tidy` — un solo advice
per i quattro, perché una sola release li installa tutti — poi `cmake`, `ninja`,
il **database di compilazione** e i parser.

`clang-tidy` si riporta per percorso e non per versione: la prima riga del suo
`--version` è il banner di LLVM (`LLVM (http://llvm.org/):`), e il numero è quello
riportato sopra.

**Il controllo che vale più di tutti gli altri è il database**, perché senza di
esso clangd non fallisce: **indovina**. Si attacca, risponde, riempie il buffer di
errori su `#include` validi e accetta codice che la build rifiuta. Va cercato:

- nella radice del progetto **e sotto `build/`**: misurato, con il generatore
  Ninja `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` scrive
  `build/compile_commands.json`, e quello è anche il secondo posto in cui clangd
  guarda da sé (documentato: le directory padre del file, e in ognuna una
  sottodirectory `build/`). Una build directory con un altro nome resta fuori
  portata, e l'advice deve dire di collegarla o di nominarla nel `.clangd`;
- partendo dal **buffer alternato** (`vim.fn.bufnr('#')`) e non dal buffer 0: è la
  ragione che `check_angular()` documenta per esteso — `:checkhealth` esegue i
  check dentro il proprio buffer di report, che è uno scratch senza nome.

Del database si stampa anche il `-std=` che porta: è l'unico posto in cui lo
standard in vigore è visibile, e un database generato prima che
`CMAKE_CXX_STANDARD` fosse alzato continua a rispondere quello vecchio.

**`root_markers` non trova la radice dal `CMakeLists.txt`**, e non è un guasto:
l'elenco di 'nvim-lspconfig' contiene `compile_commands.json`, che sta in
`build/` e quindi non è antenato di nessun sorgente. La radice viene da `.git`.
Misurato: un client solo, con `root_dir` sulla radice del checkout.

## 8. Verifica

Oltre alla passata generale della skill `nvim-config-testing`, i controlli
falsificabili propri del C++ — tutti eseguiti, tutti passati:

| Cosa | Sonda e parametro |
|---|---|
| `makeprg` viene da `compiler/cmake.lua`, e `path` conserva le voci globali | `option_origin` con `expect = @{ makeprg = 'compiler.cmake%.lua'; path = '^path=%.,,' }` |
| l'albero c'è davvero | `treesitter` con `lang = 'cpp'`, un `find` e un `node` atteso |
| una build che non compila riempie il quickfix con file e riga | `quickfix` con `pattern = 'cannot initialize'`, **da eseguire nella radice del progetto** (`-Cwd`), perché `cmake --build build` è relativo alla directory di lavoro |
| una `build/` non configurata **non** lascia il quickfix vuoto | `quickfix` con `valid = $false` e `pattern = 'not a directory'` |
| un client `clangd` solo, con la radice giusta e il `cmd` voluto | `lsp` con `server = 'clangd'`, `clients = 1` |
| lo standard del progetto è quello che il server applica | due `diagnostics` sulle due fixture: `expect = 'C%+%+17'` in quella vecchia, `absent = 'C%+%+17'` in quella nuova |
| `:Run` avvia il programma costruito e non altro | `command` con `name = 'Run'`, `buffer = $true` e uno stub di `vim.fn.jobstart` nello `before` |
| toolchain, database e parser | `health` con `fail_on = 'WARNING'` |

La fixture minima che serve a tutti: un `CMakeLists.txt` con
`CMAKE_CXX_STANDARD`, un `main.cpp`, un `git init` (**necessario**: senza un root
marker alla radice clangd ricade in single file mode) e un
`cmake -S . -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`.

E il controllo che smaschera l'errore più costoso di questo linguaggio:
`:LspClangdSwitchSourceHeader` da un `.cpp` apre il suo header. Se il comando non
esiste, un `after/lsp/clangd.lua` ha sovrascritto `on_attach`.
