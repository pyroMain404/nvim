-- ┌──────────────┐
-- │ Health check │
-- └──────────────┘
--
-- This file reports the state of what this config assumes about its environment:
-- which external programs are installed, at which version, and what stops working
-- when one of them is missing. Run it with `:checkhealth config`.
--
-- It is the only file under 'lua/' in this config. `:checkhealth` discovers any
-- 'lua/**/health.lua' on `:h 'runtimepath'` and names the check after its path,
-- so this one is reachable as `config`.
--
-- Structure: one `check_*()` function per area, called from `M.check()` in the
-- order they should be read. This is the shape every healthcheck in Neovim's own
-- runtime uses (see '$VIMRUNTIME/lua/vim/health/health.lua').
--
-- Conventions to keep when adding a section (see `:h health-dev`):
-- - Open with `health.start()`; return before it if the check does not apply.
-- - Always pass advice to `warn()` and `error()`: the second argument says how
--   to fix it. A warning without a command to run sends the reader elsewhere.
-- - Close a section that found nothing wrong with `health.ok()`, never silence.
-- - Report the version, not only the presence: an outdated tool fails in more
--   confusing ways than a missing one.

local M = {}
local health = vim.health

-- Read the first line of `cmd` output, or `nil` if it can not be run
local function first_line(cmd)
  local ok, out = pcall(function() return vim.system(cmd):wait() end)
  if not ok or out.code ~= 0 then return nil end
  return vim.split(vim.trim(out.stdout), '\n')[1]
end

-- External tools =============================================================
-- Programs the config uses when they are there and does without when they are
-- not. None of them is required for startup (`:h mini.nvim-general-principles`).
local function check_external_tools()
  health.start('config: external tools')

  local tools = {
    { name = 'git', why = "'mini.git' and 'mini.diff' show no data" },
    { name = 'rg', why = '`<Leader>ff` and `<Leader>fg` get slower' },
    { name = 'lazygit', why = '`<Leader>tl` warns and does nothing' },
    -- Not reported by any runtime healthcheck, yet `AGENTS.md` requires
    -- `stylua --check .` to pass before a change is finished
    { name = 'stylua', why = 'config formatting can not be checked' },
  }

  for _, tool in ipairs(tools) do
    if vim.fn.executable(tool.name) ~= 1 then
      health.warn('`' .. tool.name .. '` is not available', tool.why)
    else
      local version = first_line({ tool.name, '--version' }) or 'found'
      health.ok(tool.name .. ': ' .. version)
    end
  end
end

-- Language toolchains ========================================================
-- One section per language the config supports. Answer the questions asked when
-- something does not work: is the toolchain there, which version is active in
-- this session, is the language server reachable, is the parser installed.
--
-- Neovim inherits the environment of the shell that started it, so the active
-- toolchain can differ from the one the user sees in a fresh terminal. Saying
-- which one is in use here is the point of the check.
--
-- Copy this function per language and call it from `M.check()`.
local function check_lang()
  health.start('config: <lang>')

  if vim.fn.executable('<tool>') ~= 1 then
    return health.warn('`<tool>` is not available', {
      'Install it with `mise use -g <tool>@latest`',
      '<what stops working without it>',
    })
  end
  health.ok('<tool>: ' .. (first_line({ '<tool>', '--version' }) or 'found'))

  -- The tree-sitter parser has to be installed, not just available. This is the
  -- same check 'plugin/40_plugins.lua' uses to decide what to install.
  if #vim.api.nvim_get_runtime_file('parser/<lang>.*', false) == 0 then
    health.warn('tree-sitter parser for `<lang>` is not installed', {
      "Add '<lang>' to `languages` in 'plugin/40_plugins.lua' and restart",
      'Highlighting falls back to the legacy syntax file',
    })
  else
    health.ok('tree-sitter parser: installed')
  end
end

function M.check()
  check_external_tools()
  check_lang()
end

return M
