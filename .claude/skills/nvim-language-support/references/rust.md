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

### I due plugin da valutare

Sono decisioni indipendenti e di natura diversa.

**[`rustaceanvim`](https://github.com/mrcjkb/rustaceanvim)** — richiede Neovim ≥ 0.12
(compatibile) e `rust-analyzer`. Aggiunge runnables e debuggables (eseguire il test
sotto il cursore, anche sotto debugger), **espansione ricorsiva delle macro** — in un
progetto pieno di macro procedurali come quello del libro è la funzione che più
spesso manca — `view HIR`/`MIR`, grafo delle crate, `docs.rs` per il simbolo sotto il
cursore, spiegazione dei codici di errore, structural search replace.

Il costo non è l'installazione: è che **prende possesso del server**. La sua
documentazione chiede di non configurare `rust_analyzer` a mano né via
'nvim-lspconfig'. È quindi il caso esclusivo descritto nella Fase 2: o il plugin, o
`after/lsp/rust_analyzer.lua`. **Raccomandazione**: partire dalla configurazione
diretta del server (§3), che copre completamento, diagnostica, navigazione e rename,
e passare a `rustaceanvim` solo quando emerge un'esigenza che non copre — tipicamente
il debug o l'esecuzione dei singoli test — migrando la configurazione, non
affiancandola.

**[`crates.nvim`](https://github.com/saecki/crates.nvim)** — lavora solo su
`Cargo.toml`: completamento delle versioni, popup con versioni e feature, virtual
text con l'ultima disponibile. Non tocca l'LSP di Rust, quindi è additivo e
indipendente dalla scelta precedente. Va attivato su `BufRead Cargo.toml`.

## 3. Fase 4 — installazione

Su questa macchina `rust-analyzer` **non è installato**: l'eseguibile risponde
`error: Unknown binary 'rust-analyzer.exe' in official toolchain`.

```bash
rustup component add rust-analyzer rust-src
```

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

**Server**: `after/lsp/rust_analyzer.lua` a partire da `assets/lsp.lua`. Due
impostazioni valgono più di tutte le altre:

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
  },
}
```

Verifica i nomi contro il manuale della versione installata: sono definiti dal
server e cambiano nel tempo. Da **proporre** e non decidere: gli inlay hint (in Rust
mostrano i tipi inferiti, utili quanto invadenti) e `cargo.features`, che dipende dal
progetto e quindi appartiene al suo `.nvim.lua`.

**Formattazione**: `rustfmt` è il formatter ufficiale, quindi va dichiarato in
`formatters_by_ft` anche se il server saprebbe formattare — stessa versione della
riga di comando e della CI.

**'mini.pairs' e le lifetime**: in Rust l'apice singolo di `&'a str` non apre una
stringa. Il default non auto-chiude l'apice dopo una lettera, ma dopo `&` sì. Si
corregge in `after/ftplugin/rust.lua` con `MiniPairs.unmap_buf()`, non con
`vim.b.minipairs_config`.

**L'injection che vale la pena**, in un progetto che segue il libro: `sqlx::query!`
prende SQL come stringa letterale verificata a compile time, ma nell'editor resta una
stringa grigia. `assets/injections.scm` è già impostato su questo caso.

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

La sede è il `.nvim.lua` del progetto — e su Windows lo è a maggior ragione, perché
gli shim di `mise` non applicano le variabili dichiarate in `mise.toml`:

```lua
-- .nvim.lua nella radice del progetto
vim.env.SQLX_OFFLINE = 'true'
```

## 7. Health check

Le domande a cui `check_rust()` deve rispondere: `rustup` c'è e quale toolchain è
attiva in **questa** sessione (`rustup show active-toolchain`); `cargo` e `rustc` con
quale versione; `rust-analyzer` è raggiungibile — oggi no, e il consiglio da dare è
il comando `rustup component add` di §3; il parser `rust` è installato, non solo
disponibile.

## 8. Verifica

Oltre ai punti generali di `SKILL.md`, quelli che valgono solo qui:

- `:verbose setlocal makeprg?` deve nominare `$VIMRUNTIME/compiler/cargo.vim`, non un
  file della config: se nomina la config, qualcosa è stato riscritto inutilmente;
- `:make test` con un test rotto deve rendere il **panic** navigabile dal quickfix,
  non solo gli errori di compilazione;
- `gf` con il cursore su un `use` deve aprire il modulo **senza** che il server sia
  attaccato: è il built-in, e verifica che non sia stato perso;
- `<Leader>ls` su un simbolo di una dipendenza deve aprire il sorgente nel registry.
