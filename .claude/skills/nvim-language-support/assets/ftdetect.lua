-- ┌────────────────────┐
-- │ Filetype detection │
-- └────────────────────┘
--
-- Skeleton for 'ftdetect/<lang>.lua'. Copy, rename after the language, keep only
-- the rules that are needed.
--
-- Files in 'ftdetect/' are sourced as part of filetype detection, so this is the
-- one place where a filetype can be taught before anything else runs: no ftplugin
-- loads, no parser starts and no language server attaches until the filetype is
-- set. See `:h ftdetect` and `:h vim.filetype.add()`.
--
-- Check first whether this file is needed at all — Neovim already knows several
-- hundred filetypes:
--   :=vim.filetype.match({ filename = 'example.xyz' })
--
-- For a format met once in a single file, a modeline in that file (`:h modeline`)
-- is the proportionate answer and costs this config nothing.

vim.filetype.add({
  -- Keyed by extension without the dot. The cheapest and most common rule.
  extension = {
    myext = 'mylang',
  },

  -- Keyed by full file name, for files that carry no extension.
  filename = {
    ['Mylangfile'] = 'mylang',
    ['.mylangrc'] = 'mylang',
  },

  -- Keyed by Lua pattern matched against the full path. Used last, so keep it for
  -- what the two above can not express: a name that only means something inside a
  -- certain directory.
  pattern = {
    ['.*/mylang/.*%.conf'] = 'mylang',
  },
})

-- A new filetype that should reuse an existing tree-sitter parser does not need a
-- parser of its own, only the mapping (`:h vim.treesitter.language.register()`):
-- vim.treesitter.language.register('toml', 'mylang')
