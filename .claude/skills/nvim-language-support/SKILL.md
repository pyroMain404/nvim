---
name: nvim-language-support
description: Use when adding, extending, or fixing support for a programming language, platform, or file format — LSP server, tree-sitter parser and queries, :make and quickfix, formatter, snippets, ftplugin options, code navigation, debugging, package manager integration, toolchain installation, health check entries. Make sure to use this skill whenever the user says things like "aggiungi il supporto per <linguaggio>", "configura rust/python/go/zig", "manca l'LSP per X", "il quickfix non prende gli errori di X", "voglio compilare/testare da dentro nvim", "installa <server>", or asks where a language specific setting belongs — even when they name only one piece (just the server, just the parser), because the procedure decides what the rest of the config needs in order to stay coherent.
---

# Supporto di un nuovo linguaggio

Aggiungere il supporto per un linguaggio, una piattaforma o un formato. L'obiettivo
è triplice:

1. **Decidere** quanto di ciò che Neovim sa già fare vale la pena attivare, e cosa
   invece va preso da un modulo MINI o da un plugin esterno.
2. **Installare** le risorse necessarie in modo dichiarativo e ripetibile, non con
   comandi improvvisati che nessuno ricorda l'anno dopo (Fase 4).
3. **Mettere ogni pezzo** nel file che gli compete.

Le regole di stile, collocazione, verifica e commit sono in `AGENTS.md`, che è già
in contesto: questa skill non le ripete, le presuppone.

## Fase 1 — Inventario: cosa c'è già

**Non saltare questa fase.** È quella che distingue una configurazione di venti
righe motivate da una di duecento che duplicano il runtime. Va fatta dentro una vera
sessione, con aperto un file del linguaggio: gli ftplugin si caricano solo quando il
filetype viene effettivamente impostato.

```vim
" Il filetype viene riconosciuto? Con quale nome?
:set filetype?
:lua =vim.filetype.match({ filename = 'esempio.xyz' })

" Quali file del runtime sono già attivi per questo filetype?
:echo globpath(&rtp, 'ftplugin/<ft>.{vim,lua}')
:echo globpath(&rtp, 'indent/<ft>.{vim,lua}')
:echo globpath(&rtp, 'compiler/*.{vim,lua}')

" Chi ha impostato cosa: `:verbose` nomina il file responsabile.
" È la domanda più utile dell'intera fase.
:verbose setlocal makeprg? errorformat? commentstring? comments?
:verbose setlocal include? includeexpr? define? suffixesadd? path?
:verbose setlocal shiftwidth? expandtab? textwidth? foldmethod? keywordprg?

" Esiste una pagina di help dedicata al ftplugin built-in?
:h ft-<lang>

" Tree-sitter: il parser è disponibile, e installato?
:=vim.tbl_contains(require('nvim-treesitter').get_available(), '<lang>')
:InspectTree

" LSP: 'nvim-lspconfig' ha già un default per il server?
:=vim.lsp.config['<server>']
:checkhealth vim.lsp vim.treesitter
```

Da qui esce la lista di **cosa manca**. Riportala all'utente prima di implementare:
spesso è la parte più sorprendente del lavoro.

## Fase 2 — Il built-in basta, o serve altro?

La Fase 1 dice cosa *c'è*. Questa dice se **vale**. Ereditare qualcosa dal runtime
non significa che sia la scelta migliore: parte di ciò che Neovim spedisce sono
snapshot di plugin Vimscript nati prima di LSP e tree-sitter, manutenuti a ritmo
lento dal Vim project. Funzionano, ma a volte l'ecosistema del linguaggio si è
spostato altrove.

Non è una scelta di gusto. Applica questi criteri, in quest'ordine:

**Tieni il built-in quando**

- copre il caso d'uso senza attriti, e il costo di manutenzione è zero: si aggiorna
  con Neovim, non ha config, non si rompe;
- il plugin candidato porta soprattutto funzioni che non useresti;
- il built-in è la base su cui il resto poggia (`:compiler`, `'includeexpr'`,
  `commentstring`): sostituirlo significa perdere comportamenti che altri pezzi
  danno per scontati.

