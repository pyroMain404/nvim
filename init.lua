-- ┌─────────────┐
-- │ Neovim 0.12 │
-- └─────────────┘
--
-- Entry point. 'plugin/NN_*.lua' are sourced in order (options, keymaps, MINI,
-- other plugins, features); 'lua/config/' holds feature modules, 'after/' the
-- filetype and LSP overrides, 'compiler/' the `:compiler` definitions.

_G.Config = {}

local gr = vim.api.nvim_create_augroup('custom-config', { clear = true })
Config.new_autocmd = function(event, pattern, callback, desc)
  local opts = { group = gr, pattern = pattern, callback = callback, desc = desc }
  vim.api.nvim_create_autocmd(event, opts)
end

-- `vim.pack.add()` hook helper (`:h vim.pack-events`); define hooks before the first add.
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

-- `now`: needed by the first draw; `now_if_args`: only when a file is opened; `later`: the rest.
local misc = require('mini.misc')
Config.now = function(f) misc.safely('now', f) end
Config.later = function(f) misc.safely('later', f) end
Config.now_if_args = vim.fn.argc(-1) > 0 and Config.now or Config.later

vim.o.exrc = true
