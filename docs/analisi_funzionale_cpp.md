# Analisi funzionale: supporto C++

Segue il metodo di `nvim-language-support`: inventario prima, scelta esplicita degli
assi, niente che duplichi il runtime o i plugin già installati.

L'ambito è **C++ generalizzato** — qualunque progetto, non solo Godot. GDExtension è un
modo di *usare* questo supporto, non una sua variante, e vive in §9.

## Come usare questo documento

È scritto per essere implementato da una sessione che non ha visto nessuna delle
misure. Tre convenzioni:

- **"Misurato"** = un comando eseguito su questa macchina il 2026-09-13, con Neovim
  0.12.5 e la config reale (`%LOCALAPPDATA%\nvim` è un symlink a
  `configs/nvim-0.12`), aprendo un `main.cpp` vero. Non va rifatto: va usato.
- **"Deciso"** = una scelta già presa con l'utente. Non va riaperta senza un motivo
  nuovo.
- **"Da misurare"** = riquadro esplicito. Sono i punti che **non** vanno scritti a
  memoria, e sono tre in tutto il documento. Ognuno dice quale comando eseguire e cosa
  guardare.

Lo stato attuale: **nessuna riga di config è stata scritta, nessun tool installato.**
Il documento parte da zero.

## 1. Inventario misurato

### Riconoscimento del filetype — tutto gratis

`vim.filetype.match()`:

| File | Filetype |
| --- | --- |
| `.cpp` `.cc` `.cxx` `.hpp` `.hh` `.ixx` `.cppm` | `cpp` |
| `.h` | `cpp` |
| `.c` | `c` |
| `CMakeLists.txt`, `.cmake` | `cmake` |
| `Makefile` | `make` |
| `compile_commands.json` | `json` |
| `.gdextension` | **nessun match** |

**`.h` è `cpp`, non `c`, e non dipende dal contenuto.** In
`$VIMRUNTIME/lua/vim/filetype/detect.lua`, `M.header()` cerca solo marcatori
Objective-C; poi, se `g:c_syntax_for_h` non è impostata, ritorna `cpp` come fallback.
Verificato anche con un header di C puro: resta `cpp`. Per un progetto C++ è il
comportamento voluto; per un progetto C puro la leva è `g:c_syntax_for_h`, che è
globale e quindi appartiene a un `.nvim.lua` di progetto, non a questa config (§6).

### Editing — il runtime copre quasi tutto

`:verbose setlocal`, che nomina il file responsabile:

| Opzione | Valore | Da dove |
| --- | --- | --- |
| `commentstring` | `// %s` | `$VIMRUNTIME/ftplugin/cpp.vim:17` |
| `include` | `^\s*#\s*include` | `$VIMRUNTIME/ftplugin/c.lua` |
| `define` | `^\s*#\s*define` | `$VIMRUNTIME/ftplugin/c.lua` |
| `omnifunc` | `ccomplete#Complete` | `$VIMRUNTIME/ftplugin/c.vim:32` |
| `cindent` | `true` | `$VIMRUNTIME/indent/cpp.vim:14` |
| `expandtab`, `tabstop=2`, `shiftwidth=2` | — | **`plugin/10_options.lua` di questa config** |
| `path` | **vuoto** (globale `.,,`) | nessuno |
| `makeprg`, `errorformat` | **vuoti** | nessuno |

Due righe meritano attenzione.

**L'indentazione a 2 spazi non viene dal linguaggio**, viene dai default globali della
config. Coincide con lo stile LLVM, che è anche il default di `clang-format` senza
`.clang-format`, quindi non c'è niente da correggere — ma va saputo, perché un progetto
che vuole 4 lo dichiara nel proprio `.clang-format` e non qui.

**`omnifunc` è il completamento a tag di Vim**, precedente a LSP. Quando clangd si
attacca, Neovim lo sostituisce con il proprio (`:h lsp-defaults`). Non è un asse da
configurare: è un fallback che sparisce da solo.

