# Rust

L'esito delle Fasi 1 e 2 per Rust, già svolte e verificate su questa macchina
(Neovim 0.12.4, Windows, `rustup` con Rust 1.98 stabile). Le fasi successive
seguono la procedura di `SKILL.md`; qui c'è solo ciò che è specifico del linguaggio.

L'impostazione dell'ambiente segue **Zero To Production In Rust** di Luca Palmieri,
in particolare l'*inner development loop* rapido del capitolo iniziale e gli
strumenti che il libro mette in CI.

## 1. Fase 1 — cosa il runtime dà già

**Neovim spedisce l'intero 'rust.vim' nel proprio runtime**, ed è ciò che riduce il
lavoro a poche cose. All'apertura di un `.rs` (`:h ft-rust`):

| Cosa | Dettaglio |
|---|---|
| Stile ufficiale | `shiftwidth=4 softtabstop=4 expandtab textwidth=100` (`:h g:rust_recommended_style`) |
| Commenti | `commentstring=// %s` e `comments` che gestisce `///`, `//!`, `/* */` |
| `gf` sugli import | `include`, `includeexpr`, `suffixesadd=.rs`: il cursore su un `use` salta al file |
| `%` esteso | `matchpairs+=<:>` e `b:match_skip` (inerte finché matchit non è caricato) |
| Comandi | `:RustFmt`, `:RustTest`, `:RustRun`, `:RustExpand`, `:RustInfo` (`:h rust-commands`) |
| Comandi cargo | `:Cargo`, `:Ccheck`, `:Cbuild`, `:Ctest`, `:Crun`, `:Cdoc`, … |
| Compiler | **sceglie da solo**: `compiler cargo` se trova un `Cargo.toml` risalendo, altrimenti `compiler rustc` |
| Formattazione al salvataggio | disponibile ma disattivata, si abilita con `g:rustfmt_autosave` |

E in `$VIMRUNTIME/compiler/cargo.vim` (che include `rustc.vim`): `makeprg=cargo $*`,
più un `errorformat` che riconosce il formato di `rustc` con la riga
`--> file:riga:col`, scarta il rumore di avanzamento **e cattura i panic dei test**
(`panicked at '...', file:riga:col`).

**In pratica**: in un progetto cargo, appena aperto un `.rs`, `:make check` compila e
mette gli errori nel quickfix, e `]q` ci salta sopra. Nessuna riga di configurazione.

## 2. Fase 2 — cosa di questo tenere

Il runtime Rust si divide nettamente in due, e la data in cima ai file lo dice.

**Da tenere.** I compiler plugin sono manutenuti: `compiler/rustc.vim` porta
modifiche del **dicembre 2025** ("detect more errors"), `ftplugin/rust.vim` pure. Non
sono file abbandonati, e `makeprg`, `errorformat`, `commentstring`, `includeexpr` e
lo stile ufficiale sono esattamente le opzioni su cui poggiano `:make`,
'mini.comment', `gf` e gli operatori di rientro.

**Invecchiato, perché precede LSP e tree-sitter.** `syntax/rust.vim`, sostituito dal
parser appena lo si installa; i comandi che invocano `cargo` in modo sincrono
(`:Ccheck`, `:Ctest`), che fanno ciò che fa `:make` senza integrarsi col quickfix;
`rust#Jump()` dietro `[[` e `]]`, navigazione a espressioni regolari dove l'albero sa
la risposta esatta; `rustfmt#PreWrite()`, dove ci sono 'conform.nvim' e il server.

Niente di tutto questo è rotto: semplicemente non è più la strada migliore. Il
progetto a monte, `rust-lang/rust.vim`, è in manutenzione conservativa.

### Il livello che si dimentica: 'nvim-lspconfig'

