-- ┌───────┐
-- │ ts_ls │
-- └───────┘

local mise = require('config.mise')

-- A Node too old for the server, pinned by a project, kills it silently through the
-- `mise` shim; `MISE_NODE_VERSION` points this process alone at the newest Node.
-- NOTE: not `PATH`: the shim recomputes its environment from the working directory.
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

-- `typescript` fallback for a plain `.ts` outside any Node project.
-- NOTE: TypeScript 7 drops `tsserver.js`, so require that file and skip such an install.
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
  -- HACK: copy of the `cmd` of 'nvim-lspconfig' with `env` added, because
  -- `cmd_env` is read by `vim.lsp.start()` only when `cmd` is a list, and the
  -- plugin's `cmd` function passes no `extra_spawn_params`: the variable shows
  -- in `:=vim.lsp.config['ts_ls']` and never reaches the process.
  -- Still true in 'nvim-lspconfig' 993d048 (2026-11-09) on Neovim v0.12.6.
  -- Delete it the day the plugin forwards `cmd_env` or `cmd` stops being a function.
  --
  -- NOTE: `vim.tbl_deep_extend('force')` merges tables but replaces functions,
  -- so this `cmd` replaces the one of 'nvim-lspconfig' (and 'after/lsp/jdtls.lua'
  -- leaves `cmd` out for the same reason).
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
