# Rust

Dossier di riferimento. I fatti sul runtime sono verificati su questa macchina
(Neovim 0.12.4, Windows, `rustup` con Rust 1.98 stabile).

L'impostazione dell'ambiente segue **Zero To Production In Rust** di Luca Palmieri,
in particolare l'*inner development loop* rapido del capitolo iniziale e gli
strumenti che il libro mette in CI (`clippy`, `fmt`, `audit`). La mappatura di quelle
abitudini su Neovim è in [§5](#5-il-ciclo-di-lavoro-make-e-quickfix).

## 1. Cosa il runtime dà già

**Neovim spedisce l'intero 'rust.vim' nel proprio runtime.** È la sorpresa che
cambia l'ambito del lavoro. Verificabile con
`:echo globpath(&rtp, 'ftplugin/rust.vim')` e `:h ft-rust`.

Da `$VIMRUNTIME/ftplugin/rust.vim`, all'apertura di un `.rs`:

| Cosa | Dettaglio |
|---|---|
| Stile ufficiale | `shiftwidth=4 softtabstop=4 expandtab textwidth=100` (`:h g:rust_recommended_style`) |
| Commenti | `commentstring=// %s` e `comments` che gestisce `///`, `//!`, `/* */` |
| `gf` sugli import | `include`, `includeexpr`, `suffixesadd=.rs`: il cursore su un `use` salta al file |
| `%` esteso | `matchpairs+=<:>` e `b:match_skip` che evita di confondersi con `->` |
| Movimenti | `[[` e `]]` per elemento di livello superiore |
| Comandi | `:RustFmt`, `:RustTest`, `:RustRun`, `:RustPlay`, `:RustExpand`, `:RustInfo` (`:h rust-commands`) |
| Comandi cargo | `:Cargo`, `:Ccheck`, `:Cbuild`, `:Ctest`, `:Crun`, `:Cdoc`, … |
| Compiler | **sceglie da solo**: `compiler cargo` se trova un `Cargo.toml` risalendo, altrimenti `compiler rustc` |
| Formattazione al salvataggio | disponibile ma **disattivata**, si abilita con `g:rustfmt_autosave` |

E in `$VIMRUNTIME/compiler/cargo.vim` (che include `rustc.vim`):

- `makeprg=cargo $*` — quindi `:make check`, `:make test`, `:make clippy` funzionano
  senza configurare niente;
- un `errorformat` che riconosce il formato di `rustc` (inclusa la riga
  `--> file:riga:col`), scarta il rumore di avanzamento **e cattura i panic dei
  test**: `panicked at '...', file:riga:col`.

Ci sono anche `indent/rust.vim`, `syntax/rust.vim`, e per i manifesti
`ftplugin/toml.vim` con `syntax/toml.vim`.

**Conseguenza pratica**: in un progetto cargo, appena aperto un `.rs`, `:make check`
compila e mette gli errori nel quickfix, e `]q` ci salta sopra. Confermalo con
`:verbose setlocal makeprg? errorformat?` prima di scrivere qualsiasi cosa.

## 2. Cosa di questo è invecchiato

Applicando i criteri della Fase 2, il runtime Rust si divide nettamente in due.

**Ancora ottimo, da tenere.** I compiler plugin sono manutenuti: l'intestazione di
`compiler/rustc.vim` porta modifiche del **dicembre 2025** ("detect more errors"),
e `ftplugin/rust.vim` del dicembre 2025. Non sono file abbandonati. `makeprg`,
`errorformat`, `commentstring`, `includeexpr` e lo stile ufficiale sono la base su
cui il resto poggia: sostituirli non porta niente.

**Invecchiato, perché precede LSP e tree-sitter.** Il resto di 'rust.vim' nasce
quando in Vim non c'era altro:

- `syntax/rust.vim` — sostituito dal parser tree-sitter appena lo si installa;
- i comandi che invocano `cargo` in modo sincrono (`:Ccheck`, `:Ctest`) — fanno
  quello che fa `:make`, che è integrato con il quickfix;
- `rust#Jump()` dietro `[[` e `]]` — navigazione a espressioni regolari, dove
  l'albero sintattico sa la risposta esatta;
- `rustfmt#PreWrite()` — formattazione via comando esterno, dove esistono
  'conform.nvim' e il server.

Nessuna di queste è rotta; semplicemente non è più la strada migliore. Il progetto a
monte, `rust-lang/rust.vim`, è in manutenzione conservativa: riceve fix, non nuove
direzioni.

## 3. Quali plugin valutare, e cosa costano

Due plugin coprono ciò che runtime e LSP puro non danno. Sono decisioni di natura
diversa e vanno prese separatamente.

### `rustaceanvim` — sostituisce la configurazione del server

[mrcjkb/rustaceanvim](https://github.com/mrcjkb/rustaceanvim). Richiede
**Neovim >= 0.12** (compatibile) e `rust-analyzer` installato. Non si chiama
`setup()`: si attiva attraverso il sistema dei filetype.

Cosa aggiunge, oltre a `rust-analyzer` configurato a mano:

- **runnables e debuggables**: eseguire il test o il binario sotto il cursore, e
  lanciarlo sotto debugger (con 'nvim-dap' e un adapter);
- **espansione ricorsiva delle macro**, che in un progetto pieno di macro procedurali
  — quello del libro lo è — è la funzione che più spesso manca;
- **`view HIR` / `MIR`**, grafo delle crate, `docs.rs` per il simbolo sotto il cursore;
- **spiegazione dei codici di errore**, structural search replace, azioni di codice
  raggruppate.

**Il costo vero non è l'installazione, è l'esclusività.** La sua documentazione
avverte di *non* configurare `rust_analyzer` a mano né via 'nvim-lspconfig', perché
i due entrano in conflitto. Adottarlo significa quindi che `after/lsp/rust_analyzer.lua`
non è più il posto dove si configura il server: la configurazione si sposta dentro le
opzioni del plugin. È una scelta consapevole, non un'aggiunta.

**Raccomandazione**: parti dalla configurazione diretta del server (§4). È coerente
con l'ordine di preferenza, tiene la config leggibile e copre completamento,
diagnostica, navigazione e rename. Passa a `rustaceanvim` quando emerge un'esigenza
concreta che non copre — tipicamente il debug o l'esecuzione dei singoli test — e
quando arriva quel momento, migra la configurazione, non affiancarla.

### `crates.nvim` — additivo, nessun conflitto

[saecki/crates.nvim](https://github.com/saecki/crates.nvim) lavora **solo su
`Cargo.toml`**: completamento delle versioni, popup con versioni, feature e
dipendenze, virtual text con l'ultima disponibile, aggiornamento delle dipendenze.

Non tocca l'LSP di Rust e non ha niente a che vedere con `rustaceanvim`: si può
adottare da solo. Va attivato sull'apertura del manifesto (`BufRead Cargo.toml`), non
all'avvio, così non pesa su una sessione che non apre mai quel file. È l'asse §11 del
catalogo, e resta una comodità: proponilo, non darlo per scontato.

## 4. Installazione e configurazione del server

### Installare `rust-analyzer`

Su questa macchina **non è installato**: l'eseguibile risponde
`error: Unknown binary 'rust-analyzer.exe' in official toolchain`. Due vie, e per
Rust non sono equivalenti:

- **`rustup component add rust-analyzer`** — è la via ufficiale del linguaggio, e
  installa la versione **allineata al toolchain attivo**. Per un linguaggio che
  rilascia ogni sei settimane e ha un server sviluppato insieme al compilatore,
  l'allineamento conta. Aggiungi anche `rustup component add rust-src`, senza cui il
  server non analizza la libreria standard.
- **`mise use -g rust-analyzer@latest`** — la via uniforme con tutto il resto della
  toolchain (Fase 4 di `SKILL.md`); il binario arriva dal backend `aqua`
  (`aqua:rust-lang/rust-analyzer`) ed è indipendente dal toolchain.

**Per Rust preferisci `rustup`**, e lascia a `mise` gli strumenti che non hanno un
canale ufficiale altrettanto stretto. Il criterio generale — un solo posto dove sono
dichiarate le dipendenze — vale finché non peggiora il risultato; qui lo
peggiorerebbe, e il health check è comunque il punto in cui la dipendenza viene
registrata e verificata.

### `after/lsp/rust_analyzer.lua`

Scheletro nella forma di 'after/lsp/lua_ls.lua'. **Verifica i nomi delle
impostazioni** contro il manuale della versione installata: sono definiti dal server
e cambiano nel tempo.

```lua
-- ┌───────────────────────────────┐
-- │ Language server configuration │
-- └───────────────────────────────┘
--
-- This file contains configuration of 'rust-analyzer' language server.
-- Source: https://github.com/rust-lang/rust-analyzer
-- Install with `rustup component add rust-analyzer rust-src` to get the version
-- that matches the active toolchain.
--
-- The structure of `settings` comes from rust-analyzer, not from Neovim.
return {
  settings = {
    ['rust-analyzer'] = {
      -- Report `clippy` lints while typing instead of only in CI. Rust's own
      -- linter is what catches the mistakes `rustc` accepts.
      check = { command = 'clippy' },

      -- Procedural macros are what `#[tokio::main]` and `sqlx::query!` expand
      -- to. Without this the code inside them is invisible to the server and
      -- gets reported as errors.
      procMacro = { enable = true },
    },
  },
}
```

Poi il nome in `vim.lsp.enable({ 'lua_ls', 'rust_analyzer' })` in
'plugin/40_plugins.lua', decommentando la chiamata già preparata lì.

**Da proporre, non da decidere**: gli inlay hint
(`vim.lsp.inlay_hint.enable()` in `on_attach`) — in Rust mostrano i tipi inferiti e i
nomi dei parametri, utili quanto invadenti; e `cargo.features`, che dipende dal
progetto e quindi appartiene al suo `.nvim.lua` (§7).

## 5. Il ciclo di lavoro: `:make` e quickfix

Il libro insiste su un inner development loop stretto e sul fatto che `cargo check`
sia molto più rapido di `cargo build`. Con `makeprg=cargo $*` già impostato, quel
ciclo si fa senza uscire dall'editor:

| Comando | Cosa fa | Nel libro |
|---|---|---|
| `:make check` | compila senza generare codice, errori nel quickfix | il passo centrale dell'inner loop |
| `:make test` | esegue i test; i panic finiscono nel quickfix | `cargo test`, inclusi i test in `tests/` |
| `:make clippy` | i lint di clippy nel quickfix | il controllo che il libro mette in CI |
| `:make fmt -- --check` | segnala i file non formattati | idem |

Navigazione con `:copen`, `]q` e `[q`. `'switchbuf'` è già `usetab`, quindi saltare a
un errore riusa una finestra esistente.

Due limiti da dire all'utente invece di aggirarli con del codice:

- **`:make` blocca l'interfaccia** finché cargo non finisce. Per `check` è
  impercettibile; per una build completa conviene il terminale (`<Leader>tt`). Il
  libro affronta lo stesso problema con `cargo watch`: se l'utente lo usa, la sede
  naturale è un terminale di fianco, non un'integrazione da scrivere.
- **I tempi di link dominano** le build incrementali. Il libro consiglia un linker
  più veloce (`lld`, `mold`) in `.cargo/config.toml`: è la modifica che rende
  `:make check` immediato, e non richiede niente a Neovim.

Con il server attivo e `check.command = 'clippy'` gli stessi errori compaiono già
come diagnostica. `:make` resta utile per eseguire i test, vedere l'output completo,
e lavorare senza server.

## 6. Tree-sitter

Aggiungi `'rust'` e `'toml'` alla tabella `languages` in 'plugin/40_plugins.lua'.
`toml` serve per `Cargo.toml`, che in un progetto Rust si legge quanto il codice.

Cosa si sblocca: highlight moderno al posto di `syntax/rust.vim`, fold per struttura
(`'foldexpr'` = `v:lua.vim.treesitter.foldexpr()` in `after/ftplugin/rust.lua`),
textobject via `MiniAi.gen_spec.treesitter()` su `vim.b.miniai_config` (`daf` su una
funzione, `cif` sul corpo), e le injection.

**L'injection che vale la pena** in un progetto che segue il libro: `sqlx::query!`
prende SQL come stringa letterale verificata a compile time, ma nell'editor resta una
stringa grigia. Un `after/queries/rust/injections.scm` che riconosce quelle macro e
inietta `sql` restituisce l'evidenziazione. Ricorda `; extends` sulla prima riga:
senza, sostituisce tutte le injection di 'nvim-treesitter' invece di aggiungersi, in
silenzio. Verifica prima con `:InspectTree` che il parser non la copra già.

**'mini.pairs' e le lifetime**: in Rust l'apice singolo di `&'a str` non apre una
stringa. Il default di 'mini.pairs' non auto-chiude l'apice dopo una lettera, ma dopo
`&` sì. Se dà fastidio, si corregge in `after/ftplugin/rust.lua` con
`MiniPairs.unmap_buf()` o `map_buf()` — **non** con `vim.b.minipairs_config`, che per
quel modulo non ha effetto (§10 del catalogo).

## 7. Toolchain e ambiente di progetto

- **`rustup` resta il version manager del linguaggio.** Invocare il server come
  `rust-analyzer` semplice fa passare la chiamata dal proxy di `rustup`, che rispetta
  il `rust-toolchain.toml` del progetto; un percorso assoluto no. Motivo in più per
  non impostare `cmd` a mano.
- **La toolchain attiva è quella della shell che ha lanciato Neovim** (§14 del
  catalogo). Il health check deve dirla.
- **`sqlx` e `DATABASE_URL`**: le macro `query!` interrogano il database durante la
  compilazione, quindi il server ha bisogno della stessa variabile che serve a
  `cargo`, o dei metadati offline (`SQLX_OFFLINE`, prodotti da `cargo sqlx prepare`)
  che il libro introduce per non dipendere da un database in CI. Se il server segnala
  errori sulle `query!` mentre `cargo` compila, è quasi sempre questo. La sede è il
  `.nvim.lua` del progetto (`'exrc'` è già abilitato):

  ```lua
  -- .nvim.lua nella radice del progetto
  vim.env.SQLX_OFFLINE = 'true'
  ```

## 8. Health check

Una `check_rust()` in `lua/config/health.lua` che risponda alle domande che ci si fa
quando qualcosa non va:

- `rustup` c'è? Quale toolchain è attiva in **questa** sessione
  (`rustup show active-toolchain`)?
- `cargo` e `rustc`, con che versione?
- `rust-analyzer` è raggiungibile? Oggi **no**: il consiglio nel `warn()` è
  `rustup component add rust-analyzer rust-src`.
- Il parser `rust` è installato, non solo disponibile?

## 9. Verifica da consegnare all'utente

```
1. rustup component add rust-analyzer rust-src   (nella shell, una volta)
2. Riavvia Neovim; aspetta l'installazione dei parser
   :checkhealth nvim-treesitter          — rust e toml installati
3. Apri un file .rs dentro un progetto cargo
4. :InspectTree                          — l'albero c'è
5. :verbose setlocal makeprg?            — cargo, da $VIMRUNTIME/compiler/cargo.vim
6. :checkhealth vim.lsp                  — rust_analyzer attaccato, nessun errore
7. Introduci un errore e salva
   :make check                           — l'errore è nel quickfix, `]q` ci salta;
                                           la diagnostica compare anche in linea
8. :make test                            — un test fallito è navigabile dal quickfix
9. <Leader>ls su un simbolo di dipendenza — apre il sorgente nel registry
10. gf con il cursore su un `use`         — apre il modulo (built-in, senza LSP)
11. :checkhealth config                   — la sezione Rust dice il vero
```

## 10. Commit

```
feat(plugins): Rust files have no syntax tree
feat(lsp): Rust code has no diagnostics, completion or navigation
feat(ftplugin): Rust buffers do not fold by structure
feat(health): a missing Rust toolchain is only discovered when it fails
```

Non compare un commit per il quickfix o per l'indentazione: quelli il runtime li fa
già, e un commit che li "aggiunge" sarebbe la prova che la Fase 1 è stata saltata.
