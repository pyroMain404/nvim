---
name: nvim-language-inventory
description: Use before configuring a language in Neovim to inventory what $VIMRUNTIME and installed plugins (nvim-lspconfig, nvim-treesitter-textobjects, friendly-snippets, mini.*) already provide and decide whether the built-in is good enough. Trigger on "cosa offre già Neovim", "inventario del linguaggio", or "serve un plugin per X".
---

# Inventario di un linguaggio

Le Fasi 1 e 2 della procedura di `nvim-language-support`.

## Fase 1 — Inventario: cosa c'è già

**Non saltare questa fase.** È quella che distingue una configurazione di venti
righe motivate da una di duecento che duplicano il runtime. Va fatta dentro una vera
sessione, con aperto un file del linguaggio: gli ftplugin si caricano solo quando il
filetype viene effettivamente impostato.

```vim
" Il filetype viene riconosciuto? Con quale nome?
:=vim.bo.filetype
:=vim.filetype.match({ filename = 'esempio.xyz' })

" Quali file del runtime sono già attivi per questo filetype?
" NOTE: `*` e non `{vim,lua}`. Le graffe le espande la shell, e `cmd.exe` non le
" conosce: su Windows `globpath(&rtp, 'ftplugin/html.{vim,lua}')` risponde stringa
" vuota — cioè "il runtime non ha niente" — mentre `'ftplugin/html.*'` trova il
" file. Verificato con `-u NONE`, quindi non è una regola della config.
:=vim.fn.globpath(vim.o.rtp, 'ftplugin/<ft>.*')
:=vim.fn.globpath(vim.o.rtp, 'indent/<ft>.*')

" Quali compiler plugin esistono, senza scorrere le directory
:=vim.fn.getcompletion('', 'compiler')

" Chi ha impostato cosa: `:verbose` nomina il file responsabile, `vim.bo`/`vim.wo`
" danno il valore senza rumore. Servono entrambi, per domande diverse.
:verbose setlocal makeprg? errorformat? commentstring? includeexpr?
:=vim.bo.makeprg
:=vim.wo.foldexpr

" Esiste una pagina di help dedicata al ftplugin built-in?
:h ft-<lang>

" Tree-sitter: il parser è disponibile, e installato?
:=vim.tbl_contains(require('nvim-treesitter').get_available(), '<lang>')
:InspectTree

:checkhealth vim.lsp vim.treesitter
```

### Il secondo inventario: i plugin già installati

Fermarsi a `$VIMRUNTIME` fa dare per scontato un livello che per questo linguaggio ha
già lavorato. 'nvim-lspconfig', 'nvim-treesitter-textobjects' e 'friendly-snippets'
spediscono **default per linguaggio**, e la varianza da un linguaggio all'altro è
enorme: il file di 'nvim-lspconfig' per `lua_ls` è una decina di righe, quello per
`rust_analyzer` ne ha duecento — ricerca della workspace root con `cargo metadata`,
runnable, comandi utente.

```vim
" Cosa 'nvim-lspconfig' dà già per il server. LEGGILO, non limitarti a vedere che
" esiste: le funzioni che contiene sono quelle che un override cancella.
:=vim.lsp.config['<server>']

" I textobject tree-sitter arrivano già da 'nvim-treesitter-textobjects'?
:=vim.treesitter.query.get('<lang>', 'textobjects') ~= nil

" Quali snippet arrivano da 'friendly-snippets' (un `<lang>.json`, o una directory)
:=vim.fn.globpath(vim.o.rtp, 'snippets/<lang>*', false, true)
```

Tutte e tre valgono **solo dopo** che il plugin è sul `runtimepath`, e
'friendly-snippets' e 'conform.nvim' arrivano da `Config.later()`: chiesto troppo
presto, `globpath` risponde vuoto e la risposta si legge come "il plugin non dà
niente". Aspetta l'evento, non un numero — è la stessa regola della skill
`nvim-headless-probes`, e qui costa un asse dichiarato mancante per sbaglio.

**Un inventario può essere fatto davvero e restare falso a metà, ed è il modo in cui
questa fase viene saltata senza accorgersene.** Le affermazioni sul runtime reggono,
quelle sui plugin no, e nel testo finito nulla distingue le due: si leggono uguali.
Misurato su Godot, dove due assi su tredici sono stati classificati male così — e in un
caso l'asse non era *mancante* ma **attivo e sbagliato**, che è peggio:

- «il parser `gdshader` dichiara `gdshaderinc`, quindi non copre `*.gdshader`».
  `get_filetypes('gdshader')` risponde **`gdshader, gdshaderinc`**: la tabella di
  'nvim-treesitter/plugin/filetypes.lua' registra i filetype **in più** rispetto al
  nome del parser, che è già un filetype di suo. È additiva, ed era stata letta come
  sostitutiva — lo stesso errore di categoria della tabella in
  ["I livelli si sovrappongono"](../nvim-language-support/SKILL.md#i-livelli-si-sovrappongono), applicato però a una
  tabella *di un plugin* invece che a un file scritto da noi.
- «'friendly-snippets' non offre un set per questo linguaggio». Ne caricava **25**, e
  quattro espandevano sintassi di una major precedente del motore.

La regola che ne esce: **un'affermazione su cosa un plugin contiene si scrive solo
dopo il comando che l'ha prodotta.** Le tre righe qui sopra costano un secondo; senza,
un asse archiviato come "non serve ora" può essere un asse già rotto, e nessuno lo
riapre perché il documento dice che è stato valutato.

Da qui esce la lista di **cosa manca**. Riportala all'utente prima di implementare:
spesso è la parte più sorprendente del lavoro. E ciò che questi comandi mostrano non
va riscritto né, peggio, sovrascritto per sbaglio: vedi
["I livelli si sovrappongono"](../nvim-language-support/SKILL.md#i-livelli-si-sovrappongono).

## Fase 2 — Il built-in basta, o serve altro?

La Fase 1 dice cosa *c'è*. Questa dice se **vale**. Ereditare qualcosa dal runtime
non significa che sia la scelta migliore: parte di ciò che Neovim spedisce sono
snapshot di plugin Vimscript nati prima di LSP e tree-sitter, manutenuti a ritmo
lento dal Vim project. Funzionano, ma a volte l'ecosistema del linguaggio si è
spostato altrove.

**E la scelta non è binaria.** Fra il runtime e un plugin nuovo c'è un livello
intermedio **già installato**, che per un linguaggio diffuso ha spesso già fatto il
lavoro: 'nvim-lspconfig' per il server, 'nvim-treesitter' e i suoi textobject per
l'albero, 'friendly-snippets' per gli snippet, 'conform.nvim' per la formattazione.
Il secondo inventario della Fase 1 serve a questo — sapere cosa quel livello dà prima
di chiedersi se ne serve un terzo. Un plugin nuovo che duplica quel livello è lo
stesso errore di uno che duplica il core, solo meno visibile.

Non è una scelta di gusto. Applica questi criteri, in quest'ordine:

**Tieni il built-in quando**

- copre il caso d'uso senza attriti, e il costo di manutenzione è zero: si aggiorna
  con Neovim, non ha config, non si rompe;
- il plugin candidato porta soprattutto funzioni che non useresti;
- **altre parti della config lo danno per scontato.** Le opzioni impostate dai
  ftplugin del runtime non servono solo a chi le legge: `'commentstring'` è ciò che
  'mini.comment' usa per commentare, `'makeprg'` ed `'errorformat'` sono ciò che
  `:make` legge per riempire il quickfix (e quindi ciò che rende utili `]q` e `[q`
  di 'mini.bracketed'), `'includeexpr'` e `'suffixesadd'` sono ciò che fa arrivare
  `gf` al file giusto, `'shiftwidth'` decide l'indentazione di ogni operatore che
  rientra il testo. Sostituire il ftplugin con un plugin che imposta le sue
  convenzioni significa spostare tutti questi comportamenti insieme, spesso senza
  accorgersene finché uno smette di funzionare.

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

**Il segnale opposto, che vale quanto gli altri**: un plugin che *reimplementa* ciò
che Neovim ha nel frattempo assorbito nel core va **evitato**, anche quando è
popolare e ben fatto. LSP, tree-sitter, `vim.pack`, `vim.snippet`, i comandi di
diagnostica, gli inlay hint e i semantic token sono stati a lungo territorio di
plugin, e quei plugin esistono ancora, spesso con più installazioni del built-in che
li ha resi superflui. Popolarità e attività di sviluppo misurano quanti utenti sono
arrivati prima del core, non se oggi servano: qui l'ordine di preferenza di
`AGENTS.md` decide, e il built-in vince.

**Prima di installare un plugin** vale l'ordine di preferenza di `AGENTS.md`. Il
livello MINI si salta troppo spesso, ed è quello che risolve più casi di quanti
sembri: `nvim-language-support/references/capabilities.md` elenca, asse per asse, i moduli con
configurazione per linguaggio.

Un plugin esterno deve dichiarare cosa porta che gli altri due livelli non danno, e
va verificato che **non spenga ciò che già funziona**. Alcuni prendono possesso della
configurazione di un server e chiedono esplicitamente di non configurarlo per conto
proprio: la scelta diventa allora **esclusiva** — o il plugin, o `after/lsp/<server>.lua`,
mai i due insieme — invece che **additiva**, cioè un pezzo che si aggiunge lasciando
al suo posto quello che c'era. È la differenza che decide se una prova si può
annullare cancellando due righe o se richiede di rifare la configurazione.

Riporta la decisione all'utente prima di installare qualcosa. Un plugin nuovo è un
impegno di manutenzione, non un dettaglio implementativo.

## Reference

- `../nvim-language-support/SKILL.md` — la procedura completa per un linguaggio.
