-- ┌────────────────┐
-- │ Rust behaviour │
-- └────────────────┘
--
-- On top of '$VIMRUNTIME/ftplugin/rust.vim': a lifetime-safe quote and `:Run`.

-- 'mini.pairs' pairs `'`, which misfires on lifetimes; mapping the key to itself
-- undoes it per buffer (`:h MiniPairs.unmap_buf()`).
vim.keymap.set('i', "'", "'", { buf = 0, desc = 'Insert a plain quote' })

-- `:Run` per 'lua/config/run.lua'; cargo refuses loudly when it cannot pick a binary.
local root = vim.fs.root(0, 'Cargo.toml')

require('config.run').command(
  function(args) return vim.list_extend({ 'cargo', 'run' }, args), nil, root end
)

require('config.ft').undo("silent! iunmap <buffer> '")
