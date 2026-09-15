-- ┌────────────────────┐
-- │ GDScript behaviour │
-- └────────────────────┘
--
-- This file contains behavior specific to GDScript buffers, added on top of
-- what '$VIMRUNTIME/ftplugin/gdscript.vim' and '$VIMRUNTIME/indent/gdscript.vim'
-- already do: `commentstring`, hard tabs (`expandtab` off, `tabstop=4`,
-- `shiftwidth=0` so the indent follows the tab stop, which is what Godot
-- recommends), `suffixesadd=.gd` for `gf`, an `indentexpr` and a fold
-- expression. None of it is repeated here, and none of it needs correcting.
-- `:verbose setlocal commentstring? tabstop? foldexpr?` says who set what.
--
-- What is missing is everything that talks to the engine, and it is what
-- follows: `:make`, `:Run`, the documentation with the editor closed, and the
-- way back after the editor is restarted.

-- The project this buffer belongs to, read once and HERE: `:Run` resolves after
-- `:vertical new` may have made a nameless buffer current, so a resolver that
-- asked then would read an empty name.
local root = vim.fs.root(0, { 'project.godot' })

-- Build and test through `:h :make`, so that a parse error lands in the
-- quickfix list and `]q` / `[q` of 'mini.bracketed' walk it. What the engine
-- can and cannot answer is in 'compiler/godot.lua'; only the project gate is
-- here, because a '.gd' file outside a project has no engine to ask.
if root ~= nil then
  vim.cmd('compiler godot')

  -- `:make` has to run from the project root, and a compiler plugin cannot put
  -- it there: it sets options, and this is a directory. The engine's own
  -- `--path` is not enough either, and that is the part worth remembering -
  -- it tells Godot which project to open, while the file names it prints stay
  -- relative to that project (`res://scripts/broken.gd`) and Neovim resolves
  -- quickfix names against ITS OWN directory. Measured from 'scripts/': every
  -- entry pointed at '<root>/scripts/scripts/broken.gd', and `]q` opened an
  -- empty buffer with that name - no error, no message, and the natural
  -- reading is that the quickfix list is wrong rather than the directory.
  --
  -- NOTE: the pair cannot be buffer-local. `QuickFixCmdPre` matches its
  -- pattern against the COMMAND NAME (`:h QuickFixCmdPre`), so `buffer = 0`
  -- would ask for a pattern that never matches. Hence one named group,
  -- cleared on every load so that opening a second '.gd' file replaces the
  -- pair instead of adding one, and a filetype test inside the callback.
  --
  -- `vim.fn.chdir()` and not `:lcd`: it changes the directory in whatever
  -- scope the current one has - window, tab or global - and returns the
  -- previous one to restore. `:lcd` would leave the window with a local
  -- directory it did not have, which `MiniMisc.setup_auto_root()` would then
  -- never move again.
  local group = vim.api.nvim_create_augroup('config-godot-make', { clear = true })
  local previous = nil
  vim.api.nvim_create_autocmd('QuickFixCmdPre', {
    group = group,
    pattern = { 'make', 'lmake' },
    desc = 'Run `:make` from the root of the Godot project',
    callback = function()
      if vim.bo.filetype ~= 'gdscript' then return end
      local project = vim.fs.root(0, { 'project.godot' })
      if project == nil then return end
      previous = vim.fn.chdir(project)
    end,
  })
  vim.api.nvim_create_autocmd('QuickFixCmdPost', {
    group = group,
    pattern = { 'make', 'lmake' },
    desc = 'Return to the directory `:make` was called from',
    callback = function()
      if previous == nil or previous == '' then return end
      vim.fn.chdir(previous)
      previous = nil
    end,
  })
end

-- Running the game, under the contract of 'lua/config/run.lua'. Nothing is read
-- from 'project.godot' here because the engine reads it: `run/main_scene` is the
-- default, and a project that declares none refuses loudly with `Can't run
-- project: no main scene defined in the project` (measured, exit 1), which is
-- the loud failure the contract asks for instead of starting the wrong thing.
-- Arguments reach the engine, so `:Run res://scenes/level.tscn` runs one scene.
--
-- DETACHED, which is the branch the contract keeps for a program with a window
-- of its own, and here it is a measurement and not a preference: invoked
-- captured, the game opens a `buftype=terminal` with a live job whose buffer
-- stays EMPTY, while its output comes out on the stdout of Neovim itself - the
-- screen the interface is drawn on. NOTE: a detached game therefore outlives
-- `:qa`. That is the trade of this branch, and for a windowed program it is the
-- right way round: closing the editor is not a reason to kill what is running.
require('config.run').command(function(args)
  if root == nil then
    return nil, 'no project.godot above this file: there is no game to run'
  end
  return vim.list_extend({ 'godot', '--path', root }, args)
end, { detach = true })

