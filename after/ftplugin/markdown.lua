-- ┌─────────────────────────┐
-- │ Markdown buffer config  │
-- └─────────────────────────┘
--
-- Window options and link lookup; modes live in 'lua/config/markdown.lua'.

vim.wo[0][0].spell = true
vim.wo[0][0].wrap = true
require('config.ft').ts_fold()

-- Follow a `[label](target)` link from its label too; 'lua/config/mdlink.lua'.
vim.bo.includeexpr = "v:lua.require'config.mdlink'.target(v:fname)"

-- Disable built-in `gO` mapping in favor of 'mini.basics'
pcall(vim.keymap.del, 'n', 'gO', { buf = 0 })

require('config.markdown').attach(0)

-- `:lua` consumes the remainder of its source, so it has to be the final command.
require('config.ft').undo(
  'setlocal spell< wrap< includeexpr<',
  'unlet! b:minisurround_config',
  "lua require('config.markdown').detach()"
)
