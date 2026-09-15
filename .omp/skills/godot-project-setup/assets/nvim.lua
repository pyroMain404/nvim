-- ┌──────────────────────────────┐
-- │ Project environment: <gioco> │
-- └──────────────────────────────┘
--
-- Copiare nella root del gioco come '.nvim.lua', tenere solo le righe che
-- servono, poi aprirlo una volta e `:trust`. Senza fiducia il file non viene
-- sorgentato e niente di quanto segue esiste, SENZA un errore (`:h 'exrc'`).
-- Ogni modifica annulla la fiducia: `:trust` va rifatto.
--
-- Questo file è letto all'avvio, prima di qualunque buffer. È la ragione per cui
-- le tre cose qui sotto non possono stare in un ftplugin: arriverebbe tardi.

-- 1. La porta su cui l'editor Godot apre i file in QUESTA istanza di Neovim.
--    Va insieme agli `Exec Flags` di Godot:
--      --server 127.0.0.1:55432 --remote-send "<C-\><C-N>:e {file}<CR>:call cursor({line},{col})<CR>"
--
--    `serverstart()` aggiunge un listener SECONDARIO: `v:servername` resta la
--    named pipe di default, e `serverlist()` mostra entrambi (misurato). Un
--    secondo bind sulla stessa porta SOLLEVA, quindi il `pcall`: due Neovim
--    aperti sullo stesso gioco non sono un errore, e il primo tiene la porta.
--
--    NOTE: TCP e non una named pipe. `//./pipe/<nome>` è la forma che vuole
--    Windows e si scrive diversamente altrove; e la ricetta diffusa
--    `--listen {project}/server.pipe` crea un file DENTRO il repository, che poi
--    va escluso dal versionamento e nascosto in ogni picker.
local ok, err = pcall(vim.fn.serverstart, '127.0.0.1:55432')
if not ok then
  vim.notify('Godot editor port: ' .. tostring(err), vim.log.levels.WARN)
end

-- 2. SOLO se questo non è il primo Godot aperto sulla macchina. La porta è una
--    risorsa della macchina: la seconda istanza dell'editor non ripiega su
--    un'altra, resta senza, e i buffer di questo progetto si attaccherebbero in
--    silenzio al server dell'ALTRO gioco. Va insieme a `godot --lsp-port 6105`.
--    Cancellare queste righe se il caso non esiste.
-- vim.env.GDScript_Port = '6105'

-- 3. SOLO se il gioco non si avvia con `godot --path <root>`, che è il default
--    di `:Run` per un buffer GDScript. Una lista sostituisce il comando intero e
--    gli argomenti della chiamata le si aggiungono in coda.
-- vim.g.run_command = { 'godot', '--path', vim.fn.getcwd(), 'res://scenes/dev.tscn' }

-- 4. SOLO se i '*.gd.uid' accanto a ogni script danno fastidio nei picker e in
--    'mini.files'. Sono file da committare e non da cancellare: qui si nascondono
--    soltanto alla vista, ed è una preferenza di questo progetto. Il campo è
--    `content.filter`, `:h MiniFiles.config`.
