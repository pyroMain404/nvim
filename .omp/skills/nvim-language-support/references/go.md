# Go

L'esito delle Fasi 1-5 per Go, svolte e verificate su questa macchina (Neovim 0.12.6,
Windows, Go 1.27.3, gopls 0.24.0). Le fasi seguono la procedura di `SKILL.md`; qui c'è
solo ciò che è specifico del linguaggio.

## 1. Fase 1 — cosa il runtime dà già

| Cosa | Dettaglio |
|---|---|
| Filetype | `go`, `gomod`, `gowork`, `gosum`: tutti riconosciuti, nessun `ftdetect/` |
| `ftplugin/go.vim` | manutenuto (ultima modifica 2026-02): `commentstring=// %s`, `comments` per `/* */`, `formatoptions-=t`, stile ufficiale `noexpandtab` con `shiftwidth=0` (variabile `g:go_recommended_style`), `]]` `[[` `][` `[]` per `type` e `func` |
| `'keywordprg'` | `:GoKeywordPrg`, cioè `go doc` in un terminale; l'hover del server vince su `K` (`SKILL.md` "Contratti") |
| `ftplugin/gomod.vim` | `noexpandtab`, `commentstring`; niente `gowork` |
| `compiler/go.vim` | del **2014**: `makeprg=go build` **senza `$*`**, quindi `:make test` diventa `go build test`; l'`errorformat` non conosce `go vet`, i test fallimenti indentati né i frame di un panic |
| `indent/go.vim` | del 2017, con due TODO nell'intestazione; `=` e `gq` passano comunque da `gopls` |
| `syntax/go.vim` | sostituito dal parser |

## 2. Fase 2 — cosa tenere

Si tiene il ftplugin (commentstring, stile, `go doc`). Il compiler plugin invece è
l'unico pezzo vecchio che cambia, e lo fa **ereditando** (`capabilities.md` "Un
compiler plugin può ereditarne un altro"): `compiler/go.lua` sorgenta `go.vim` e
aggiunge ciò che manca. Nessun plugin esterno: 'nvim-lspconfig' dà già `gopls` (con
`root_dir` che cerca `go.work`, poi `go.mod`, e riconosce sorgenti della libreria
standard e del module cache), 'nvim-treesitter' i parser, 'conform.nvim' il formatter.

## 3. Fase 4 — toolchain

`go` è già dichiarato globale in `mise`. Il server si installa con il backend `go:`,
che chiama `go install`, perché il registry non conosce `gopls` per nome:

```bash
mise use -g go:golang.org/x/tools/gopls@latest
```

`gofmt` arriva con Go. `gofumpt`, `goimports` e `golangci-lint` non sono installati e
non sono dichiarati: cambierebbero lo stile del codice formattato, e **si propongono**
(`SKILL.md`, "Le decisioni che cambiano le abitudini").

## 4. Fase 5 — cosa implementare

- **Tree-sitter**: `go`, `gomod`, `gowork` in `languages`. Il filetype `gosum` non ha
  parser e non serve.
- **Server**: `after/lsp/gopls.lua`, solo tabelle: il default definisce `root_dir`
  come funzione. Unica impostazione, `staticcheck = true`, l'equivalente di clippy per
  Rust. Misurato: con l'impostazione `a == a` esce come `SA4000`, con
  `staticcheck = false` no; **ma le diagnostiche di analisi arrivano dopo quelle di
  tipo**, e la sonda `diagnostics` con `quiet` di default (700 ms) si ferma prima
  dichiarando zero diagnostiche — serve `quiet = 5000`.
- **Formatter**: `gofmt`, quello su cui la CI di un progetto Go si accorda.
- **Editing**: `after/ftplugin/go.lua`: fold tree-sitter e `:make` dalla radice del
  modulo (`go.mod`), perché gli strumenti stampano percorsi relativi.
- **Build e test**: `compiler/go.lua`, `makeprg=go $*` come `cargo $*` — quindi
  `:make` **da solo** chiama `go` senza sottocomando e non produce niente; si scrive
  sempre `:make build ./...`.
- **Esecuzione**: `:Run` risolve da `go list -f {{.Name}} .` (`main` nella radice del
  modulo: `go run .`), altrimenti da `cmd/`: una sola directory la usa, più d'una
  rifiuta **elencandole**, nessuna rifiuta dicendolo. Fuori da un modulo il file
  esegue sé stesso (`go run <file>`). Argomenti presenti: `go run <args>`, che
  sostituiscono il default.
- **File singolo** (senza `go.mod` né `.git`): `gopls` si attacca lo stesso, in
  single-file mode con `root: nil` — il default di 'nvim-lspconfig' chiama `on_dir(nil)`
  e il client parte comunque. Misurato su un file isolato: diagnostiche, hover e
  definizione rispondono. `:make build <file>` funziona senza cambiare directory.

## 5. Il ciclo di lavoro

| Comando | Cosa fa |
|---|---|
| `:make build ./...` | errori di compilazione nella quickfix |
| `:make vet ./...` | `go vet`, il cui output ha davanti il nome dello strumento |
| `:make test ./...` | i test; il messaggio di un test fallito e la riga del panic nel test finiscono nella quickfix, i frame in `src/testing` e `src/runtime` no |
| `:Run` | esegue il progetto in un terminale in split |

## 7. Cosa deve dire l'health check

`go` e `gopls` rispondono a `version`, **non** a `--version` (`go --version` esce con
`flag provided but not defined`): il campo `version` di una voce di `tools` lo dice a
`check_tool()`. `gofmt` non ha né l'uno né l'altro e si controlla per percorso. Più i tre
parser.

## 8. Verifica

- Il parser mancante alla prima apertura dà `Parser could not be created for buffer`:
  è il comportamento documentato ("riavvia una volta e aspetta"), non un guasto; la
  seconda esecuzione della sonda `startup` è pulita.
- Un modulo con errori di tipo (un `bad.go` accanto) fa tacere le analisi di `gopls` su
  tutto il pacchetto: per provare `staticcheck` serve un modulo che compila.
- Il test del panic: sulla macchina i frame hanno percorsi con `/` anche su Windows
  (`W:/.cache/.../src/testing/testing.go:2125 +0x239`), e il filtro `%-G` poggia su
  quello.
