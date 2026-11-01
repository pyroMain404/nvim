-- ┌────────────────────────┐
-- │ Godot file recognition │
-- └────────────────────────┘
--
-- Two Godot extensions Neovim does not know (`:h vim.filetype.add()`, `:h ftdetect`).
vim.filetype.add({
  extension = {
    -- Shader include; the `gdshader` parser declares this filetype ('plugin/40_plugins.lua').
    gdshaderinc = 'gdshaderinc',
    -- GDExtension library declaration, an INI: `dosini` is what Neovim calls it.
    gdextension = 'dosini',
  },
})
