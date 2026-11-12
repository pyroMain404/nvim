-- ┌────────────────┐
-- │ Rust behaviour │
-- └────────────────┘
--
-- This file adds a quote safe for lifetimes and `:Run` to '$VIMRUNTIME/ftplugin/rust.vim'.

-- 'mini.pairs' pairs `'`, which causes errors with lifetimes.
-- Map the key to itself to disable pairing in this buffer (`:h MiniPairs.unmap_buf()`).
vim.keymap.set('i', "'", "'", { buf = 0, desc = 'Insert a plain quote' })

-- `:Run` follows 'lua/config/run.lua'; cargo reports an error if it cannot select a binary.
-- Without a 'Cargo.toml' above the file, `:Run` compiles it with `rustc` and runs it.
-- It uses edition 2024, which `cargo new` writes.
local root = vim.fs.root(0, 'Cargo.toml')
local run = require('config.run')

run.command(function(args)
  if root == nil then return run.compiled({ 'rustc', '--edition', '2024' }, args) end
  return vim.list_extend({ 'cargo', 'run' }, args), nil, root
end)

require('config.ft').undo("silent! iunmap <buffer> '")
