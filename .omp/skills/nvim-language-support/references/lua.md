# Lua

L'esito delle Fasi 1 e 2 per Lua, svolte e verificate su questa macchina (Neovim
0.12.5, Windows, `lua-language-server` 3.19.1 installato con `mise`). Le fasi
successive seguono la procedura di `SKILL.md`; qui c'è solo ciò che è specifico del
linguaggio.

Lua ha una particolarità che nessun altro linguaggio di questa config ha: **è la
lingua in cui la config stessa è scritta**. Il linguaggio da supportare e lo
strumento di lavoro coincidono, e questo decide quasi tutte le scelte di "Fase 5 — cosa implementare" — la
`library` del server, i globali dichiarati, il formatter.

## 1. Fase 1 — cosa il runtime dà già

Per Lua il runtime è **doppio**: Neovim spedisce sia il ftplugin ereditato da Vim sia
uno proprio, e vengono caricati entrambi (`$VIMRUNTIME/ftplugin/lua.vim` e
`lua.lua`). All'apertura di un `.lua`:

| Cosa | Dove | Dettaglio |
|---|---|---|
| Commenti | `lua.vim` | `commentstring=-- %s`, `comments` che gestisce `---` |
| `gf` sui `require` | `lua.vim` | `include`, `includeexpr` che prova `x/y.lua` e `x/y/init.lua`, `suffixesadd=.lua` |
| `path-=.` | `lua.vim` | Lua non risolve i moduli relativi al file corrente |
| `define` | `lua.vim` | `function` e `local function`, per `[i` e `[d` |
| `%` esteso | `lua.vim` | `b:match_words` con `do`/`if`/`function` → `end`, `repeat` → `until` |
| Tree-sitter | `lua.lua` | `vim.treesitter.start()`: highlight moderno **senza installare niente**, il parser è built-in |
| Fold | `lua.lua` | `foldexpr=v:lua.vim.treesitter.foldexpr()` |
| Omni-completamento | `lua.lua` | `omnifunc=v:lua.vim.lua_omnifunc`, che completa le API di Neovim anche senza server |
| Indentazione | `indent/lua.vim` | euristica a espressioni regolari, `Last Change: 2017` |

**Nessun compiler plugin.** `:=vim.fn.getcompletion('', 'compiler')` non elenca né
`lua` né `luac`: non c'è un `:make` naturale, e per una config Neovim non serve —
quello che un `luac -p` direbbe lo dice già il server, subito e sulla riga giusta.

Query tree-sitter: `highlights`, `folds` e `injections` sono nel runtime;
`textobjects` arriva da 'nvim-treesitter-textobjects'; 'friendly-snippets' porta una
directory `snippets/lua`, che `after/snippets/lua.json` sovrascrive per prefisso.

## 2. Fase 2 — cosa di questo tenere

**Quasi tutto.** È il caso in cui il livello ereditato non lascia quasi buchi: il
ftplugin di Neovim è recente (usa tree-sitter e `vim.lua_omnifunc`), quello di Vim è
del 2025 e copre `gf` e i commenti, il parser è built-in. L'unico buco è
`'textwidth'`, che nessun livello ereditato imposta e che questa config vuole a 85 -
gli stessi `column_width` di `.stylua.toml` - così `'colorcolumn'` disegna il limite
mentre si scrive invece di scoprirlo da un `stylua --check` fallito. Da qui
`after/ftplugin/lua.lua`, il file più corto di questa config: una riga di
`vim.bo.textwidth`, un `b:undo_ftplugin` e il commento che spiega perché non è un
vezzo di stile.

L'unico file datato è `indent/lua.vim` (2017), che però funziona e resta l'unica
indentazione disponibile: Neovim non spedisce un `indentexpr` tree-sitter per Lua.
Con `stylua` un colpo di `<Leader>lf` rimette a posto quello che l'euristica sbaglia,
il che riduce il problema a un fastidio.

**Nessun plugin esterno vale la pena.** I candidati abituali coprono cose che qui
esistono già: il completamento delle API di Neovim (il server, con `VIMRUNTIME` nella
`library`), l'highlight (parser built-in), l'annotazione dei tipi (LuaCATS, che è del
server). L'unico esterno è il server stesso.

### Il livello che si dimentica: 'nvim-lspconfig'

Per `lua_ls` il file di 'nvim-lspconfig' è corto, e questo cambia cosa si può
scrivere in `after/lsp/lua_ls.lua`:

| Cosa dà | Dettaglio |
|---|---|
| `cmd` | `{ 'lua-language-server' }`, preso dal `PATH` |
| `root_markers` | `.luarc.json`, `.emmyrc.json`, poi `.stylua.toml`/`selene.toml`/`.luacheckrc`, poi `.git` |
| `settings.Lua` | `codeLens.enable = true` e `hint.enable = true` |
| funzioni | **nessuna**: niente `on_attach`, `on_init` o `root_dir` |