**Guarda altrove quando riconosci uno di questi segnali**

- il file del runtime è **datato o in manutenzione minima**: controlla l'intestazione
  (`Last Change:`, `Latest Revision:`) in cima al file — sono commenti veri, non
  decorativi;
- **duplica in Vimscript ciò che LSP o tree-sitter fanno meglio**: completamento a
  pattern, navigazione a tag, highlight con `syntax/`;
- **l'ecosistema del linguaggio ha un tool di riferimento** che il runtime non
  conosce (un test runner, un gestore di dipendenze, un debug adapter);
- ti accorgi di **star scrivendo la stessa funzionalità a mano**: se serve del codice
  per colmare la distanza, quel codice è già scritto e manutenuto da qualcun altro.

**Prima di installare un plugin**, l'ordine di preferenza di `AGENTS.md` resta:
built-in → modulo MINI configurato → plugin esterno. Il livello MINI si salta troppo
spesso, ed è quello che risolve più casi di quanti sembri (`references/capabilities.md`
elenca i moduli con configurazione per linguaggio). Un plugin esterno deve
**guadagnarsi il posto**: dichiara cosa porta che gli altri due livelli non danno, e
verifica che **non spenga ciò che già funziona** — alcuni chiedono esplicitamente di
non configurare il server a mano, e in quel caso la scelta è esclusiva, non additiva.

Riporta la decisione all'utente prima di installare qualcosa. Un plugin nuovo è un
impegno di manutenzione, non un dettaglio implementativo.

## Fase 3 — Decidere l'ambito

Non tutti gli assi meritano di essere attivati per ogni linguaggio. Uno che serve a
leggere qualche file altrui ha bisogno di riconoscimento e highlight; quello in cui
si lavora ogni giorno merita tutto.

Per ogni asse decidi **serve / non serve / è già gratis**, sapendo già dove andrà:

| Asse | Dove va | Serve quando |
|---|---|---|
| Riconoscimento filetype | `ftdetect/<lang>.lua` | Neovim non riconosce l'estensione o il nome del file |
| Opzioni di editing | `after/ftplugin/<ft>.lua` | indentazione, `textwidth`, fold, `commentstring` non già corretti |
| Parser e highlight | lista `languages` in `plugin/40_plugins.lua` | esiste un parser tree-sitter per il linguaggio |
| Query personalizzate | `after/queries/<lang>/*.scm` | injection, fold, o capture che il parser non fornisce |
| Server di linguaggio | `after/lsp/<server>.lua` + `vim.lsp.enable()` | esiste un server e il linguaggio si scrive, non solo si legge |
| Build, test, quickfix | `:compiler` in `after/ftplugin/`, o `compiler/<tool>.lua` | il progetto si compila o si testa da riga di comando |
| Formattazione | `formatters_by_ft` di 'conform.nvim' | esiste un formatter dedicato per il linguaggio |
| Snippet | `after/snippets/<lang>.json` | ci sono costrutti ricorrenti propri del linguaggio |
| Navigazione | `path`, `include`, `includeexpr`, LSP | `gf`, `[i`, `<C-]>` non arrivano dove dovrebbero |
| Textobject e manipolazione | `vim.b.mini*_config` in `after/ftplugin/` | i costrutti del linguaggio meritano operatori propri |
| Gestione dipendenze | plugin dedicato, attivato sul manifesto | il linguaggio ha un manifesto che si modifica spesso |
| Debug del programma | 'nvim-dap' + adapter, o plugin del linguaggio | serve eseguire passo passo, non solo leggere errori |
| Toolchain e installazione | `mise`, health check | sempre, appena serve un binario esterno |
| Salute | `lua/config/health.lua` | sempre, se hai aggiunto una dipendenza esterna |

Il catalogo completo — cosa dà ciascun asse, come scoprire se è già coperto, e gli
helptag — è in `references/capabilities.md`. Leggilo quando decidi l'ambito, invece
di andare a memoria: citare un `:h` inesistente in un commento è un danno che resta
nel repo.

**Le decisioni che cambiano le abitudini dell'utente** — una mapping nuova, un
formatter che scatta al salvataggio, un `textwidth` diverso — si propongono, non si
prendono.

