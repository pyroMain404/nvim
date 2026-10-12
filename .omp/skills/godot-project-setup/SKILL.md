---
name: godot-project-setup
description: Use when a Godot 4 game checkout has to be made to work with this Neovim config — pinning the engine version for that project, writing its '.nvim.lua', wiring Godot as the external editor and Neovim as the one it opens files into, deciding what of a Godot project goes into git, and adding the test and export tasks the editor cannot provide. Make sure to use this skill whenever the user says things like "ho clonato un progetto godot", "configura questo gioco", "nuovo progetto Godot", "Godot non apre i file in nvim", "come faccio a esportare", "quale versione del motore usa questo gioco", "che cosa committo di un progetto Godot" — including when they name only one piece, because the steps depend on each other and the order is what keeps them from failing silently.
---

# Setup di un progetto Godot

Questa skill riguarda il **checkout del gioco**, non la config di Neovim. Il supporto
GDScript — parser, server, `gdformat`, `:make`, `:Run`, health check — è già nella
config e non va rifatto qui: se manca qualcosa *lì*, la sede è
`nvim-language-support` e la sua `references/godot.md`, che è anche dove stanno le
misure su cosa il motore risponde e cosa no.

Qui sta ciò che ogni gioco deve dichiarare **di sé**, e che nessuna config globale può
indovinare: quale motore, su quale porta, con quali task, e cosa di tutto quello che
Godot genera finisce in git.

**L'ordine conta.** Ogni passo fallisce in silenzio se il precedente manca: senza la
versione fissata lo shim non parte, senza il motore aperto non c'è nessun server, senza
fiducia il `.nvim.lua` non viene letto e tutto ciò che imposta semplicemente non esiste.

## 1. Fissare la versione del motore

Un gioco resta sulla versione con cui è stato scritto, e aprirlo con una più nuova ne
converte i file. La versione è quindi una proprietà **del progetto**:

```powershell
cd <root del gioco>
mise use godot@4.5.1-stable     # scrive il 'mise.toml' del progetto, da committare
godot --version                 # deve rispondere quella versione, eseguito da qui
```

**Verificare dove `mise` ha scritto, non solo cosa.** `mise use` senza `--path`
risale l'albero delle directory e aggiorna il **primo** `mise.toml` che trova già
esistente, invece di crearne uno in `<root del gioco>`. Misurato: con un
`mise.toml` già presente più in alto (un file condiviso per strumenti globali), il
comando ha scritto la versione del motore **lì**, pinnandola per ogni progetto sotto
quella directory e non solo per questo gioco — il comando stesso nomina il file nel
suo output (`mise <percorso> tools: godot@...`), ed è quella riga a dover essere
letta, non solo l'exit code. Se il percorso non è `<root del gioco>/mise.toml`,
rimuovere la riga da dove è finita e creare il file corretto a mano.

Se `godot --version` risponde `mise ERROR No version is set for shim: godot`, il
comando è stato eseguito fuori dal progetto: lo shim risolve la versione **dalla
directory corrente**, e `--path` non rimedia perché quel flag parla al motore dopo che
`mise` ha già scelto quale motore lanciare.

Conseguenza che si paga più tardi: l'editor va aperto **da questa directory**
(`godot --editor` da qui), non da un collegamento sul desktop, che lancia una
installazione qualunque e non sa niente di questo file.

Le versioni disponibili sono solo le `-stable`, e **non esiste la variante .NET/Mono**:
un gioco in C# non si serve da `mise`.

## 2. Git: cosa entra e cosa no

Tre categorie, e due sono contro-intuitive:

| Percorso | In git? | Perché |
|---|---|---|
| `.godot/` | **no** | cache di import, rigenerata dal motore |
| `*.gd.uid` | **sì** | da Godot 4.4 ogni script ne ha uno accanto: è la sua identità stabile attraverso rinomine e spostamenti. Ignorarlo rompe i riferimenti per chiunque cloni |
| `export_credentials.cfg` | **no** | ci finiscono le credenziali di firma. `export_presets.cfg` invece è configurazione e si committa |

`assets/gitignore` di questa skill è il file minimo da copiare. Verificare con
`git check-ignore -v .godot/uid_cache.bin` e con un `git status` pulito dopo un avvio
del motore: se compare qualcosa di generato, va aggiunto lì e non ignorato a mano.

In 'mini.files' e nei picker i `.gd.uid` raddoppiano le voci di ogni directory di
codice. Nasconderli è legittimo ma è una preferenza di questo progetto, quindi la sede
è il suo `.nvim.lua` (passo 3) e non la config condivisa — il filtro è
`content.filter`, `:h MiniFiles.config`.

## 3. Il `.nvim.lua` del progetto

Copiare `assets/nvim.lua` nella root del gioco come `.nvim.lua` e tenerne solo le righe
che servono. Il file è letto all'avvio (`:h 'exrc'`, già abilitato nella config), quindi
**prima** di qualunque buffer: è l'unico livello dove queste tre cose possono stare.

- **La porta su cui Godot apre i file in Neovim** (`vim.fn.serverstart`). Misurato: è un
  listener *secondario*, `v:servername` non cambia, e un secondo bind sulla stessa porta
  **solleva** — da qui il `pcall` nel template.
- **`GDScript_Port`**, solo se questo gioco non è il primo Godot aperto sulla macchina
  (passo 5).
- **`vim.g.run_command`**, solo se il gioco non si avvia con `godot --path <root>`.

Poi, una volta sola: aprire il file e `:trust`. Senza, `exrc` non lo sorgenta e tutto
ciò che imposta non esiste, **senza un errore**. Ogni modifica al file annulla la
fiducia e va rifatto.

Verifica: `:=vim.fn.serverlist()` deve contenere l'indirizzo scelto.

