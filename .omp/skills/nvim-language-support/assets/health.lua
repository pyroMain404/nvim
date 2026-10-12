-- ┌──────────────┐
-- │ Health check │
-- └──────────────┘
--
-- This file reports the state of what this config assumes about its environment:
-- which external programs are installed, at which version, and what stops working
-- when one of them is missing. Run it with `:checkhealth config`.
--
-- `:checkhealth` discovers any 'lua/**/health.lua' on `:h 'runtimepath'` and names
-- the check after its path, so this one is reachable as `config`. It is not the
-- only file under 'lua/': `lua/config/run.lua` and `lua/config/mise.lua` also live
-- there, required by name rather than found by path - see `language-declaration.md`
-- for the test that decides which of the two a new module belongs to.
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

-- Read the first line of `cmd` output, or `nil` if it can not be run.
local function first_line(cmd)
  local ok, out = pcall(function() return vim.system(cmd):wait() end)
  if not ok or out.code ~= 0 then return nil end
  return vim.trim(vim.split(vim.trim(out.stdout), '\n')[1] or '')
end

-- Report an external program: its version when present, what breaks when not.
-- Every executable check in this file goes through this one function, so a
-- new language's tools read `report('<tool>', '<what breaks>', '<fix>')`
-- rather than hand-rolling the executable/version/warn dance again.
local function report(name, why, advice)
  if vim.fn.executable(name) ~= 1 then
    health.warn('`' .. name .. '` is not available', { advice, why })
    return nil
  end
  local version = first_line({ name, '--version' }) or 'found'
  health.ok(name .. ': ' .. version)
  return version
end

-- Whether each of `langs` has an installed tree-sitter parser, not merely
-- available - the same check 'plugin/40_plugins.lua' uses to decide what to
-- install. `advice` is a function of the language name giving the fix line;
-- omit it to use the default ("restart with `<lang>` in `languages`").
local function check_parsers(langs, advice)
  advice = advice
    or function(lang)
      return "Restart Neovim once with '" .. lang .. "' in `languages`, and wait"
    end
  for _, lang in ipairs(langs) do
    if #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) == 0 then
      health.warn('tree-sitter parser for `' .. lang .. '` is not installed', {
        advice(lang),
        'Highlighting falls back to the legacy syntax file',
      })
    else
      health.ok('tree-sitter parser `' .. lang .. '`: installed')
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

  report(
    '<tool>',
    '<what stops working without it>',
    'Install it with `mise use -g <tool>@latest`'
  )

  check_parsers({ '<lang>' })
end

function M.check()
  check_lang()
end

return M
