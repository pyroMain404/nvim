-- ┌─────────────────────────┐
-- │ Markdown buffer config  │
-- └─────────────────────────┘
--
-- This file sets window options and link lookup.

vim.wo[0][0].spell = true
vim.wo[0][0].wrap = true
require('config.ft').ts_fold()

vim.bo.includeexpr = "v:lua.require'config.mdlink'.target(v:fname)"

-- Disable the built-in `gO` mapping to use 'mini.basics'.
pcall(vim.keymap.del, 'n', 'gO', { buf = 0 })

require('config.markdown').attach(0)

-- Keep `:lua` last because it consumes the rest of its source.
require('config.ft').undo(
  'setlocal spell< wrap< includeexpr<',
  'unlet! b:minisurround_config',
  "lua require('config.markdown').detach()"
)
