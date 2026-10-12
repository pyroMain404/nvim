-- ┌──────────────────────────────┐
-- │ Project environment: <game>  │
-- └──────────────────────────────┘
--
-- Copy into the game's root as '.nvim.lua', keep only the lines that apply,
-- then open it once and `:trust`. Without trust the file is not sourced and
-- nothing below exists, with NO error (`:h 'exrc'`). Every edit voids trust:
-- `:trust` has to be redone.
--
-- This file is read at startup, before any buffer. That is why the three
-- things below cannot live in an ftplugin: they would arrive too late.
--
-- This is a diff against 'nvim-project-environment/assets/nvim.lua', the base
-- '.nvim.lua' skeleton: only what Godot specifically adds is here.

-- 1. The port the Godot editor opens files on, in THIS Neovim instance. Goes
--    together with Godot's own `Exec Flags`:
--      --server 127.0.0.1:55432 --remote-send "<C-\><C-N>:e {file}<CR>:call cursor({line},{col})<CR>"
--
--    `serverstart()` adds a SECONDARY listener: `v:servername` stays the
--    default named pipe, and `serverlist()` shows both (measured). A second
--    bind on the same port RAISES, hence the `pcall`: two Neovim instances
--    open on the same game are not an error, and the first one keeps the
--    port.
--
--    NOTE: TCP, not a named pipe. `//./pipe/<name>` is the form Windows wants
--    and is written differently elsewhere; and the common recipe
--    `--listen {project}/server.pipe` creates a file INSIDE the repository,
--    which then has to be excluded from version control and hidden in every
--    picker.
local ok, err = pcall(vim.fn.serverstart, '127.0.0.1:55432')
if not ok then
  vim.notify('Godot editor port: ' .. tostring(err), vim.log.levels.WARN)
end

-- 2. ONLY if this is not the first Godot instance open on the machine. The
--    port is a resource of the machine: the second instance of the editor
--    does not fall back to another one, is left without, and this project's
--    buffers would silently attach to the OTHER game's server. Goes together
--    with `godot --lsp-port 6105`. Delete these lines if that case does not
--    apply.
-- vim.env.GDScript_Port = '6105'

-- 3. ONLY if the game does not start with `godot --path <root>`, which is
--    the default `:Run` a GDScript buffer already uses. A list replaces the
--    whole command, and the arguments of the call are appended to it.
-- vim.g.run_command = { 'godot', '--path', vim.fn.getcwd(), 'res://scenes/dev.tscn' }

-- 4. ONLY if the '*.gd.uid' files next to every script get in the way in
--    pickers and in 'mini.files'. They are files to commit, not to delete:
--    this only hides them from view, and it is a preference of this project.
--    The field is `content.filter`, `:h MiniFiles.config`.
