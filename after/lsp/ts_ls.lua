-- ┌───────┐
-- │ ts_ls │
-- └───────┘

local mise = require('config.mise')

-- A project can pin a Node version that is too old for the server.
-- The `mise` shim then stops the server silently.
-- `MISE_NODE_VERSION` selects the newest Node for this process only.
-- NOTE: The code sets no `PATH`, because the shim recalculates its environment from the working directory.
local node_entry = mise.newest(
  'node',
  function(entry) return tonumber(tostring(entry.version):match('^(%d+)')) ~= nil end
)
local node = node_entry and node_entry.version or nil

if node == nil then
  vim.notify_once(
    'no Node is installed through `mise`, so `ts_ls` runs on whatever Node the '
      .. 'project resolves to and will not start if that one is too old: '
      .. 'install one with `mise use -g node@<major>`, and see '
      .. '`:checkhealth config`',
    vim.log.levels.WARN
  )
end

-- This supplies a `typescript` fallback for a plain `.ts` outside a Node project.
-- NOTE: TypeScript 7 removes `tsserver.js`, so the code checks that this file exists
-- and skips such an installation.
local function lib_of(entry)
  return vim.fs.joinpath(entry.path, 'node_modules', 'typescript', 'lib')
end
local ts_entry = mise.newest(
  'npm:typescript',
  function(entry)
    return vim.fn.filereadable(vim.fs.joinpath(lib_of(entry), 'tsserver.js')) == 1
  end
)
local tsserver_fallback = ts_entry and lib_of(ts_entry) or nil

return {
  -- HACK: This is a copy of the `cmd` of 'nvim-lspconfig' with `env` added.
  -- `vim.lsp.start()` reads `cmd_env` only when `cmd` is a list.
  -- The plugin's `cmd` function passes no `extra_spawn_params`.
  -- Thus, the variable appears in `:=vim.lsp.config['ts_ls']` but never reaches the process.
  -- The problem exists on Neovim v0.12.6.
  --
  -- Delete this copy when the plugin forwards `cmd_env`.
  -- Delete it too when `cmd` stops being a function
  -- (nvim-lspconfig 993d048, locked 2026-11-09, not retested).
  --
  -- NOTE: `vim.tbl_deep_extend('force')` merges tables but replaces functions.
  -- Thus, this `cmd` replaces the function from 'nvim-lspconfig'.
  -- 'after/lsp/jdtls.lua' omits `cmd` for the same reason.
  cmd = function(dispatchers, config)
    local cmd = 'typescript-language-server'
    local root = (config or {}).root_dir
    if root ~= nil then
      local local_cmd = vim.fs.joinpath(root, 'node_modules/.bin', cmd)
      if vim.fn.executable(local_cmd) == 1 then cmd = local_cmd end
    end
    local env = node ~= nil and { MISE_NODE_VERSION = node } or nil
    return vim.lsp.rpc.start({ cmd, '--stdio' }, dispatchers, { env = env })
  end,
  init_options = tsserver_fallback ~= nil and {
    tsserver = { fallbackPath = tsserver_fallback },
  } or nil,
}
