-- ┌─────────────────────────┐
-- │ Filetype config example │
-- └─────────────────────────┘
--
-- This is an example of a configuration that will apply only to a particular
-- filetype, which is the same as file's basename ('markdown' in this example;
-- which is for '*.md' files).
--
-- It can contain any code which will be usually executed when the file is opened
-- (strictly speaking, on every 'filetype' option value change to target value).
-- Usually it needs to define buffer/window local options and variables.
-- So instead of `vim.o` to set options, use `vim.bo` for buffer-local options and
-- `vim.wo[0][0]` for window-local options (`:h vim.wo`).
--
-- This is also a good place to set buffer-local 'mini.nvim' variables.
-- See `:h mini.nvim-buffer-local-config` and `:h mini.nvim-disabling-recipes`.

-- Enable spelling and wrap for window. Both are window-local options.
vim.wo[0][0].spell = true
vim.wo[0][0].wrap = true

-- Fold with tree-sitter. `foldmethod` and `foldexpr` are window-local; the
-- second index keeps the value tied to this buffer inside this window.
vim.wo[0][0].foldmethod = 'expr'
vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'

-- Disable built-in `gO` mapping in favor of 'mini.basics'
vim.keymap.del('n', 'gO', { buf = 0 })

-- Set markdown-specific surrounding in 'mini.surround'
vim.b.minisurround_config = {
  custom_surroundings = {
    -- Markdown link. Common usage:
    -- `saiwL` + [type/paste link] + <CR> - add link
    -- `sdL` - delete link
    -- `srLL` + [type/paste link] + <CR> - replace link
    L = {
      input = { '%[().-()%]%(.-%)' },
      output = function()
        local link = require('mini.surround').user_input('Link: ')
        return { left = '[', right = '](' .. link .. ')' }
      end,
    },
  },
}

-- Undo what this file sets when the filetype changes away from `markdown`
-- (`:h b:undo_ftplugin`). The `gO` deletion above removes a buffer-local
-- override that only ever existed for this filetype, so there is nothing to
-- restore for it.
vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n'
  .. table.concat({
    'setlocal spell< wrap< foldmethod< foldexpr<',
    'lua vim.b.minisurround_config = nil',
  }, ' | ')