### Build e quickfix — il buco vero

`vim.fn.getcompletion('', 'compiler')`, 135 voci. Quelle pertinenti:

```text
bcc, gcc, hp_acc, icc, make, msvc, racomake, tcl
```

- **`gcc`** imposta *solo* `errorformat` — nessun `makeprg`. Il formato è quello di GCC
  e clang (`file:riga:col: error: messaggio`), quindi **copre clang senza modifiche**.
- **`msvc`** imposta `makeprg=nmake` e `errorformat&`, cioè il default.
- **`cmake` non esiste**, e nemmeno `clang` o `ninja`.

Questo è l'unico asse che richiede un file nuovo, ed è la stessa situazione di Angular:
`compiler/ngc.lua` esiste in questo repository proprio perché il runtime non aveva il
compiler giusto.

### Tree-sitter

| Parser | Disponibile | Installato | Filetype | Tier |
| --- | --- | --- | --- | --- |
| `cpp` | sì | **no** | `cpp` | 2, `requires = { 'c' }` |
| `c` | sì | **sì** (spedito con Neovim) | `c` | — |
| `cmake` | sì | no | `cmake` | — |
| `make` | sì | no | `make`, `automake` | — |

Le query di `c` sono già complete (`highlights`, `textobjects`, `folds`); quelle di
`cpp` rispondono `nil` finché il parser non è installato — è l'assenza del parser, non
delle query.

### LSP — `nvim-lspconfig` dà molto, e parte è fragile

`:=vim.lsp.config['clangd']`:

```text
cmd = { 'clangd' }                                    ← TABELLA
filetypes = { 'c', 'c.doxygen', 'cpp', 'cpp.doxygen', 'objc', 'objcpp', 'cuda' }
root_markers = { '.clangd', '.clang-tidy', '.clang-format',
                 'compile_commands.json', 'compile_flags.txt', 'configure.ac', '.git' }
capabilities      → tabella (offsetEncoding, editsNearCursor)
get_language_id   → FUNZIONE
on_init           → FUNZIONE
on_attach         → FUNZIONE
```

**Le tre funzioni sono la parte da non toccare.** In `after/lsp/` una funzione
*sostituisce* quella ereditata invece di affiancarla, e `on_attach` è quella che crea
due comandi che nessuno documenta e che sono esattamente ciò che serve ogni giorno in
C++:

- `:LspClangdSwitchSourceHeader` — salto header ↔ sorgente, via l'estensione
  `textDocument/switchSourceHeader` di clangd;
- `:LspClangdShowSymbolInfo`.

Scriverne una in `after/lsp/clangd.lua` li cancella entrambi, in silenzio.

`cmd` invece è una **tabella**, quindi sovrascriverlo è legittimo. La fusione sostituisce
la lista intera — verificato sul caso gemello in `analisi_funzionale_godot.md` §4.3: Neovim
tratta una tabella-lista come un valore, non fonde per indice.

Esistono anche `ccls` (alternativa storica) e, per i file CMake, `neocmake` e `cmake`.

### Formattazione e snippet — già pronti

- Conform conosce già `clang-format`: `get_formatter_info('clang-format')` risolve il
  comando; `available=false` solo perché il binario manca.
- friendly-snippets: **52 snippet** caricati in un buffer `cpp` reale, via
  `gen_loader.from_lang()`. Nessun asse da aprire, e nessuna correzione da fare —
  a differenza di GDScript, dove gli snippet erano obsoleti.

### Debug

`$VIMRUNTIME/pack/dist/opt/termdebug/plugin/termdebug.vim` esiste, e
`plugin/40_plugins.lua` lo documenta già in fondo, commentato. È un front-end per
**gdb**: copre C++ senza installare plugin, ma richiede gdb, che LLVM non spedisce.

### Toolchain — lo stato peggiore dell'inventario

`vim.fn.executable()`:

