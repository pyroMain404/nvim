# Angular

L'esito delle Fasi 1 e 2 per Angular, svolte e verificate su questa macchina
(Neovim 0.12.5, Windows, Node 20.20.2, progetto Angular 17.3 con `strictTemplates`).
Le fasi successive seguono la procedura di `SKILL.md`; qui c'è solo ciò che è
specifico del linguaggio.

Angular non è un linguaggio ma una piattaforma, e questo decide la forma del
lavoro: **un componente è tre file** — la classe TypeScript, il template, il foglio
di stile — che possono essere tre file veri o uno solo, con template e stili scritti
dentro il decoratore. Ogni asse va deciso due volte, per la forma esterna e per
quella inline.

## 1. Fase 1 — cosa il runtime dà già

| Cosa | Dettaglio |
|---|---|
| Filetype `.ts` | `typescript`, con `ftplugin`, `indent` e `syntax` nel runtime |
| Filetype `.html` | `html` — **quasi mai `htmlangular`**, vedi sotto |
| `commentstring` TypeScript | `// %s`, da `ftplugin/typescript.vim` |
| `gf` sugli import | `suffixesadd=.ts,.d.ts,.tsx,.js,.jsx,.cjs,.mjs`, stesso file |
| Filetype `htmlangular` | esiste, con `ftplugin` e `syntax` propri: entrambi si limitano a caricare quelli di `html` |
| `makeprg` / `errorformat` | **vuoti**, in tutti e due i filetype |
| Compiler plugin | ci sono `tsc` e `eslint`; nessuno per Angular |
| Parser tree-sitter | `angular`, `typescript`, `html`, `css`, `scss`, `json` tutti disponibili, nessuno installato |
| 'nvim-lspconfig' | ha `angularls`, `ts_ls`, `vtsls`, `html`, `cssls`, `eslint` |
| 'friendly-snippets' | `typescript.json` e `html.json` arrivano; quelli Angular **no**, vedi `capabilities.md` §9 |

### Il rilevamento del template è il primo guasto, ed è a monte di tutto

`vim.filetype.match({ filename = 'app.component.html' })` risponde `html`. Non è una
svista: `M.html()` in `$VIMRUNTIME/lua/vim/filetype/detect.lua` guarda le prime 40
righe cercando `@if`, `@for`, `*ngIf`, `<ng-template>`, `<ng-content>`, e **la regola
per nome è lì, commentata**, con il link alla discussione che l'ha respinta
(`vim/vim#13594`): un `*.component.html` fuori da Angular non vuol dire niente.

Quindi un template fatto di soli binding — `{{ title }}` dentro un `<div>`, cioè il
caso più comune — resta `html`. E `html` non è un `htmlangular` più povero: il parser
`angular` dichiara `get_filetypes() == { 'angular', 'htmlangular' }`, per cui
l'autocomando di `plugin/40_plugins.lua` non lo raggiunge mai e l'highlight resta
quello del `syntax/` legacy. Da qui la Fase 5 comincia con `ftdetect/`.

## 2. Fase 2 — cosa di questo tenere

**Da tenere.** I ftplugin di `typescript` e `html` del runtime, che danno
`commentstring`, `suffixesadd` e le opzioni di indentazione su cui poggiano
'mini.comment', `gf` e gli operatori di rientro. Non c'è niente da correggere.

**Non basta.** Il `syntax/` di TypeScript e di HTML, sostituito dal parser appena lo
si installa; il compiler plugin `tsc`, per il motivo del §4; e il rilevamento del
filetype, per il motivo del §1.

### I server: due, non uno

`angularls` e `ts_ls` non sono alternative, ed è la cosa che più spesso si sbaglia:

- `angularls` sa **il template**. Controlla i tipi di `{{ }}` contro la classe del
  componente, completa dentro un binding, segue un selettore fino al componente che
  lo dichiara. Di TypeScript come linguaggio non sa niente: da solo, un `.ts` non
  riceve **nessuna** diagnostica.
- `ts_ls` è quella metà. Si attaccano entrambi a un buffer `typescript`, che Neovim
  gestisce interrogando tutti i client e unendo le risposte.

Chi formatta non va lasciato al caso: lo decide `prettier` dichiarato in
`formatters_by_ft` (§4), che toglie di mezzo il fallback `lsp_format`.

`vtsls` è la terza opzione ed è più veloce su codebase grandi, ma è un cambio di
server, non un'aggiunta: si valuta solo se `ts_ls` diventa lento.

Quello che 'nvim-lspconfig' dà per `angularls` va letto prima di scrivere qualsiasi
cosa, perché è molto più di un `cmd`:

```vim
:=vim.lsp.config['angularls']
```

| Cosa fa | Perché conta |
|---|---|
| `cmd` è una **funzione** che compone la riga di comando dal progetto | `--tsProbeLocations` e `--ngProbeLocations` puntano al `node_modules` del progetto, e `--angularCoreVersion` viene letta dal suo `package.json` |
| risolve il wrapper `.cmd` di npm su Windows, ricorsivamente | senza, il probe partirebbe dalla directory dello shim |
| `root_markers = { 'angular.json', 'nx.json' }` | copre anche i monorepo Nx |
| `filetypes` include `html` oltre a `htmlangular` | un template non riconosciuto riceve comunque il server, ma non il parser |

Niente `on_attach`, niente `before_init`, niente `root_dir`: un
`after/lsp/angularls.lua` sarebbe additivo e sicuro — ma **non serve**, perché non
c'è niente da aggiungere. `ts_ls` invece ne definisce tre, quindi lì la regola dei
livelli sovrapposti (`SKILL.md`) vale in pieno.

## 3. Fase 4 — installazione

```bash
mise use -g npm:@angular/language-server@17   # la major DEL PROGETTO, non @latest
mise use -g npm:typescript-language-server@latest
mise use -g npm:typescript@5                  # tsserver per i file fuori progetto
mise use -g npm:prettier@latest
```

`@latest` è la scelta sbagliata di default, ed è costato un giro: con il server 22.1.5
su un progetto Angular 17 il client si attacca, `:checkhealth vim.lsp` lo dà sano, e
**nessuna diagnostica arriva mai**; in `:LspLog` ogni `didOpen` fallisce con
`languageService.ensureProjectAnalyzed is not a function`. Il perché è generale ed è
in `capabilities.md` §4: `ngserver` è un guscio che carica
`@angular/language-service` dal progetto. Per progetti di major diverse la sede è il
`mise.toml` **del progetto**: lo shim risolve in base alla directory corrente, e
Neovim avvia `ngserver` proprio attraverso lo shim.

`typescript@5` e non `@7`: la 7 è la riscrittura nativa e non espone più
`typescript/lib/tsserverlibrary`, che è quello che `ngserver` cerca.

Il compilatore Angular **non** si installa: `npx` prende quello del progetto, che è
l'unico allineato ai suoi sorgenti.

## 4. Fase 5 — cosa implementare

**`ftdetect/htmlangular.lua`** — la regola per nome che il runtime ha scartato,
ristretta a un progetto che davvero è Angular. Il valore di `pattern` è una funzione
che ritorna `nil` fuori da uno, così altrove il rilevamento resta identico
(`capabilities.md` §1).

**Tree-sitter**: `angular`, `typescript`, `html`, `css`, `scss`, `json` nella tabella
`languages`. `angular` dipende da `html` e `html_tags`, e 'nvim-treesitter' li
installa da sé senza che vadano elencati.

**`after/queries/typescript/injections.scm`** — template e stili inline. Il nodo è
`(pair key: (property_identifier) value: (template_string))`, e la parte che decide
se funziona è `(#offset! @injection.content 0 1 0 -1)`, che lascia i backtick a
TypeScript. Catturare lo `(string_fragment)` interno sembra più semplice ed è
sbagliato: un template con un `${}` ha **più** fragment, e un tag aperto prima della
sostituzione e chiuso dopo non verrebbe mai chiuso.

**I server**: `angularls` e `ts_ls` dentro `vim.lsp.enable()`, e nessun file in
`after/lsp/` (§2).

**Build e quickfix**: `compiler/ngc.lua`, più `:compiler ngc` nei due ftplugin.
`:compiler tsc` non è la risposta, e la prova è misurabile: su un componente il cui
template usa una proprietà che la classe non dichiara, `tsc --noEmit` non riporta
**niente**, mentre `ngc` riporta l'errore alla riga e alla colonna dentro il `.html`.
Il type checking dei template è del compilatore Angular e di nessun altro.

Due cose del compiler plugin, entrambe verificate e nessuna deducibile:

- `--noEmit` fa parte del comando. `ngc` senza argomenti legge il `tsconfig.json`
  della directory corrente e **scrive** JavaScript accanto ai sorgenti; `:make` qui
  è il controllo rapido dell'inner loop, non una build.
