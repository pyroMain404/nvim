---
name: nvim-config-testing
description: Use when verifying that a change to this Neovim configuration actually works, deciding what and when to check, delivering interactive verification steps, closing verification, or recording what a check taught you. Use whenever the user says "verifica", "testa", "controlla che funzioni", "prova questa modifica", "è rotto qualcosa?", "fammi vedere che si apre giusto", and whenever a change under `configs/` is about to be called done. This repository has no test suite; this skill is the verification entry point.
---

# Verificare una modifica a questa config

Questo repository non ha una suite di test: la verifica è manuale, deliberata, e
le sue regole stanno qui; il banco di prova è in `nvim-headless-probes`. `AGENTS.md`, le altre skill e i commenti della
config rimandano a questo file e non ripetono niente, perché una regola di
verifica scritta in due posti diverge al primo aggiornamento, e da quel momento
nessuno dei due sa più cosa sia vero.

Gli obiettivi sono tre, in ordine:

1. **Controllare quello che può essere falso**, non quello che è comodo
   guardare.
2. **Farlo una volta sola**, con il banco di prova in `../nvim-headless-probes/assets/`, invece di
   riscrivere ogni volta lo stesso comando sbagliato in un modo diverso.
3. **Lasciare questa skill più precisa** di come l'hai trovata: ogni verifica
   scopre qualcosa su Neovim, sulla macchina o su se stessa, e quella scoperta
   torna qui ([Auto-miglioramento](#auto-miglioramento--a-ogni-test)).

## Regola 1 — Un controllo che passerebbe comunque non è un controllo

È il criterio che genera tutti gli altri. "Il server si attacca" è vero anche
senza il file in `after/lsp/`; "l'highlight funziona" è vero anche con il vecchio
`syntax/`; "la config si avvia" è vero anche se la modifica non è stata salvata.
Un controllo utile **può fallire**, e il suo fallimento **accusa un livello
preciso**.

Da qui tre conseguenze pratiche:

- **Prima di verificare, sapere cosa distinguerebbe il giusto dallo sbagliato.**
  Se due letture della richiesta portano a due esiti diversi ed entrambi
  "funzionano", non è un problema di verifica: è la richiesta che va chiarita
  prima, altrimenti si finisce per testare benissimo la cosa sbagliata.
- **Misurare, non guardare.** Una finestra "a destra" è un'impressione;
  `row=1 col=92 w=108 h=57` è un fatto, ed è quello che smaschera il secondo file
  che si comporta diversamente dal primo.
- **L'evidenza si conserva insieme all'esito.** Un `PASS` senza il valore
  osservato costringe a rifare tutto per sapere cosa era passato.

## Regola 2 — Una sola passata, alla fine

Non eseguire controlli headless mentre lavori: concentra tutto in un passaggio
alla fine del compito. Verificare a metà costa due volte, e la metà che non è
finita produce fallimenti che non significano niente.

La passata finale copre sempre due cose:

1. **l'avvio pulito** (sonda `startup`), perché un file che lancia un errore
   mentre si carica si porta via tutto ciò che sarebbe stato registrato dopo, e
   il sintomo compare altrove;
2. **i controlli mirati sui file toccati**, inclusi i moduli caricati da
   `Config.later()`, che vanno forzati.

Se ti accorgi a metà passata che ne serve un'altra, quella è l'informazione da
scrivere: la sonda o il parametro che mancava va aggiunto in `nvim-headless-probes`, non improvvisato
una seconda volta.

## Regola 3 — Ciò che è interattivo si consegna, non si simula

UI, LSP e plugin differiti non si riproducono fedelmente fuori da una sessione
vera. Quando il comportamento da verificare è interattivo — un colore, un popup,
il modo in cui una finestra "si sente" — la cosa giusta è **consegnare
all'utente i passi esatti**, non descriverli e non fingere di averli eseguiti.

I passi si consegnano così: il comando esatto da incollare, il punto preciso su
cui mettere il cursore, e **cosa dovrebbe succedere**, in modo che l'utente possa
dire di no. `../nvim-headless-probes/assets/run.ps1 -Show` stampa la riga di comando esatta di una sonda, che
vale più di qualunque descrizione.

Il banco di prova, le operazioni e le trappole delle sonde stanno in `nvim-headless-probes`; le trappole Windows/shell in `nvim-shell-traps`, quelle Neovim/plugin in `nvim-runtime-traps`; gli antipattern stanno qui.

## Antipattern

Errori già commessi in questo repository, con quello che sono costati. Non sono
ipotesi: sono il motivo per cui questa skill esiste.

| Antipattern | Cosa costa | Cosa fare invece |
|---|---|---|
| Cercare a tappeto sul filesystem (`find /`, `Get-ChildItem -Recurse` dalla radice) | due minuti di timeout e un processo orfano, per un file che stava in un posto noto | i plugin stanno in `stdpath('data')/site/pack/core/opt/`, la config è il link `~/AppData/Local/nvim`: parti da lì |
| Lasciare vivo il processo di un test | resta a girare per tutta la sessione, e lo scopre l'utente | usa `run.ps1`, che ha il watchdog; se lanci a mano, uccidi tu e poi verifica |
| Modificare un file con uno script che lo riscrive tutto (Python, `sed -i`) | line ending convertiti in silenzio. Con `core.autocrlf` **`git diff` resta pulito**: mostra solo le righe toccate mentre il file su disco è passato a LF, e a dirlo è solo il `warning: LF will be replaced by CRLF` sopra il diff | scrivi con il line ending del file: in Python `newline=''` **in scrittura non basta**, perché la lettura in modalità testo ha già convertito i CRLF in `\n` e li riscrive così. Serve `newline=''` **anche in lettura**, o si lavora in binario. Il `perl -i -pe` di Msys invece non converte niente: le righe non toccate restano byte per byte, e resta da scrivere a mano solo il CRLF di una riga **aggiunta** dalla sostituzione - con la cautela sui backslash della shell, in Trappole. Verifica contando i byte di fine riga o con `stylua --check`, non con `git diff --stat` |
| Cercare un blocco di testo senza la sua indentazione o senza il suo line ending | l'`assert` fallisce e si perde un giro a capire perché | normalizza (`replace('\r\n', '\n')`), edita, riconverti; e metti sempre un `assert` **prima** di scrivere |
| Filtrare l'output di una sonda (un `Select-String` sui soli `PASS` e `FAIL`, un `grep -E`) per accorciarlo | l'evidenza sta nella riga **indentata sotto** l'esito e non contiene nessuna di quelle parole: resta un `FAIL` senza il valore osservato, e si va a cercare nella config un guasto che l'evidenza avrebbe smentito in un colpo. Successo due volte in un giro solo, su `injected` e su `group` | leggi l'esito intero. Se è davvero troppo lungo, filtra con `-Context 0,1` |
| Guardare l'output e dire "sembra giusto" | quello che non torna è proprio quello che non si guarda | fai dire alla sonda `PASS`/`FAIL`, con l'evidenza accanto |
| Due passate di verifica perché la prima non copriva un caso | tempo doppio, e l'utente lo vede | elenca i casi **prima** (primo file, secondo file, dopo la chiusura), poi scrivi una sonda sola |
| Testare in una directory che non è un repository git, per una funzione git | ogni comando fallisce per il motivo sbagliato | verifica il presupposto per primo (`git -C <dir> rev-parse`), o usa questo repository |
| Prendere la baseline con `git checkout --` **del file che si sta modificando**, per una funzione che legge il working tree | il ripristino toglie l'unica modifica non committata che c'era, `:Git diff` non ha più nessuna hunk, il `<CR>` non apre niente e la sonda fotografa il buffer di partenza: un rapporto plausibile che non ha esercitato il percorso | la baseline di una funzione git si prende con il worktree separato e `-Appname` (vedi la riga sopra), che lascia il working tree dirty; e la sonda deve pretendere di essere arrivata da qualche parte (il nome del buffer, la riga del cursore), non solo leggere delle opzioni |
| Verificare un server LSP in una directory scratch senza root marker | il server si attacca e risponde alle richieste, ma resta in single-file mode e per certi server (`lua_ls`) non manda **nessuna** diagnostica: identico a una config sbagliata, e si indaga un guasto che non c'è | dai una radice alla directory di prova (`git init`) o verifica dentro questo repository, e conferma la root letta con `client.root_dir` |
| Implementare prima di aver deciso quale delle due letture della richiesta sia quella giusta | si verifica benissimo la cosa sbagliata | vedi Regola 1: se non sai cosa distinguerebbe il successo dal fallimento, chiedi |
| Prendere per guasto della config un'aspettativa sbagliata della sonda | si va a cercare un bug che non c'è | quando una sonda fallisce, il primo sospetto è il parametro che le hai dato (un `pattern` sensibile alle maiuscole, un server non abilitato) |
| Verificare N mapping con N esecuzioni della sonda `keymap` (una per `lhs`) | N avvii di Neovim per una domanda sola, e dopo una rinomina le mapping da controllare sono il doppio, perché vanno provate anche **assenti** quelle vecchie - cosa che la sonda `keymap` non sa dire, uscendo 1 sul `lhs` che non trova, indistinguibile da un guasto | un inventario in una sonda sola: uno snippet `before` che gira `maparg()` su tutte, presenti e assenti, accumula gli scarti e li lascia in una `vim.b.<nome>`, letta con `vars` e un `expect` che pretende la lista vuota. La sonda `keymap` resta quella giusta per **premere** una mapping, che è un caso per volta |
| Indagare un `FAIL` senza sapere se esisteva già prima della modifica | si cerca la causa nel proprio lavoro, dove non c'è | tieni una baseline accanto: `git worktree add --detach <tmp> HEAD`, una junction da `%LOCALAPPDATA%\nvim-baseline` alla sua radice e una da `nvim-baseline-data` a `nvim-data` (stessi plugin, nessun download), poi la stessa sonda con `-Appname nvim-baseline`. Due output affiancati dicono in un colpo solo se il comportamento è cambiato |

## Chiudere la verifica

Prima di dire che è finita:

- nessun processo lasciato in giro (`Get-Process nvim`, i job in background, e
  **il processo del server di linguaggio**, che sopravvive a Neovim);
- `git diff --stat` mostra solo quello che intendevi cambiare;
- `stylua --check <file>` dalla radice, sui file Lua toccati;
- l'esito è riportato per quello che è: se un controllo non è stato eseguito, si
  dice; se è fallito, si mostra l'output.

## Auto-miglioramento — a ogni test

**Ogni verifica è anche una verifica di questa skill.** All'inizio,
gli [antipattern](#antipattern) qui e le trappole in `nvim-headless-probes`, `nvim-shell-traps` e `nvim-runtime-traps` vanno **letti**, non ricordati; alla fine, ciò che la
sessione ha scoperto torna qui. Senza questo passo la conoscenza muore con la
sessione e la volta dopo si ripete lo stesso errore — che è esattamente come sono
nate le righe che stai leggendo.

Il lavoro è finito quando la skill è aggiornata, non quando il controllo è
passato.

**Cosa qualifica.** Il criterio è uno: *se l'avessi saputo prima di cominciare,
avrei verificato diversamente.* E deve essere **osservato** — un comando
eseguito, un output letto — non dedotto e non ricordato. In particolare:

- una sonda che ha **mentito**, o che si è rivelata insufficiente;
- un parametro che è servito e non c'era;
- un comportamento di Neovim, della shell o della macchina che ha fatto perdere
  un giro;
- un errore commesso durante la verifica, anche banale, **soprattutto** se
  banale: sono quelli che si ripetono.

**Dove va.**

| Cosa hai imparato | Dove va |
|---|---|
| Neovim, la shell o la macchina si comportano in modo non ovvio | banco delle sonde → [Trappole di nvim-headless-probes](../nvim-headless-probes/SKILL.md#trappole); shell e strumenti → [Trappole di nvim-shell-traps](../nvim-shell-traps/SKILL.md#trappole); Neovim e plugin → [Trappole di nvim-runtime-traps](../nvim-runtime-traps/SKILL.md#trappole) |
| Un modo di procedere ha fatto perdere tempo o ha prodotto un esito falso | tabella [Antipattern](#antipattern) |
| Una sonda ha bisogno di un parametro, o un suo default è sbagliato | l'asset in `../nvim-headless-probes/assets/`, insieme alla sua intestazione di documentazione |
| Serve un'operazione che nessuna sonda copre | una sonda nuova in `../nvim-headless-probes/assets/`, aggiunta alla tabella [Le operazioni](../nvim-headless-probes/SKILL.md#le-operazioni) di `nvim-headless-probes`; se ne sostituisce una, la vecchia si cancella |
| Riguarda **cosa** verificare in un linguaggio preciso | la reference di quel linguaggio in `nvim-language-support`, **mai** qui |

**Cosa non scrivere.** Questa skill è un indice, e un indice che registra tutto
non indicizza niente:

- il racconto della sessione: cosa è stato provato e in che ordine;
- ciò che il repository già dice (`AGENTS.md`, i commenti della config), che si
  richiama con un rimando e non si riassume;
- una regola dedotta e non osservata: scritta come fatto, è peggio del silenzio;
- una riga che ne ripete un'altra: si corregge quella, non se ne aggiunge una
  seconda che col tempo diverge.

L'aggiornamento di questa skill è **un commit a sé**, separato da quelli della
config: risolve un problema diverso, come chiede `AGENTS.md`.

## Reference

- `../nvim-headless-probes/SKILL.md` — banco di prova, operazioni e trappole delle sonde.
- `../nvim-shell-traps/SKILL.md` — le trappole Windows, shell e strumenti.
- `../nvim-runtime-traps/SKILL.md` — le trappole di Neovim e dei plugin.
