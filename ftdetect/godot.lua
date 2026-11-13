-- ┌────────────────────────┐
-- │ Godot file recognition │
-- └────────────────────────┘
--
-- This file adds two Godot extensions that Neovim does not recognize
-- (`:h vim.filetype.add()`, `:h ftdetect`).
vim.filetype.add({
  extension = {
    -- The `gdshader` parser declares the shader include filetype ('plugin/40_plugins.lua').
    gdshaderinc = 'gdshaderinc',
    -- Neovim calls the INI format of a GDExtension library declaration `dosini`.
    gdextension = 'dosini',
  },
})