```text
clangd  clang  clang-format  g++  gcc  cmake  ninja  make  cl  gdb  lldb  →  tutti assenti
```

**Non c'è nessun modo, oggi, di compilare un file C++ da questo Neovim.**

Ma c'è un compilatore sul disco, fuori dal `PATH`:

```text
Visual Studio Build Tools 2022 — MSVC 14.44.35207
  cl.exe: …/BuildTools/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe
Windows SDK 10.0.26100.0
vcvars64.bat presente
```

`cl.exe` non funziona lanciato direttamente: vuole `INCLUDE`, `LIB` e `PATH` che
`vcvarsall.bat` imposta. È il vincolo che ha deciso la sezione seguente.

## 2. Toolchain — deciso: LLVM

```powershell
winget install LLVM.LLVM
```

Una installazione, e `clang++`, `clangd`, `clang-format`, `clang-tidy` sono la stessa
versione. Quattro ragioni, in ordine di peso:

1. **Server e compilatore dalla stessa release.** È il principio che `AGENTS.md`
   applica già a Rust — `rust-analyzer` da `rustup` e non da `mise`, perché per un
   linguaggio il cui server viaggia col compilatore quell'allineamento è ciò che li
   tiene d'accordo. Per C++ quel canale è LLVM. È anche l'eccezione già scritta nelle
   convenzioni personali: *canale ufficiale del linguaggio quando lo strumento è
   compilato con il compilatore*.
2. **Niente rituale `vcvars`.** Su Windows clang individua da sé l'installazione MSVC e
   il Windows SDK già presenti, e usa la stessa ABI. Il compilatore diventa invocabile
   da un Neovim avviato da un'icona, che è il caso normale qui.
3. **L'`errorformat` esiste già.** La diagnostica di clang ha la forma GCC, quindi
   `:compiler gcc` del runtime la legge senza scrivere una riga.
4. **`clang-tidy` entra nel server con un flag**, e occupa per C++ il ruolo che
   `clippy` occupa per Rust in questa config: niente linter separato da installare e da
   far girare.

**WinGet e non `mise`**, coerentemente con il punto 1 e con la ripartizione di
`docs/GESTIONE_TOOL.md`: è il canale ufficiale del linguaggio, e ne serve una versione
sola. Non va quindi aggiunto a `~/.config/mise/config.toml`.

A cui si aggiungono, da `mise`, gli strumenti di build:

```powershell
mise use -g cmake@4        # aqua:Kitware/CMake   — verificato disponibile
mise use -g ninja@1.13     # aqua:ninja-build/ninja — verificato disponibile
mise install
```

Questi sì in `mise`: sono strumenti di sviluppo che un progetto può voler pinnare, ed è
la ripartizione documentata.

> **Vincolo Windows, da non dimenticare.** La directory degli shim
> (`%LOCALAPPDATA%\mise\shims`) deve essere nel `PATH` di **sistema**. `mise` su Windows
> non ce la mette. Finché non c'è, `cmake` e `ninja` sono invisibili a un Neovim avviato
> da un'icona, e il sintomo è quello di un programma non installato.
> `:checkhealth config` è ciò che lo dice.

### L'alternativa scartata, e perché resta registrata

**MSVC, già installato.** Non avrebbe installato un compilatore (14.44.35207 è sul
disco) e avrebbe prodotto binari con il compilatore che Godot stesso usa come default su
Windows. È stata scartata per tre costi:

- **`clangd` andrebbe installato comunque e da solo.** Verificato: `aqua:clangd/clangd`
  **non esiste** nel registry, ma `ubi:clangd/clangd` sì, con versioni da 20.1.0 a
  22.1.6 → `mise use -g "ubi:clangd/clangd@22.1.6"`. In quel caso il server è assunto
  dalla config e non viaggia col compilatore, quindi la sede giusta sarebbe `mise`.
