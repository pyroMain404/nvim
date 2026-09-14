-- ┌───────┐
-- │ ts_ls │
-- └───────┘
--
-- This file contains configuration of the TypeScript language server.
-- Source: https://github.com/typescript-language-server/typescript-language-server
-- Install: see `check_angular()` in 'lua/config/health.lua' for the exact `mise`
-- line. The server is a Node program launched through a `mise` shim, which is
-- what makes the runtime below a decision rather than an accident.
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
--
-- Nothing here describes TypeScript: `filetypes`, `root_dir`, the handlers and
-- the two commands of 'nvim-lspconfig' are already right and none of them is
-- repeated. What this file adds is the Node the server itself runs on, which is
-- not the Node the project builds with - and, because of the HACK below, the
-- one line of command that carries it.

-- The Node the *server* runs on, which is not the Node the project builds with.
--
-- A `mise` shim resolves its tools from the current directory, so a repository
-- pinning an old Node hands that one to every program started inside it, the
-- language server included. Node 14 is the ceiling of Angular 15 and the pin of
-- every PASS portal checkout, and on it this server does not start at all:
-- measured, `typescript-language-server` 6.0.0 dies while parsing its own code
-- with `SyntaxError: Unexpected token '??='` - the nullish assignment, which
-- Node gained in 15. Neovim reports none of that. The client simply never
-- attaches, on a project where nothing is wrong.
--
-- `MISE_NODE_VERSION` decouples the two for this process alone: the server
-- starts on the Node chosen here, while the same directory keeps resolving the
-- Node its build needs for `:make`, for `npx` and for every terminal - and that
-- one has to stay 14, because the project's own compiler is what runs there.
--
-- The newest installed release is the choice, rather than a version named here,
-- for the reason 'after/lsp/jdtls.lua' gives at length: the day this server
-- raises its minimum, `mise use -g node@<major>` is the whole fix.
--
-- NOTE: it has to be this variable and not `PATH` or a Node named directly. The
-- shim recomputes its own environment from the tools of its working directory
-- and overwrites what it inherited, so anything pointing at an interpreter is
-- read and then discarded - silently, which is the part that costs a day.
local function newest_node()
  local ok, out = pcall(
    function() return vim.system({ 'mise', 'ls', 'node', '--json' }):wait() end
  )
  if not ok or out.code ~= 0 then return nil end

  local decoded, entries = pcall(vim.json.decode, out.stdout)
  if not decoded or type(entries) ~= 'table' then return nil end

  -- Compared by major and not as strings, where '8.17.0' sorts above '20.20.2'
  local newest = nil
  for _, entry in ipairs(entries) do
    local major = tonumber(tostring(entry.version):match('^(%d+)'))
    if entry.installed and major ~= nil then
      local known = newest ~= nil and tonumber(newest:match('^(%d+)')) or -1
      if major > known then newest = entry.version end
    end
  end
  return newest
end

local node = newest_node()
if node == nil then
  vim.notify_once(
    'no Node is installed through `mise`, so `ts_ls` runs on whatever Node the '
      .. 'project resolves to and will not start if that one is too old: '
      .. 'install one with `mise use -g node@<major>`, and see '
      .. '`:checkhealth config`',
    vim.log.levels.WARN
  )
end

return {
  -- HACK: this whole function exists to pass one environment variable, and it
  -- is a copy of the `cmd` of 'nvim-lspconfig' with `env` added to the spawn.
  -- `cmd_env` - the field meant for exactly this - is read by `vim.lsp.start()`
  -- only when `cmd` is a **list**. When it is a function, Neovim hands it the
  -- dispatchers and steps aside, and 'nvim-lspconfig' ends it with
  -- `vim.lsp.rpc.start({ cmd, '--stdio' }, dispatchers)`, passing no
  -- `extra_spawn_params` at all: the variable is set in the merged config,
  -- reported by `:=vim.lsp.config['ts_ls']`, and never reaches the process.
  -- Measured on this project - `cmd_env` present, `MISE_NODE_VERSION` unset in
  -- the server, no client attached - which is the failure the whole file exists
  -- to prevent, wearing a different mask.
  --
  -- Still true in 'nvim-lspconfig' ac9d2f7 (2026-09-10) on Neovim v0.12.5.
  -- Delete this and go back to a plain `cmd_env` the day either the plugin
  -- forwards it or `cmd` stops being a function.
  --
  -- The preference for a `typescript-language-server` inside the project's own
  -- 'node_modules/.bin' is kept, because dropping it would be a second, silent
  -- change: it is what a monorepo pinning its own server relies on. It resolves
  -- to nothing here - the PASS portal does not carry one - and a project that
  -- does gets it launched on the same Node as the global one, which is the
  -- point.
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
}