- `ngc` **colora sempre**. Formatta con `formatDiagnosticsWithColorAndContext` di
  TypeScript, che emette le sequenze senza guardare niente: `--pretty false` non
  arriva a quella chiamata (`--pretty=false` viene proprio rifiutato come opzione
  sconosciuta), e sotto `:make` le sequenze ci sono anche con `NO_COLOR=1` già
  presente nell'ambiente del figlio. L'`errorformat` deve quindi vederci attraverso;
  la forma e i suoi escaping sono in `capabilities.md` §6 e in `assets/compiler.lua`.

La riga da riconoscere, senza colore:

```
src/app/app.component.html:1:8 - error TS2339: Property 'titleXYZ' does not exist...
```

I codici sono `TS` (dal type checker) e `NG` (dal compilatore Angular, `NG8001` per
un elemento che nessun modulo dichiara), come errori e come warning. Tutto il resto
— l'estratto del sorgente e, per un errore di template, la posizione nel `.ts` che
lo ha incluso — si scarta con `%-G%.%#`: sono righe che non portano da nessuna parte.

**Formattazione**: `prettier` per `typescript`, `javascript`, `html`, `htmlangular`,
`css`, `scss`, `json`. `htmlangular` va elencato accanto a `html` perché per Neovim
sono due filetype, mentre `prettier` vede lo stesso `.html` in entrambi i casi.

**Fold del template**: `v:lua.vim.treesitter.foldexpr()` in
`after/ftplugin/htmlangular.lua`. Senza, il markup annidato si piega per profondità
di indentazione invece che per elemento.

## 5. Il ciclo di lavoro

| Comando | Cosa fa |
|---|---|
| `:make` | `ngc --noEmit` sul progetto: errori di TypeScript **e** di template nel quickfix, `]q` per scorrerli |
| `:make -p tsconfig.app.json` | lo stesso su un altro `tsconfig` |
| `<Leader>lf` | `prettier`, gli stessi file e le stesse regole della CI |
| `<Leader>ld` su un selettore | `angularls` porta al componente che lo dichiara |

Gli stessi errori compaiono già come diagnostica mentre si scrive: `:make` resta
quello che dà la lista completa del progetto in un colpo solo, invece dei soli file
aperti. Una build vera (`ng build`, `ng test`) è un'altra cosa e sta in un terminale.

## 6. Ambiente di progetto

Un progetto la cui Angular non è quella dichiarata globalmente vuole il proprio
`mise.toml` con `npm:@angular/language-server` alla major giusta (§3). Non è un
`.nvim.lua`: qui non serve una variabile d'ambiente, serve che lo shim risolva un
altro eseguibile, e per quello la directory corrente basta.

## 7. Health check

Le domande a cui `check_angular()` deve rispondere: `node` c'è (tutto il resto ci
passa); `ngserver`, `typescript-language-server` e `prettier` sono raggiungibili;
il progetto ha davvero un `node_modules` — senza, `angularls` non trova nessun
servizio di linguaggio da caricare e `npx` nessun compilatore, e il sintomo somiglia
a una config rotta; e **quale major di Angular usa il progetto**, accanto alla riga
`mise` che installa il server corrispondente. Quest'ultima è la voce che vale di
più, perché è l'unico posto da cui si può vedere il guasto del §3.

`ngserver --version` non è un modo di chiedere: il binario si rifiuta di partire
senza le `--tsProbeLocations` che 'nvim-lspconfig' calcola dal progetto, quindi la
presenza è tutto ciò che il check può onestamente riportare.

## 8. Verifica

Oltre a quanto prescrive la skill `nvim-config-testing`, i controlli che valgono
solo qui:

- un `*.component.html` **senza** costrutti Angular, dentro un progetto Angular,
  deve avere filetype `htmlangular`; lo stesso file fuori da un progetto Angular
  deve restare `html`. Il secondo è il controllo che conta: senza, la regola è
  soltanto più larga di quella del runtime;
- `:make` con un errore **nel template** deve produrre una voce navigabile che punta
  al `.html` alla riga e alla colonna giuste. Un errore nel `.ts` non basta a
  provarlo: è quello che `tsc` prenderebbe comunque;
- su un template devono essere attaccati **uno** e un solo client, `angularls`; su
  un `.ts` **due**, `angularls` e `ts_ls`. La sonda `lsp` aspetta il primo client e
  poi legge: con due server va data un'attesa esplicita, o riporta quello che è
  arrivato per primo;
- una diagnostica del server deve comparire **nel buffer del template**, con
  `ngtsc` come sorgente: è l'unica prova che il servizio di linguaggio caricato dal
  progetto sia compatibile con l'eseguibile, e quindi che il §3 sia stato rispettato;
- il cursore dentro un `template:` inline deve dare `angular` come linguaggio
  iniettato, non `typescript`.