- **L'ambiente.** `cl.exe` va raggiunto attraverso `vcvarsall.bat`, e uno shim `mise`
  non lo risolve. Vorrebbe dire avviare Neovim da un Developer Prompt, o far invocare
  `vcvars` al `makeprg`.
- **Un `errorformat` da scrivere.** MSVC emette `file(riga,col): error C2065: messaggio`,
  che il `gcc` del runtime non legge.

Resta registrata perché **nulla impedisce di avere entrambi**: clang per l'editing e il
ciclo interno, MSVC per le build di release. La config punta comunque a uno solo, ed è
quello da cui nasce il `compile_commands.json`.

## 3. Assi scelti

| Asse | Stato | Sede |
| --- | --- | --- |
| Riconoscimento filetype | Già gratis | — |
| Editing (`commentstring`, `include`, `cindent`) | Già gratis | — |
| Tree-sitter `cpp`, `c`, `cmake`, `make` | **Da aggiungere** | lista `languages`, `plugin/40_plugins.lua` |
| Query Tree-sitter | Non serve | Nessuna finché `:Inspect` non mostra un difetto |
| LSP `clangd` | **Da aggiungere** | `vim.lsp.enable()` + `after/lsp/clangd.lua` |
| Diagnostica, completion, navigazione, code lens | Già gratis con LSP | — |
| Lint | **Coperto da `--clang-tidy`** | dentro `after/lsp/clangd.lua`; nessun linter separato |
| Build e quickfix | **Da aggiungere** | `compiler/cmake.lua` + `:compiler` in `after/ftplugin/cpp.lua` |
| Formattazione | **Da aggiungere** | `formatters_by_ft`, `plugin/40_plugins.lua` |
| Snippet | Già gratis | 52 da friendly-snippets, misurati, e corretti |
| Salto header ↔ sorgente | **Già gratis, ma invisibile** | `:LspClangdSwitchSourceHeader` da `nvim-lspconfig` |
| `gf` su `#include` | Da rinviare | `path` è vuoto; riempirlo con path di sistema in una config condivisa è sbagliato. `gd` di LSP copre il bisogno reale |
| Textobject | Già gratis dopo il parser | `mini.ai` usa i capture di `nvim-treesitter-textobjects` |
| Debug | Da rinviare | `Termdebug` c'è ma vuole gdb, che LLVM non dà |
| Toolchain | **Da installare** | §2 |
| Health check | **Da aggiungere** | `check_cpp()` in `lua/config/health.lua` |

## 4. Cosa implementare

```text
configs/nvim-0.12/
├── plugin/40_plugins.lua        parser, server abilitato, formatter
├── after/lsp/clangd.lua         solo `cmd`
├── after/ftplugin/cpp.lua       solo `:compiler cmake` quando il progetto è CMake
├── compiler/cmake.lua           `:make` → `cmake --build`
└── lua/config/health.lua        sezione C++
```

### 4.1 Tree-sitter

In `plugin/40_plugins.lua`, dentro `languages`:

```lua
'cpp',
-- `c` è già spedito con Neovim, ma il parser `cpp` lo dichiara fra i propri
-- `requires` in 'parsers.lua': senza, non si costruisce. Elencarlo qui lo rende
-- anche esplicito per l'health check.
'c',
-- I file da cui si costruisce il progetto, letti quanto il codice — stessa
-- ragione per cui `toml` sta accanto a `rust` e `xml` accanto a `java`
'cmake',
'make',
```

### 4.2 LSP

In `vim.lsp.enable({ … })` aggiungere `'clangd'`, con il commento che dice perché non
c'è altro da configurare:

```lua
-- Installato con LLVM (WinGet), configurato in 'after/lsp/clangd.lua'.
-- Copre C, C++, Objective-C e CUDA: i `filetypes` di 'nvim-lspconfig' sono
-- già quelli giusti e non vanno ricopiati.
'clangd',
```

E `after/lsp/clangd.lua`, che contiene **solo `cmd`**:

```lua
-- ┌──────────────────────┐
-- │ C and C++ via clangd │
-- └──────────────────────┘
--
-- Only `cmd` is set here, and that is the whole point of the file.
-- 'nvim-lspconfig' defines `on_attach`, `on_init` and `get_language_id` as
-- functions, and a function written here REPLACES the inherited one instead of
-- running next to it (`:h vim.lsp.config()`). The inherited `on_attach` is what
-- creates `:LspClangdSwitchSourceHeader` - the header/source jump - so writing
-- one here removes it with no error and no message.
--
-- `cmd` is safe to write because the default is a table, and a list is replaced
-- whole rather than merged by index.
--
-- What is NOT here, on purpose: `root_markers`. The default already includes
-- 'compile_commands.json' ahead of '.git', which is the right order - the
-- database is what clangd actually needs, and the repository root is the
-- fallback.
return {
  cmd = {
    'clangd',
    -- Index the whole project in the background, so references and rename
    -- answer about files that were never opened. Without it clangd only knows
    -- the translation units of the open buffers.
    '--background-index',
    -- Run clang-tidy as part of the diagnostics. This is what makes a separate
    -- linter unnecessary for C++, the same role `clippy` plays for Rust in
    -- 'after/lsp/rust_analyzer.lua'. Rules belong to the project's
    -- '.clang-tidy', not here.
    '--clang-tidy',
    -- Accepting a completion does not edit the top of the file. Inserting an
    -- include is a deliberate act, and a silent one lands in the diff.
    '--header-insertion=never',
  },
}
```

### 4.3 Build e quickfix

Il runtime non ha un compiler per CMake, quindi va scritto, sul modello di
`compiler/ngc.lua`. La forma attesa di `compiler/cmake.lua`:

```lua
vim.g.current_compiler = 'cmake'

-- `--build build` costruisce la directory configurata una volta sola con
-- `cmake -S . -B build`. `$*` è dove `:make` inserisce i suoi argomenti, così
-- `:make --target test` resta possibile.
vim.cmd([[CompilerSet makeprg=cmake\ --build\ build\ $*]])

-- La diagnostica di clang ha la forma GCC, che il runtime sa già leggere.
-- <<< QUESTO È IL PUNTO DA MISURARE — vedi il riquadro >>>
```

> **Da misurare prima di scrivere l'`errorformat`.**
>
> 1. Creare un progetto CMake minimo con un errore di sintassi vero.
> 2. `cmake -S . -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`
> 3. `cmake --build build` e **guardare l'output esatto**.
>
> Le due domande a cui rispondere:
> - Il generatore Ninja antepone `[1/8]` a ogni riga: quelle righe di avanzamento
>   vanno scartate con un `%-G`, o l'`errorformat` le raccoglie come voci che non
>   saltano da nessuna parte?
> - Il formato di clang è già coperto da `$VIMRUNTIME/compiler/gcc.vim`? Se sì,
>   la riga giusta è caricare quello e aggiungere solo lo scarto
>   (`:compiler gcc` seguito da `CompilerSet errorformat+=…`), non ricopiare
>   ventitré righe di formato.
>
> È la lezione che `compiler/ngc.lua` ha già pagato con i codici colore di `ngc`:
> **un `errorformat` scritto a memoria lascia il quickfix vuoto, e un quickfix vuoto
> si legge come "la build è passata".**

E `after/ftplugin/cpp.lua`, che esiste solo per la riga che seleziona il compiler
quando il progetto è un progetto CMake — risalendo come fa il ftplugin di Rust del
runtime per `Cargo.toml`:

```lua
-- ┌───────────────┐
-- │ C++ behaviour │
-- └───────────────┘
--
-- Everything else a C++ buffer needs is already set by
-- '$VIMRUNTIME/ftplugin/cpp.vim' (which sources 'c.vim' and 'c.lua') and
-- '$VIMRUNTIME/indent/cpp.vim': `commentstring`, `include`, `define`, `cindent`.
-- `:verbose setlocal commentstring? include?` says who set what.
--
-- The indentation is not set here either: `expandtab`, `tabstop=2` and
-- `shiftwidth=2` come from 'plugin/10_options.lua' and match the LLVM style
-- that `clang-format` falls back to. A project that wants something else says
-- so in its own '.clang-format'.
if vim.fs.root(0, { 'CMakeLists.txt' }) ~= nil then vim.cmd('compiler cmake') end
```

### 4.4 Formattazione

In `formatters_by_ft` di `plugin/40_plugins.lua`:

```lua
-- Arriva con LLVM, insieme al server, quindi formatter ed editor concordano
-- per costruzione. Legge il '.clang-format' del progetto, cosa che il server
-- non farebbe: è la stessa ragione per cui `rustfmt` e `prettier` sono
-- dichiarati qui. Senza quel file ricade sullo stile LLVM, a 2 spazi, che è
-- già il default di 'plugin/10_options.lua'.
cpp = { 'clang-format' },
c = { 'clang-format' },
```

Niente format-on-save: `<Leader>lf` e `<Leader>lF` restano come sono.

### 4.5 Health check

`check_cpp()` in `lua/config/health.lua`, richiamata da `M.check()` dopo
`check_java()`. Deve riportare, in quest'ordine:

```lua
local function check_cpp()
  health.start('config: C++')

  -- Un'unica installazione LLVM dà server, compilatore, formatter e linter alla
  -- stessa versione: è la ragione per cui viene da WinGet e non da `mise`, la
  -- stessa per cui `rust-analyzer` viene da `rustup`. Un advice solo, quindi.
  local install_llvm = 'Install it with `winget install LLVM.LLVM`'
  report(
    'clangd',
    'C++ buffers lose completion, diagnostics, rename and go to definition',
    install_llvm
  )
  report('clang++', 'nothing compiles', install_llvm)
  report(
    'clang-format',
    '`<Leader>lf` falls back to a server that formats differently',
    install_llvm
  )
  -- 'after/lsp/clangd.lua' passes `--clang-tidy`: senza il binario il server
  -- non fallisce, semplicemente non produce quelle diagnostiche
  report(
    'clang-tidy',
    'the server is configured to lint with clang-tidy and finds nothing to run',
    install_llvm
  )

  report(
    'cmake',
    "`:make` has nothing to run ('compiler/cmake.lua')",
    'Install it with `mise use -g cmake@4`'
  )
  report(
    'ninja',
    'CMake falls back to a slower generator',
    'Install it with `mise use -g ninja@1.13`'
  )

  -- … parser cpp/c/cmake/make, con lo stesso ciclo di `check_rust()` …

  -- … e il controllo che segue, che è quello che conta davvero.
end
```

**Il controllo che vale più di tutti gli altri: esiste un `compile_commands.json`
raggiungibile dal progetto del buffer da cui si è arrivati?**

È l'analogo esatto del controllo `node_modules` della sezione Angular, e per la stessa
ragione: **senza compilation database clangd non fallisce, indovina.** Si attacca,
risponde, e riempie il buffer di errori su `#include` perfettamente validi perché non
conosce gli include path del progetto. È il guasto più comune del C++ in un editor ed è
indistinguibile da una config rotta se nessuno lo nomina.

L'advice deve contenere il comando che lo genera:

```powershell
cmake -S . -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

E va cercato **dal buffer alternato**, non dal buffer 0: durante `:checkhealth` il
buffer corrente è uno scratch senza nome e `vim.fs.root()` risponde `nil`. Il commento
di `check_angular()` su `vim.fn.bufnr('#')` spiega l'errore per esteso ed è il modello
da copiare.

> **Da misurare durante l'implementazione.** Dove CMake scrive
> `compile_commands.json` con il generatore Ninja: nella directory di build
> (`build/compile_commands.json`) o alla radice? Il controllo deve cercarlo dove
> finisce davvero, e clangd lo trova solo se è alla radice o se `.clangd` gli dice
> dove guardare. Se sta in `build/`, l'advice dell'health check deve dirlo — è il
> secondo passo che manca a metà dei progetti C++.

## 5. Ciclo di lavoro risultante

1. Configurare una volta:
   `cmake -S . -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`.
2. Aprire un `.cpp`: clangd trova `compile_commands.json` fra i propri `root_markers` e
   si attacca conoscendo i flag reali del progetto.
3. Completion, diagnostica, clang-tidy, hover, definizioni, riferimenti e rinomina
   dalle mapping `<Leader>l` già esistenti.
4. `:LspClangdSwitchSourceHeader` per il salto header ↔ sorgente.
5. `:make` per costruire, `]q` e `[q` di `mini.bracketed` per camminare gli errori.
6. `<Leader>lf` sulle righe cambiate, `<Leader>lF` sul buffer intero.

## 6. Ambiente di progetto

Due casi che **non** appartengono a questa config e vanno in un `.nvim.lua` del
progetto (`:h 'exrc'`, già abilitato). La skill `nvim-project-environment` tiene il
registro dei progetti già configurati:

- un progetto di **C puro** che vuole `.h` come `c`: `vim.g.c_syntax_for_h = true`;
- un progetto la cui build non sta in `build/`, o che usa un preset: lì cambia il
  `makeprg`, non il compiler plugin condiviso.

## 7. Verifica

Oltre alla passata generale di `nvim-config-testing`, i controlli falsificabili propri
del C++:

- `:InspectTree` su un `.cpp` mostra un albero e non il solo syntax fallback;
- `:checkhealth vim.lsp` mostra **un solo** client `clangd`, con root sulla directory
  che contiene `compile_commands.json` e non su quella del `.git`;
- in un file con un `#include` di una dipendenza del progetto, **nessuna diagnostica di
  "file not found"**. È la prova che il compilation database è stato letto davvero, ed è
  l'unico modo di distinguere clangd informato da clangd che indovina;
- una diagnostica di `clang-tidy` — non del compilatore — compare su codice che la
  merita: è la prova che `--clang-tidy` è arrivato al server;
- `:LspClangdSwitchSourceHeader` da un `.cpp` apre il suo header. **È anche il modo di
  accorgersi che un `after/lsp/clangd.lua` ha sovrascritto `on_attach`**: se il comando
  non esiste, è successo esattamente quello;
- `:make` su un file con un errore di sintassi riempie il quickfix e `]q` salta alla
  riga giusta. Va provato con una build che fallisce, non con una che passa;
- `:ConformInfo` dichiara `clang-format` disponibile e `<Leader>lf` tocca solo
  l'intervallo richiesto;
- `:checkhealth config` segnala correttamente toolchain, parser e compilation database.

## 8. Decisioni rinviate

- **Debug.** `Termdebug` richiede gdb; con LLVM c'è `lldb`, che non parla il protocollo
  MI che Termdebug usa. Le strade sono installare gdb a parte (MSYS2/MinGW) o
  `nvim-dap` con `codelldb`. Scelta di workflow, separata.
- **`gf` su `#include`.** Servirebbe `path`, e i path di sistema in una config
  condivisa sono sbagliati per costruzione. Si riapre solo se `gd` di LSP si dimostra
  insufficiente.
- **`cmake-language-server`.** Un secondo server per i soli `CMakeLists.txt`. Il parser
  `cmake` dà già l'highlighting; il server si adotta solo se i file CMake diventano un
  posto in cui si lavora, non uno che si legge.
- **`.clang-tidy` condiviso.** Le regole appartengono al progetto, non alla config.
- **MSVC come secondo compilatore** per le build di release (§2).

## 9. Il ponte con Godot: GDExtension

GDExtension è il modo in cui un gioco Godot 4 esegue C++ nativo: una libreria condivisa
costruita contro `godot-cpp` e dichiarata al motore da un file `.gdextension`. Dal punto
di vista di Neovim **non è un linguaggio nuovo**: è un progetto C++ come gli altri, e
tutto ciò che c'è sopra vale invariato.

Tre cose in più, e una sola richiede una riga di config:

1. **`.gdextension` non è riconosciuto** (misurato: nessun match). Ha la forma di un
   INI. Si risolve nell'`ftdetect/godot.lua` descritto in
   `analisi_funzionale_godot.md` §7, insieme a `.gdshaderinc`. È l'unico file
   che GDExtension aggiunge.
2. **Il compilation database**, che è l'unica vera differenza operativa. `godot-cpp` si
   costruisce con **SCons**, non con CMake, e clangd senza `compile_commands.json` su un
   progetto GDExtension è cieco esattamente come su qualunque altro.

   > **Da verificare sul checkout reale**, prima di scriverlo nell'health check: quale
   > dei due percorsi il progetto usa. SCons può emettere il database
   > (`scons compiledb=yes`), e le versioni recenti di `godot-cpp` espongono anche un
   > `CMakeLists.txt`. Se il percorso è CMake, GDExtension non aggiunge nulla a §4.5;
   > se è SCons, l'advice dell'health check deve nominare il comando di SCons e non
   > quello di CMake. **Non scrivere l'advice senza aver guardato quale dei due c'è.**

3. **Godot va installato** — oggi non lo è. Vale per GDScript e per GDExtension insieme,
   ed è il passo zero dell'altro documento.

La conseguenza sull'ordine dei lavori: **il supporto C++ va fatto per primo e non va
reso Godot-specifico.** GDExtension eredita clangd, `clang-format`, i parser e il
quickfix senza aggiungere niente, e ciò che gli è proprio si riduce a un `ftdetect` e a
una riga nell'health check.

## 10. Ordine di implementazione

1. `winget install LLVM.LLVM`; `mise use -g cmake@4 ninja@1.13`; `mise install`.
   Verificare che `%LOCALAPPDATA%\mise\shims` sia nel `PATH` di sistema.
2. Parser, `clangd` abilitato, `clang-format`: tre modifiche a `plugin/40_plugins.lua`.
3. `after/lsp/clangd.lua`, con il solo `cmd`.
4. **Misurare** l'output di una build CMake fallita (§4.3), poi scrivere
   `compiler/cmake.lua` e `after/ftplugin/cpp.lua`.
5. **Misurare** dove finisce `compile_commands.json` (§4.5), poi `check_cpp()`.
6. Verifica (§7).
7. Solo dopo, Godot come integrazione separata.

Parser, server, quickfix e health check risolvono problemi diversi: sono commit
distinti, come chiede `AGENTS.md`. E l'aggiornamento della skill
`nvim-language-support` — una `references/cpp.md` nuova, con l'esito delle fasi 1 e 2 —
è un commit ancora a parte, come prescrive la sua Fase 6.

## Fonti

- Inventario: misurato su questa macchina, Neovim 0.12.5, config `configs/nvim-0.12`,
  2026-09-13.
- [clangd: compile_commands.json](https://clangd.llvm.org/installation#compile_commandsjson)
- [clangd: estensione `switchSourceHeader`](https://clangd.llvm.org/extensions.html#switch-between-sourceheader)
- [nvim-lspconfig: configurazione `clangd`](https://github.com/neovim/nvim-lspconfig/blob/master/lsp/clangd.lua)
- [CMake: `CMAKE_EXPORT_COMPILE_COMMANDS`](https://cmake.org/cmake/help/latest/variable/CMAKE_EXPORT_COMPILE_COMMANDS.html)
- [Godot: GDExtension in C++](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/gdextension_cpp_example.html)
- `:h write-compiler-plugin`, `:h vim.lsp.config()`, `:h terminal-debug`,
  `:h lsp-defaults`