L'ultima riga è quella che conta: a differenza di `rust_analyzer`, qui un `on_attach`
scritto nella config **non cancella niente**, perché non c'è nulla da cancellare. Il
divieto generale di `SKILL.md` resta valido come metodo — si legge
`:=vim.lsp.config['lua_ls']` prima — ma per questo server la risposta è che si può.

## 3. Fase 4 — installazione

```bash
mise use -g lua-language-server@latest
```

Il registry di `mise` lo conosce come `aqua:LuaLS/lua-language-server`. Non esiste un
canale ufficiale del linguaggio da preferirgli (Lua non ha un `rustup`), quindi vale
la regola generale di `AGENTS.md` e `mise` è la via giusta.

`stylua` era già installato: serve a `AGENTS.md` prima ancora che all'editor.

## 4. Fase 5 — cosa implementare

**Tree-sitter**: niente da fare. `lua` è già nella tabella `languages` di
`plugin/40_plugins.lua` e il parser è built-in.

**Il server**: `'lua_ls'` in `vim.lsp.enable()` — è ciò che mancava, ed è il motivo
per cui `<Leader>lh`, `<Leader>lR` e `<Leader>ll` non davano niente e le altre
mapping dicevano *"method ... is not supported by any server activated for this
buffer"*. Quel messaggio non parla della mapping né del metodo: dice che **nessun
client è attaccato**, e la prima cosa da guardare è la lista passata a
`vim.lsp.enable()`.

In `after/lsp/lua_ls.lua`, le tre impostazioni che fanno la differenza per una config
Neovim, tutte dentro `settings.Lua`:

- **`workspace.library`** — le directory lette per definizioni e completamento ma mai
  segnalate. Tre voci: `vim.env.VIMRUNTIME` (le API di Neovim), `'${3rd}/luv/library'`
  (le annotazioni di `luv`, cioè `vim.uv`, che LuaLS spedisce come libreria di terze
  parti e risolve attraverso quel segnaposto) e la directory di 'mini.nvim' presa dal
  `runtimepath`, senza percorsi assoluti:

  ```lua
  vim.list_extend(library, vim.api.nvim_get_runtime_file('lua/mini', true))
  ```

  Senza l'ultima, ogni `MiniPick.builtin.files` è un globale sconosciuto e `<Leader>ls`
  su un `MiniXxx` non arriva da nessuna parte. Con essa, la definizione apre
  `mini.nvim/lua/mini/pick.lua`. **Non** si passa tutto il `runtimepath`: il costo si
  paga a ogni avvio del server (vedi "Il ciclo di lavoro").
- **`diagnostics.globals = { 'Config' }`** — `Config` è definito in `init.lua` ed è
  usato da ogni file di `plugin/`. Senza questa riga ogni suo uso è un
  `undefined-global`, cioè decine di avvisi falsi nei file che si modificano più
  spesso.
- **`workspace.checkThirdParty = false`** — altrimenti il server apre un prompt
  bloccante che chiede se configurare l'ambiente per ogni libreria di terze parti che
  riconosce. La `library` esplicita ha già risposto a quella domanda.

E `runtime.path = { 'lua/?.lua', 'lua/?/init.lua' }`, che è **come Neovim stesso
risolve `require()`** (`:h lua-module-load`), non il `package.path` di un interprete
standalone: è ciò che fa atterrare `<Leader>ls` su un `require('config.health')` nel
file che Neovim caricherebbe davvero.

**Formattazione**: `lua = { 'stylua' }` in `formatters_by_ft`. StyLua legge il
`.stylua.toml` della radice, quindi `<Leader>lf` e il `stylua --check` che
`AGENTS.md` impone prima di un commit applicano le stesse regole. Il fallback su LSP
non era un'alternativa: il server formatta con le proprie convenzioni e non conosce
quel file.

## 5. Il ciclo di lavoro

Non c'è `:make`: il ciclo è il server per gli errori, `<Leader>lf` per la forma,
`:checkhealth config` per l'ambiente, e `:source %` o un riavvio per provare la
modifica.

Questo è anche tutto ciò che resta dell'asse "esecuzione" (`capabilities.md` "Eseguire il programma, e le viste che non sono file"):
il programma è l'editor che lo sta leggendo, quindi non c'è un processo da avviare né
da staccare, e `:source %` lo esegue nello stesso Neovim. **È l'unico linguaggio di
questa config che non definisce `:Run`**, e la ragione va detta perché il contratto è
universale per costruzione: non manca un comando, manca qualcosa da eseguire. Uno
script Lua standalone lanciato con `lua` sarebbe il caso in cui definirlo, e qui non
è il lavoro che si fa.

**I primi secondi di ogni sessione vanno conosciuti.** All'attacco, `lua_ls` carica
la `library` prima di poter rispondere a una richiesta di posizione: 330 file circa
(`VIMRUNTIME` più 'mini.nvim'), meno di dieci secondi a cache calda su questa
macchina. Durante quel tempo `<Leader>lh` risponde `Workspace loading: 294 / 330`
invece della firma, mentre le diagnostiche del file aperto arrivano già. Non è un
guasto e non è un motivo per svuotare la `library`.

