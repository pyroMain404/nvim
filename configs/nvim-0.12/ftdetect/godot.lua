-- ┌────────────────────────┐
-- │ Godot file recognition │
-- └────────────────────────┘
--
-- Two extensions of the Godot ecosystem that Neovim does not know (measured
-- with `vim.filetype.match({ filename = … })`, which answers nil for both).
-- Everything else is already right: '.gd' is `gdscript`, '.gdshader' is
-- `gdshader`, '.tscn' and '.tres' are `gdresource`.
--
-- See `:h vim.filetype.add()`, `:h ftdetect`.
vim.filetype.add({
  extension = {
    -- A shader include. The tree-sitter parser `gdshader` already declares
    -- this filetype, so the parser was there and only the file never reached
    -- it: no highlighting, and no chance of any (see 'plugin/40_plugins.lua').
    gdshaderinc = 'gdshaderinc',
    -- The file that declares a GDExtension library to the engine. It is an
    -- INI, and `dosini` is what Neovim calls that - measured, and NOT the
    -- `confini` a stale note claimed: `vim.filetype.match({ filename =
    -- 'a.ini' })` answers `dosini`. Naming the filetype Neovim already uses is
    -- what gives the file its comments, its folds and its syntax for free.
    gdextension = 'dosini',
  },
})
