-- ┌──────────────────────────────┐
-- │ Project environment: <game>  │
-- └──────────────────────────────┘
--
-- Copy this file into the game root as '.nvim.lua'.
-- Keep only applicable lines.
-- Open the file once and run `:trust`.
--
-- Without trust, Neovim loads none of this file and gives no error (`:h 'exrc'`).
-- Each edit removes trust, so run `:trust` again after edits.
-- Neovim reads this file at startup, before any buffer.
-- The three settings below would arrive too late in an ftplugin.
--
-- This file adds only Godot-specific settings to the base '.nvim.lua' template,
-- 'nvim-project-environment/assets/nvim.lua'.

-- 1. This is the port that the Godot editor uses to open files in this Neovim instance.
--    It goes together with Godot's own `Exec Flags`:
--      --server 127.0.0.1:55432 --remote-send "<C-\><C-N>:e {file}<CR>:call cursor({line},{col})<CR>"
--
--    `serverstart()` adds a second listener.
--    `v:servername` keeps the default named pipe, and `serverlist()` shows both listeners, as measured.
--    A second bind on the same port raises an error.
--    `pcall` catches it, because two Neovim instances on the same game are not an error.
--    The first instance keeps the port.
--
-- NOTE: The port uses TCP, not a named pipe.
--    Windows needs the form `//./pipe/<name>`, which other systems write differently.
--    The common recipe `--listen {project}/server.pipe` creates a file inside the repository.
--    Exclude that file from version control.
--    Hide it in every picker.
local ok, err = pcall(vim.fn.serverstart, '127.0.0.1:55432')
if not ok then
  vim.notify('Godot editor port: ' .. tostring(err), vim.log.levels.WARN)
end

-- 2. Use this only if another Godot instance is already open on the machine.
--    The port belongs to the machine, not the project.
--    A second editor instance cannot use another port automatically and gets no port.
--    This project's buffers would silently attach to the other game's server.
--    Use this with `godot --lsp-port 6105`.
--    Delete these lines if this case does not apply.
-- vim.env.GDScript_Port = '6105'

-- 3. Use this only if the game cannot start with `godot --path <root>`.
--    That command is the default `:Run` for a GDScript buffer.
--    A list replaces the complete command, and `:Run` adds the call arguments to it.
-- require('config.project').set('run', { 'godot', '--path', vim.fn.getcwd(), 'res://scenes/dev.tscn' })