## 4. Godot come editor esterno

Due direzioni indipendenti, e solo la seconda va configurata: Neovim → Godot (LSP)
funziona da sé appena l'editor è aperto sul progetto.

Dentro `Editor → Editor Settings`:

| Pannello | Impostazione | Valore |
|---|---|---|
| `Network → Language Server` | Remote Host / Remote Port | `127.0.0.1` / `6005` — default, solo da verificare |
| `Network → Language Server` | `Use Thread` | **true**: il server in un thread proprio, così un'operazione pesante dell'editor non sospende le risposte |
| `Network → Language Server` | `Enable Smart Resolve` | **true**: risoluzione dei simboli dinamici |
| `Text Editor → Behavior` | `Auto Reload Scripts on External Change` | **true**: senza, Godot e Neovim divergono in silenzio su un file salvato da fuori |
| `Text Editor → External` | `Use External Editor` | **true** |
| `Text Editor → External` | `Exec Path` | il percorso **completo** di `nvim.exe`. Un processo avviato da un'icona non eredita il `PATH` di una shell |
| `Text Editor → External` | `Exec Flags` | `--server <indirizzo> --remote-send "<C-\><C-N>:e {file}<CR>:call cursor({line},{col})<CR>"` |

Dalla 4.5 Godot compila da sé gli `Exec Flags` per gli editor che documenta — VS Code,
Emacs, Vim, Rider — e **Neovim non è in quell'elenco**: quel campo va scritto a mano, e
lasciato vuoto resta vuoto.

> **Risolto in `nvim-language-support/references/godot.md` "Verifica".** Il motore invia la
> riga 1-based (`p_line` reale, confermato da `godotengine/godot#118228`), quindi
> `cursor({line},{col})` — la forma già configurata — è corretta. Non serve `+1`.
> Resta un bug distinto di Godot per cui un secondo click su uno script già caricato
> può inviare `p_line=-1`: per quello il riferimento ha la misura e il workaround.

`--remote-send` non tratta in modo affidabile i percorsi con caratteri speciali: se la
root del gioco ha spazi o accenti e l'apertura fallisce, la causa è quella.

## 5. Un secondo gioco aperto insieme al primo

Da fare **solo** quando succede davvero, ed è il guasto peggiore di tutta l'area perché
ha l'aspetto del funzionamento: la porta è una risorsa della macchina, la seconda
istanza di Godot **non ripiega su un'altra porta** — resta viva e semplicemente non
ascolta — e Neovim si attacca allora al primo editor, rispondendo con completion,
diagnostica e definizioni **dell'altro gioco**, senza un messaggio.

Il rimedio ha due metà e servono entrambe:

```powershell
godot --editor --lsp-port 6105          # nella root del secondo gioco
```

```lua
vim.env.GDScript_Port = '6105'          -- nel '.nvim.lua' dello stesso gioco
```

Verifica: `:checkhealth config`, sezione Godot, deve nominare 6105 e non 6005.

## 6. Test ed esportazione

Non esistono come comandi dell'editor, e non è una mancanza da colmare lì: dipendono dal
progetto, quindi la sede sono i **task del `mise.toml` del gioco**, accanto alla versione
che quel gioco pinna. `assets/mise-tasks.toml` è la forma da copiare.

Due avvertenze prima di usarla:

- `--export-release` richiede gli **export template della versione esatta**, che `mise`
  **non** installa con il motore. Su Windows vanno sotto
  `%APPDATA%\Godot\export_templates\<versione>`; le guide che circolano usano il percorso
  Linux `~/.local/share/godot/export_templates` e su questa macchina non funziona;
- il nome del preset deve esistere in `export_presets.cfg`, cioè va creato una volta
  dall'editor grafico.

## 7. Verifica

Nell'ordine, perché ognuna presuppone la precedente:

1. `godot --version` dalla root → la versione pinnata (passo 1);
2. Godot aperto sul progetto **da quella directory**;
3. un `*.gd` aperto in Neovim: `:checkhealth config` mostra la sezione Godot con motore,
   `gdformat`, porta e i tre parser;
4. `:checkhealth vim.lsp` → **un solo** client `gdscript`, con `root` sul
   `project.godot` e non sulla directory del `.git`. Una richiesta reale risponde:
   completion su un simbolo del motore, hover su una classe;
5. `:make` su uno script con un errore di sintassi **da una sottodirectory**, non dalla
   root: il quickfix deve avere una voce e `]q` deve aprire **il file vero**, non un
   buffer vuoto con il nome giusto;
6. `<Leader>lf` su un file mal formattato → `gdformat` lo riscrive;
7. da Godot, aprire uno script: deve arrivare nell'istanza già aperta, sulla riga giusta
   (il riquadro del passo 4).

Se il passo 4 dà zero client, l'editor non è aperto o è aperto su un altro progetto;
`:GodotReconnect` in quel buffer è ciò che rifà scattare l'attach dopo un riavvio
dell'editor, perché il client non torna da solo.

## Reference

- `assets/nvim.lua` — solo le tre aggiunte specifiche di Godot, come diff contro `assets/nvim.lua` di `nvim-project-environment`, che resta l'unico scheletro completo di un `.nvim.lua`.
- `assets/gitignore` — le righe minime da aggiungere al `.gitignore` del gioco.
- `assets/mise-tasks.toml` — i task di test ed esportazione.
- Il lato Neovim — cosa la config già fa, e cosa il motore risponde davvero da riga di
  comando — è in `nvim-language-support`, `references/godot.md`. Non è ripetuto qui.
- La regola su quale impostazione appartiene al progetto e quale alla config globale, e
  il registro dei progetti già configurati, sono in `nvim-project-environment`.