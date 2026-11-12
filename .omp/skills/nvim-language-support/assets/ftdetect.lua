-- ┌────────────────────┐
-- │ Filetype detection │
-- └────────────────────┘
--
-- Use this template for 'ftdetect/<lang>.lua'.
-- Copy this file. Rename the copy after the language.
-- Keep only the necessary rules.
--
-- Neovim loads files in 'ftdetect/' during filetype detection,
-- before ftplugins, parsers, or language servers start.
-- Set the filetype here before those features run.
-- See `:h ftdetect` and `:h vim.filetype.add()`.
--
-- First, check if Neovim already knows the filetype; it supports several hundred filetypes:
--   :=vim.filetype.match({ filename = 'example.xyz' })
--
-- For a format in only one file, use a modeline in that file (`:h modeline`).
-- A modeline needs no change to this config.

vim.filetype.add({
  -- Use the extension without its dot as the key for this simple, common rule.
  extension = {
    myext = 'mylang',
  },

  -- Use the full file name as the key for files without extensions.
  filename = {
    ['Mylangfile'] = 'mylang',
    ['.mylangrc'] = 'mylang',
  },

  -- Use a Lua pattern that matches the full path as the key.
  -- Neovim checks patterns last.
  -- Use them only for cases the other rules cannot express, such as names that depend on a directory.
  pattern = {
    ['.*/mylang/.*%.conf'] = 'mylang',
  },
})

-- Map a new filetype to an existing tree-sitter parser instead of adding a parser
-- (`:h vim.treesitter.language.register()`).
-- vim.treesitter.language.register('toml', 'mylang')