Tre conseguenze visibili, tutte del server e nessuna della config:

- **il caricamento è annunciato due volte** (`lua_ls: Loading workspace (100%)` in
  fila). Sono due token di progresso distinti — uno per scope: nel log si vedono
  arrivare `330` e `276` — con lo stesso titolo, e 'mini.notify' li mostra
  entrambi. Non sono due client: `:checkhealth vim.lsp` ne conta uno;
- un `lua_ls: Searching in files... (100%)` compare ogni tanto durante la
  navigazione: è lo stesso meccanismo, per la ricerca che serve a `<Leader>lR` e
  alle code lens;
- **`<Leader>ls` su una funzione locale dà due risultati** — `local f = function()`
  è una variabile *e* un valore, e il server nomina entrambi: la riga della
  variabile e il blocco `function ... end`. Il quickfix con due voci è la risposta
  corretta, non un client duplicato.

### Due cose da sapere prima di premere il tasto

**`<Leader>ll` non ha niente da eseguire.** Le code lens di LuaLS sono un contatore:
risolte, valgono `title = "1 references"` e `command = ""`. Neovim risolve la lens e
poi prova a eseguirla, quindi ne esce il messaggio ``Language server `lua_ls` does
not support command ``` con il nome vuoto. Il conteggio in virtual text è tutto
quello che quelle lens offrono; per andare ai riferimenti c'è `<Leader>lR`.
Spegnerle (`settings.Lua.codeLens.enable = false`) toglie il messaggio insieme al
conteggio.

**Aprire la config dal percorso di installazione crea un secondo client.** Su questa
macchina `%LOCALAPPDATA%\nvim` è una junction verso `configs/nvim-0.12`, e
`<Leader>ei` (`:edit $MYVIMRC`) apre il file **da lì**. Risalendo da quel percorso
non ci sono né `.git` né `.stylua.toml`, quindi `lua_ls` parte una seconda volta con
`root_dir = nil`, cioè in single file mode: nessuna diagnostica, e un altro
caricamento del workspace. Lo stesso file aperto dal percorso reale del repository
riusa il client giusto. `vim.fn.resolve()` risolve la junction anche su Windows
(verificato), ed è quindi il rimedio quando lo si vuole chiudere.

## 7. Health check

Le domande a cui `check_lua()` risponde: `lua-language-server` è raggiungibile e con
quale versione (con il comando `mise` di "Fase 4 — installazione" come consiglio quando non lo è), e il
parser `lua` è installato — che per un parser spedito con Neovim significa
un'installazione rotta, non un linguaggio da aggiungere, e il consiglio lo dice.
`stylua` resta in `check_external_tools()`, dove era già: la sua assenza rompe prima
il flusso di lavoro del repository che l'editing di Lua.

## 8. Verifica

Oltre a quanto prescrive la skill `nvim-config-testing`, i controlli che valgono solo
qui:

- `<Leader>ls` su un `MiniXxx` deve aprire un file dentro `mini.nvim`, e su un
  `require('config.health')` il file della config: sono le due prove che
  `workspace.library` e `runtime.path` sono arrivati al server;
- un `Config.later` in un file di `plugin/` **non** deve essere segnalato come
  `undefined-global`, mentre un nome inventato accanto deve esserlo: è l'unico modo
  di distinguere "i globali sono dichiarati" da "le diagnostiche non arrivano";
- `<Leader>lf` su una riga volutamente sciatta (`local    x   =    { 1,2 }`) deve
  restituire la forma di StyLua. Se non cambia niente, il primo sospetto è che il
  buffer non sia sintatticamente valido: StyLua non formatta ciò che non parsa, e non
  lo dice;
- `<Leader>ll` su un file della config non deve più trovare code lens da LuaLS:
  `after/lsp/lua_ls.lua` disabilita `codeLens` perché ogni lens che il server
  pubblicava aveva `command = ""` - un conteggio senza azione. Se un giorno ne
  arriva una con un comando vero, quella è la ragione per riattivarle, non
  una regressione da correggere qui;
- `:verbose setlocal commentstring? includeexpr?` deve nominare
  `$VIMRUNTIME/ftplugin/lua.vim`, mentre `:verbose setlocal textwidth?` deve
  nominare `after/ftplugin/lua.lua` - la config NE ha uno, per `'textwidth'`
  soltanto.

**La trappola di questo linguaggio in fase di verifica**: LuaLS non pubblica
diagnostiche per un file che non sta in un workspace. In uno scratch senza
`.luarc.json`, `.stylua.toml` né `.git` il server si attacca, risponde a `definition`
e `hover`, e non manda **nessuna** diagnostica — indistinguibile da una config
sbagliata. Un `git init` nella directory di prova rimette tutto a posto.

**E una che non riguarda il linguaggio ma si paga qui**: interrogare il server in
polling mentre carica lo tiene occupato e il caricamento non finisce mai. Le sonde
`lsp_request` e `diagnostics` aspettano `vim.lsp.status()` una volta sola per
questo; il resto è nella skill `nvim-config-testing`.