-- NOTE: the output of the game is not captured anywhere, by construction of
-- the branch above. Bringing it into Neovim - a scratch buffer fed by
-- `vim.system()` with `stdout`, instead of `detach` - is a separate axis
-- (`capabilities.md` §19), and the order matters: it is worth judging after
-- the detached form has been used on a real game, not before. Until then the
-- place to read `print()` is the Output panel of the Godot editor.

-- TODO: a game needs `:make`-like entries for the two things the engine cannot
-- be asked from here - running the test suite and exporting a build - and they
-- genuinely depend on the project, so they belong to the `mise.toml` of the
-- game as tasks (`mise run export:windows`), not to this file. Nothing here
-- covers them today, and a reader should not conclude that `:make` does.
-- First step, on the first real game: write `[tasks."export:windows"]` with
-- `godot --headless --export-release <preset> <output>` in that repository,
-- having installed the export templates of the exact engine version under
-- '%APPDATA%\Godot\export_templates\<version>' - `mise` does not install them
-- with the engine. Then decide whether `:Run mise ...` is worth a wrapper here
-- or stays a terminal command, which is a question this config cannot answer
-- before a project exists.

-- NOTE: there is no debugger. Godot speaks DAP on the port next to the LSP
-- one, but Neovim is not a DAP client by itself: it would take 'nvim-dap' plus
-- a workflow decision, and the only integration Godot hosts
-- ('emacs-gdscript-mode') has a debugger for Godot 3 only. What exists without
-- any of that, and is worth knowing: the `breakpoint` keyword of GDScript
-- stops the engine's own debugger on the line it is written on, and with
-- `Debug with External Editor` enabled in the Script view it is Godot that
-- brings the external editor onto that line.

-- TODO: read a '.tscn' as the tree it is, not as the INI it is written as. The
-- node hierarchy with the type of each node is the structure one reasons about
-- in Godot, and a section list is not the same thing. Deferred because half of
-- what it would be used for - *which* scene do I open - is already a picker,
-- and the other half costs code to maintain.
-- First step: a scratch buffer (`:h scratch-buffer`: `buftype=nofile`,
-- `bufhidden=wipe`, not modifiable) built from the parse of the current
-- '.tscn' - the `godot_resource` parser is installed, so the sections can be
-- read from the tree rather than with a regex - one line per node, indented by
-- the depth of its `parent=` path, with the type after the name, and `<CR>`
-- jumping to the section of that node in the file. It belongs to a
-- 'after/ftplugin/gdresource.lua', not here: it is a property of the resource
-- file, not of GDScript.

-- The documentation of the word under the cursor, in the browser. The LSP hover
-- gives it too, and better - but only with Godot open on the project, which is
-- exactly not the case while reading code. `vim.ui.open()` goes through the
-- system handler and adds no dependency (`:h vim.ui.open()`).
--
-- The search page and not 'classes/class_<name>.html', which is the form every
-- recipe shows: that one is a direct hit for a class and a 404 for everything
-- else, and most words under the cursor are not classes - `move_and_slide`,
-- `velocity` and `PROCESS_MODE_ALWAYS` have no page of their own, while the
-- search finds all three. One page in between, and it can never be wrong.
--
-- NOTE: `stable` is the documentation of the newest released engine, not of the
-- one this game pins in its 'mise.toml'. Reading a 4.5 page while working on
-- 4.7 has no symptom, and the day that matters the URL takes an `en/<x.y>/`.
vim.api.nvim_buf_create_user_command(0, 'GodotDoc', function()
  local word = vim.fn.expand('<cword>')
  vim.ui.open('https://docs.godotengine.org/en/stable/search.html?q=' .. word)
end, { desc = 'Godot documentation for the word under the cursor' })

-- Closing and reopening the Godot editor is an ordinary thing to do in a day of
-- work, and it takes the language server with it: the buffers already open stay
-- without a client, nothing says so, and completion and diagnostics are simply
-- mute from then on. What triggers the attach again is `:edit`, because it goes
-- through `FileType` once more - there is no "retry" to call otherwise.
vim.api.nvim_buf_create_user_command(0, 'GodotReconnect', function()
  if vim.bo.modified then
    local message = 'Write the buffer first: reattaching reloads it from disk'
    return vim.notify(message, vim.log.levels.WARN)
  end
  vim.cmd.edit()
end, { desc = 'Reattach the language server after restarting Godot' })
