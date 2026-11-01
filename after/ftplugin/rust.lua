-- ┌────────────────┐
-- │ Rust behaviour │
-- └────────────────┘
--
-- On top of '$VIMRUNTIME/ftplugin/rust.vim': a lifetime-safe quote and `:Run`.

-- 'mini.pairs' pairs `'`, which misfires on lifetimes; mapping the key to itself
-- undoes it per buffer (`:h MiniPairs.unmap_buf()`).
vim.keymap.set('i', "'", "'", { buf = 0, desc = 'Insert a plain quote' })

-- `:Run` per 'lua/config/run.lua'; cargo refuses loudly when it cannot pick a
-- binary. A file with no 'Cargo.toml' above it is compiled with `rustc` (edition
-- 2024, what `cargo new` writes) and run.
local root = vim.fs.root(0, 'Cargo.toml')
local run = require('config.run')

run.command(function(args)
  if root == nil then return run.compiled({ 'rustc', '--edition', '2024' }, args) end
  return vim.list_extend({ 'cargo', 'run' }, args), nil, root
end)

require('config.ft').undo("silent! iunmap <buffer> '")
