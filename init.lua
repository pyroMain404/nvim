-- ┌─────────────┐
-- │ Neovim 0.12 │
-- └─────────────┘
--
-- Entry point. Neovim sources 'plugin/NN_*.lua' in order:
-- options, keymaps, MINI, other plugins, then features.
-- 'lua/config/' contains feature modules; 'after/' contains filetype and LSP overrides.
-- 'compiler/' contains the `:compiler` definitions.

_G.Config = {}

local gr = vim.api.nvim_create_augroup('custom-config', { clear = true })
Config.new_autocmd = function(event, pattern, callback, desc)
  local opts = { group = gr, pattern = pattern, callback = callback, desc = desc }
  vim.api.nvim_create_autocmd(event, opts)
end

-- This helper defines `vim.pack.add()` hooks.
-- Call it before the first add (`:h vim.pack-events`).
Config.on_packchanged = function(plugin_name, kinds, callback, desc)
  local f = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if not (name == plugin_name and vim.tbl_contains(kinds, kind)) then return end
    if not ev.data.active then vim.cmd.packadd(plugin_name) end
    callback(ev.data)
  end
  Config.new_autocmd('PackChanged', '*', f, desc)
end

vim.pack.add({ 'https://github.com/nvim-mini/mini.nvim' })

-- `now` runs the work before the first draw.
-- `now_if_args` acts as `now` when Neovim starts with file arguments. Otherwise it acts as `later`.
-- `later` runs the remaining work after the first draw.
local misc = require('mini.misc')
Config.now = function(f) misc.safely('now', f) end
Config.later = function(f) misc.safely('later', f) end
Config.now_if_args = vim.fn.argc(-1) > 0 and Config.now or Config.later

-- 'exrc' runs after this file, from the current directory upward (`:h startup`).
-- 'lua/config/project.lua' reads this directory to know which files 'exrc' ran.
vim.o.exrc = true
Config.exrc_dir = vim.fs.normalize(vim.fn.getcwd())