Prima di valutare i plugin va detto cosa c'è già, perché per Rust è molto più del
solito. Il config installa 'nvim-lspconfig' (`plugin/40_plugins.lua`, sezione
"Language servers"), quindi `after/lsp/rust_analyzer.lua` **non è la configurazione
del server**: è un override che si fonde sopra
[`lsp/rust_analyzer.lua`](https://github.com/neovim/nvim-lspconfig/blob/master/lsp/rust_analyzer.lua),
il quale non è il consueto `cmd` + `filetypes` + `root_markers`:

| Cosa fa | Perché conta |
|---|---|
| `root_dir` chiama `cargo metadata --no-deps` | trova la **workspace root** vera, non il primo `Cargo.toml` risalendo: è la differenza nei progetti multi-crate |
| riconosce i file dentro registry, git checkout, toolchain e sysroot src | il sorgente di una dipendenza si attacca al client già attivo invece di aprirne uno nuovo |
| dichiara `serverStatusNotification` e implementa `rust-analyzer.runSingle` | **i runnable ci sono già**, senza plugin |
| accende tutti i lens (`run`, `debug`, `implementations`, `references`, `updateTest`) | vedi §4: accesi non vuol dire visibili |
| crea `:LspCargoReload` | ricarica il workspace cargo dopo un cambio di `Cargo.toml` |
| `before_init` copia `settings['rust-analyzer']` in `initializationOptions` | `rust-analyzer` legge le proprie impostazioni **da lì** all'avvio. Senza quella riga le impostazioni di §4 non arrivano al server |

Da leggere prima di scrivere qualsiasi cosa, come chiede `assets/lsp.lua`:

```vim
:=vim.lsp.config['rust_analyzer']
```

### I due plugin da valutare

Sono decisioni indipendenti e di natura diversa.

**[`rustaceanvim`](https://github.com/mrcjkb/rustaceanvim)** — richiede Neovim ≥ 0.12
(compatibile) e `rust-analyzer`. Tolto ciò che 'nvim-lspconfig' già copre, quello che
resta suo è: **espansione ricorsiva delle macro** — in un progetto pieno di macro
procedurali come quello del libro è la funzione che più spesso manca — `view HIR`/`MIR`,
grafo delle crate, `docs.rs` per il simbolo sotto il cursore, spiegazione dei codici
di errore, structural search replace, e runnable e debuggable fatti bene: asincroni e
agganciati a 'nvim-dap'.

Il costo non è l'installazione: è che **prende possesso del server**. La sua
documentazione chiede di non configurare `rust_analyzer` a mano né via
'nvim-lspconfig'. È quindi il caso esclusivo descritto nella Fase 2: o il plugin, o
`after/lsp/rust_analyzer.lua`. **Raccomandazione**: partire dalla configurazione
diretta del server (§4) — che con il livello di 'nvim-lspconfig' sotto copre
completamento, diagnostica, navigazione, rename, runnable e reload del workspace — e
passare a `rustaceanvim` solo quando emerge un'esigenza che non copre, tipicamente le
macro o il debug, migrando la configurazione e non affiancandola.

**[`crates.nvim`](https://github.com/saecki/crates.nvim)** — lavora solo su
`Cargo.toml`: completamento delle versioni, popup con versioni e feature, virtual
text con l'ultima disponibile. Non tocca l'LSP di Rust, quindi è additivo e
indipendente dalla scelta precedente. Va attivato su `BufRead Cargo.toml`.

## 3. Fase 4 — installazione

```bash
rustup component add rust-analyzer rust-src
```

Fatto: su questa macchina il server è `rust-analyzer 1.98.0 (88d9e12a 2026-08-18)`,
cioè lo stesso commit di `rustc 1.98.0` — che è il motivo per cui `rustup` è la via
giusta qui. `rust-src`, `clippy` e `rustfmt` erano già installati.

Vale qui la regola di `AGENTS.md` sui canali ufficiali: `rustup` installa la versione
**allineata al toolchain attivo**, e per un linguaggio che rilascia ogni sei
settimane con un server sviluppato insieme al compilatore l'allineamento conta.
`rust-src` è necessario perché il server analizzi la libreria standard. `mise`
resta la via per gli strumenti che non hanno un canale altrettanto stretto.

`rustup` è anche il motivo per non impostare `cmd` a mano nella config del server:
invocato come `rust-analyzer` semplice, la chiamata passa dal proxy di `rustup`, che
rispetta il `rust-toolchain.toml` del progetto; un percorso assoluto no.

## 4. Fase 5 — cosa implementare

**Tree-sitter**: `'rust'` e `'toml'` nella tabella `languages`. `toml` serve per
`Cargo.toml`, che in un progetto Rust si legge quanto il codice. Sblocca l'highlight
moderno, il fold per struttura, i textobject via `MiniAi.gen_spec.treesitter()` e le
injection.

### Il server: `after/lsp/rust_analyzer.lua`

**Solo `settings`, nessuna funzione.** È la regola generale di `SKILL.md`, sezione
"I livelli si sovrappongono"; per `rust_analyzer` è quella che costa di più, perché il
default di 'nvim-lspconfig' definisce tre funzioni e ciascuna porta via qualcosa:

- un `on_attach` — proprio ciò che lo scheletro invita a scrivere — cancella
  `:LspCargoReload`;
- un `before_init` cancella la riga che riempie `initializationOptions`, e siccome
  `rust-analyzer` legge le proprie impostazioni all'avvio da lì, `check.command` e
  `procMacro` qui sotto **non arrivano mai al server**. Nessun errore e nessun
  avviso: semplicemente clippy non gira;
- un `root_dir` cancella `cargo metadata` e il riconoscimento dei sorgenti delle
  dipendenze.

Se serve comportamento buffer-locale con il server attaccato, la sede è un
autocomando `LspAttach` in `after/ftplugin/rust.lua`, non un `on_attach` qui.

```lua
settings = {
  ['rust-analyzer'] = {
    -- Report `clippy` lints while typing instead of only in CI. Rust's own
    -- linter is what catches the mistakes `rustc` accepts.
    check = { command = 'clippy' },

    -- Procedural macros are what `#[tokio::main]` and `sqlx::query!` expand to.
    -- Without this the code inside them is invisible to the server and gets
    -- reported as errors.
    procMacro = { enable = true },

    -- 'nvim-lspconfig' turns every lens on and tells the server that three
    -- client commands are implemented, while only `runSingle` is.
    -- `showReferences` is filled in by 'plugin/40_plugins.lua'; `debugSingle`
    -- asks for a debugger and not a handful of lines, so the "Debug" lens fails
    -- when run. Turn it back on together with a DAP client, not before.
    lens = { debug = { enable = false } },
  },
}
```

Verifica i nomi contro il manuale della versione installata: sono definiti dal
server e cambiano nel tempo. Da **proporre** e non decidere: gli inlay hint (in Rust
mostrano i tipi inferiti, utili quanto invadenti) e `cargo.features`, che dipende dal
progetto e quindi appartiene al suo `.nvim.lua`.

### Tre limiti del livello ereditato, da conoscere prima di stupirsi

**I lens erano accesi ma invisibili**, e la causa non era di Rust: Neovim non chiede
i code lens a nessun server finché non glielo si dice. La riga che li accende è
`vim.lsp.codelens.enable(true)` in `plugin/40_plugins.lua` — una sola, globale, valida
per ogni server e per ogni buffer aperto dopo. **Non** un autocomando su
`vim.lsp.codelens.refresh()`, che è la forma precedente: deprecata in 0.12 e rimossa
in 0.13.

**`showReferences` non esisteva.** 'nvim-lspconfig' dichiara al server, tra le
`capabilities`, che il client sa eseguire `rust-analyzer.showReferences`, e poi
registra solo `runSingle`: i lens "N implementations" e "N references" finivano
quindi in *"Language server `rust_analyzer` does not support command"*. È un
comando **client-side** per costruzione — il server consegna le posizioni che ha
già calcolato e l'editor decide come mostrarle — quindi bastano poche righe, e
stanno in `plugin/40_plugins.lua` accanto a `vim.lsp.codelens.enable(true)`:
`vim.lsp.commands` è un registro globale, mentre `after/lsp/rust_analyzer.lua`
non può ospitare funzioni senza cancellare quelle ereditate. Una posizione sola
apre il punto, più di una riempie il quickfix.

**`runSingle` blocca Neovim.** L'implementazione di 'nvim-lspconfig' fa `proc:wait()`
sul thread principale e poi rovescia l'output in un `vim.notify`: per un `cargo test`
significa editor fermo finché non finisce, e risultato in un popup invece che nel
quickfix. È lo stesso difetto già analizzato — e già risolto sulla carta — nel
commento sopra i mapping `<Leader>l` di `plugin/20_keymaps.lua`: eseguire con
`vim.system()` e passare l'output a `setqflist()` con l'`errorformat` del buffer.
Finché resta così, `:make test` (§5) è la strada migliore per eseguire i test.

### Il resto

**Formattazione**: `rustfmt` è il formatter ufficiale, quindi va dichiarato in
`formatters_by_ft` anche se il server saprebbe formattare — stessa versione della
riga di comando e della CI.

**'mini.pairs' e le lifetime**: in Rust l'apice singolo di `&'a str` non apre una
stringa. Il default non auto-chiude l'apice dopo una lettera, ma dopo `&` sì, quindi
`&'` diventa `&''`. La sede è `after/ftplugin/rust.lua`, ma **due dei rimedi che
verrebbero in mente non funzionano**: `vim.b.minipairs_config`, perché il modulo non
rilegge la config, e `MiniPairs.unmap_buf()`, che annulla soltanto una mapping fatta
con `MiniPairs.map_buf()` — queste vengono da `setup()` e sono globali. La via che il
modulo stesso documenta per quel caso è rimappare il tasto su sé stesso nel buffer:

```lua
vim.keymap.set('i', "'", "'", { buffer = true })
```

**L'injection che vale la pena**, in un progetto che segue il libro: `sqlx::query!`
prende SQL come stringa letterale verificata a compile time, ma nell'editor resta una
stringa grigia. Sta in `after/queries/rust/injections.scm`, e tre dettagli decidono se
la query trova qualcosa — nessuno dei quali dà errore quando è sbagliato:

- `sqlx::query!` è uno `scoped_identifier`, mentre il `query!` lasciato da un `use` è
  un `identifier`: vanno elencati entrambi;
- il testo da iniettare è `(string_content)`, non `(string_literal)`, che passerebbe
  all'altro parser anche le virgolette;
- l'ancora `.` fissa la stringa alla sua posizione nella chiamata, così il tipo che
  `query_as!` nomina per primo e un eventuale secondo argomento stringa non vengono
  letti come SQL.

E serve il parser **`sql`** nella tabella `languages`: senza, l'injection non fa
niente e non lo dice.

## 5. Il ciclo di lavoro

Il libro insiste su un inner development loop stretto e sul fatto che `cargo check`
sia molto più rapido di `cargo build`. Con `makeprg=cargo $*` già impostato:

| Comando | Cosa fa | Nel libro |
|---|---|---|
| `:make check` | compila senza generare codice, errori nel quickfix | il passo centrale dell'inner loop |
| `:make test` | esegue i test; i panic finiscono nel quickfix | `cargo test`, inclusi i test in `tests/` |
| `:make clippy` | i lint di clippy nel quickfix | il controllo che il libro mette in CI |
| `:make fmt -- --check` | segnala i file non formattati | idem |

Con il server attivo e `check.command = 'clippy'` gli stessi errori compaiono già
come diagnostica: `:make` resta utile per eseguire i test, vedere l'output completo e
lavorare senza server.

Due cose che il libro risolve fuori da Neovim e che conviene sapere: `cargo watch`
ricompila da solo, e se l'utente lo usa la sede naturale è un terminale di fianco; e
i tempi di link dominano le build incrementali, per cui un linker più veloce (`lld`,
`mold`) in `.cargo/config.toml` è ciò che rende `:make check` immediato — senza
chiedere niente all'editor.

## 6. Ambiente di progetto: `sqlx`

Le macro `query!` interrogano il database durante la compilazione, quindi il server
ha bisogno della stessa variabile che serve a `cargo`, o dei metadati offline
(`SQLX_OFFLINE`, prodotti da `cargo sqlx prepare`) che il libro introduce per non
dipendere da un database in CI. **Se il server segnala errori sulle `query!` mentre
`cargo` compila, è quasi sempre questo.**

La sede è il `.nvim.lua` del progetto, e **non** il suo `mise.toml`: quelle variabili
arrivano soltanto ai programmi lanciati da uno shim di `mise`, mentre `rust-analyzer`
lo avvia Neovim per conto proprio, attraverso il proxy di `rustup`.

```lua
-- .nvim.lua nella radice del progetto
vim.env.SQLX_OFFLINE = 'true'
```

## 7. Health check

Le domande a cui `check_rust()` deve rispondere: `rustup` c'è e quale toolchain è
attiva in **questa** sessione (`rustup show active-toolchain`); `cargo` e `rustc` con
quale versione; `rust-analyzer` è raggiungibile, con il comando `rustup component
add` di §3 come consiglio quando non lo è; il parser `rust` è installato, non solo
disponibile.

## 8. Verifica

Oltre ai punti generali di `SKILL.md`, quelli che valgono solo qui:

- `:verbose setlocal makeprg?` deve nominare `$VIMRUNTIME/compiler/cargo.vim`, non un
  file della config: se nomina la config, qualcosa è stato riscritto inutilmente;
- `:make test` con un test rotto deve rendere il **panic** navigabile dal quickfix,
  non solo gli errori di compilazione;
- `gf` con il cursore su un `use` deve aprire il modulo **senza** che il server sia
  attaccato: è il built-in, e verifica che non sia stato perso;
- `<Leader>ls` su un simbolo di una dipendenza deve aprire il sorgente nel registry,
  e deve restare attaccato **un solo** client `rust_analyzer`: due client vogliono
  dire che il `root_dir` di 'nvim-lspconfig' è stato sostituito;
- `:LspCargoReload` deve esistere in un buffer Rust con server attaccato. È il
  canarino del merge di §4: se manca, `after/lsp/rust_analyzer.lua` ha sovrascritto
  una funzione ereditata invece di aggiungere solo `settings`;
- un lint che segnala solo clippy e non `rustc` deve comparire come diagnostica: è
  l'unica prova che `initializationOptions` è arrivato al server.