## Fase 4 — Installare le dipendenze con `mise`

Un linguaggio porta con sé dei binari: il compilatore, il server, il formatter, il
linter. Installarli a mano funziona una volta sola; il punto è renderli
**dichiarativi e riproducibili**, così che la config sappia da cosa dipende e il
health check possa verificarlo.

Lo strumento adottato è [`mise`](https://mise.jdx.dev) (*mise-en-place*), che gestisce
sia i runtime dei linguaggi sia gli strumenti di sviluppo, con un file dichiarativo e
attivazione automatica per directory. Copre il ruolo che altrove si dà a
'mason.nvim' — che questa config lascia deliberatamente disattivato, perché installa
programmi utilizzabili quasi solo dentro Neovim — **senza** sostituire
'nvim-lspconfig': i due sono ortogonali, `mise` procura i binari, 'nvim-lspconfig'
sa come parlargli (`cmd`, `filetypes`, `root_markers`).

### Dichiarare

I server e i formatter servono in qualunque directory si apra Neovim, quindi vanno
nella configurazione **globale** di `mise` (`mise config ls` ne dice il percorso):

```bash
mise use -g rust-analyzer@latest
mise use -g lua-language-server@latest
```

I runtime e le versioni **di un progetto** vanno invece nel `mise.toml` del progetto,
dove convivono con il resto della sua configurazione e seguono chi lo clona:

```toml
[tools]
rust = "1.98"
```

Quando il registry di `mise` non conosce un nome, quasi sempre lo copre un backend:
`aqua:` per i binari da GitHub release (`aqua:rust-lang/rust-analyzer`), più `npm:`,
`cargo:`, `go:`, `pipx:`. Verifica con `mise registry | grep <nome>` prima di
concludere che un tool non sia disponibile.

Con tutto dichiarato, l'installazione diventa un comando solo — ed è questo che
rende la procedura automatizzabile:

```bash
mise install
```

### Far vedere i binari a Neovim

È il punto in cui si perde più tempo, se si sbaglia. `mise` ha due modalità:

- **`mise activate`** aggancia la shell e aggiorna l'ambiente al cambio di directory.
  Neovim vede i tool **solo se è stato lanciato da una shell attivata**, perché
  eredita l'ambiente di quel momento: una sessione aperta ieri continua con la
  versione di ieri.
- **Gli shim** sono wrapper su `PATH`, quindi funzionano anche per un Neovim
  lanciato da un'icona, da un launcher o da un altro programma.

Su questa macchina, dove Neovim non è sempre avviato da un terminale, **gli shim
sono la scelta più affidabile**; l'attivazione di shell resta comoda per lavorare
nel progetto. Qualunque sia la scelta, il health check deve dire **quale versione è
attiva in questa sessione**, perché è la prima cosa da sospettare quando un server
si comporta in modo incoerente con la riga di comando.

### Registrare la dipendenza

Una dipendenza nuova va scritta in due posti, o è come se non esistesse:

- la **reference del linguaggio** in `references/`, con il comando `mise use` esatto;
- il **health check**, che ne verifica presenza e versione (Fase 6).

## Fase 5 — Implementare

Segui l'ordine di dipendenza: ogni passo si verifica da solo, e i successivi
poggiano sul risultato del precedente. Senza filetype non si carica nessun ftplugin;
senza parser non esistono i textobject tree-sitter; senza server non c'è niente da
mappare. Procedere in quest'ordine evita di inseguire un guasto che viene da due
livelli più in basso.

1. **Riconoscimento** — `ftdetect/<lang>.lua` con `vim.filetype.add()`, solo se la
   Fase 1 ha mostrato un filetype vuoto o sbagliato.
2. **Tree-sitter** — il linguaggio nella tabella `languages` di
   `plugin/40_plugins.lua`, sotto il separatore `-- Tree-sitter ===`. È una lista che
   alimenta un macchinario agnostico, quindi è il posto giusto. Riavvia una volta e
   aspetta la fine dell'installazione del parser prima di aprire quei file.
3. **Server di linguaggio** — `after/lsp/<server>.lua` che ritorna la tabella di
   config, più il nome dentro `vim.lsp.enable({ ... })`. Il modello di forma è
   'after/lsp/lua_ls.lua': header con la fonte del server, `on_attach` per ciò che ha
   senso solo a server attaccato, `settings` con la struttura definita dal server —
   e dillo in un commento, perché chi legge non deve chiedersi se quei nomi vengano
   da Neovim.
4. **Editing** — `after/ftplugin/<ft>.lua`, solo per ciò che il ftplugin del runtime
   non fa già. Qui vanno anche le config buffer-local di MINI.
5. **Build e test** — se esiste un compiler plugin nel runtime, `:compiler <tool>` e
   basta. Altrimenti valuta `compiler/<tool>.lua` (`:h write-compiler-plugin`) prima
   di scrivere `makeprg` ed `errorformat` a mano.
6. **Il resto** degli assi che la Fase 3 ha marcato come necessari.
7. **Health check** (Fase 6) e voce nel changelog (Fase 7).

## Fase 6 — Health check

`AGENTS.md` fissa la forma del file — un solo `lua/config/health.lua`, una
`check_*()` per area — e va seguita alla lettera. Se il file non esiste ancora,
`assets/health.lua` è lo scheletro da cui partire.

Cosa merita un controllo, per un linguaggio:

- **Gli eseguibili e la loro versione**, non solo la presenza: una toolchain vecchia
  fallisce in modi più confusi di una assente.
- **Quale toolchain è attiva in questa sessione**, e se `mise` la sta gestendo
  (Fase 4). È l'informazione che spiega i guasti altrimenti inspiegabili.
- **Il parser tree-sitter installato**, non solo disponibile.
- **Il server**, come eseguibile effettivamente raggiungibile.

Il consiglio in `warn()` ed `error()` dovrebbe essere il comando esatto da eseguire —
con `mise` è quasi sempre una riga sola, il che rende il check anche una guida
all'installazione.

## Fase 7 — Changelog e commit

Le voci di questo fork vanno nella sezione **"Fork changes"** in fondo a
`CHANGELOG.md`, mai in cima: upstream aggiunge sempre in testa al file, e tenere le
proprie voci separate evita un conflitto a ogni merge da `minimax`. Il dettaglio è
scritto in `AGENTS.md`.

Un commit per argomento, con il formato Problem/Solution: il soggetto **enuncia il
problema**. Il supporto di un linguaggio è quasi sempre più commit — parser, server,
quickfix, health check risolvono problemi diversi:

```
feat(plugins): Rust files have no syntax tree
feat(lsp): Rust code has no diagnostics, completion or navigation
feat(health): a missing Rust toolchain is only discovered when it fails
```

## Verifica

Vale la regola di `AGENTS.md`: una sola passata alla fine, e i passi interattivi si
**consegnano all'utente** invece di simularli headless. Quelli specifici di un
linguaggio nuovo:

```
1. mise install; riavvia Neovim e aspetta l'installazione dei parser
2. Apri un file del linguaggio
3. :InspectTree             — l'albero c'è
4. :checkhealth vim.lsp     — il client è attaccato, senza errori
5. :verbose setlocal makeprg? errorformat?  — vengono dal file che ti aspetti
6. :make <sottocomando>     — un errore introdotto apposta finisce nel quickfix e
                              `]q` ci salta sopra
7. <Leader>ld, <Leader>ls, <Leader>lr — diagnostica, definizione, rename
8. :checkhealth config      — la sezione nuova dice il vero
```

## Reference

- `references/capabilities.md` — il catalogo degli assi: cosa dà ciascuno, dove va,
  come scoprire se è già coperto, quali moduli MINI lo toccano.
- `references/rust.md` — Rust come caso completo: cosa il runtime dà già, cosa è
  invecchiato, i plugin che valgono la valutazione, l'installazione con `mise` e il
  ciclo `:make` mappato sull'*inner development loop* di *Zero To Production In Rust*.
  Serve anche da modello per la struttura di una reference di linguaggio.
- `assets/health.lua` — scheletro del primo `lua/config/health.lua`.
