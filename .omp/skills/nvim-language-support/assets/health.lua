-- ┌──────────────┐
-- │ Health check │
-- └──────────────┘
--
-- This file reports the state of what this config assumes about its environment.
-- It shows which external programs are installed, their versions,
-- and which features stop working when one is missing.
-- Run this check with `:checkhealth config`.
--
-- `:checkhealth` finds each 'lua/**/health.lua' on `:h 'runtimepath'`.
-- It names each check after its path, so this check is reachable as `config`.
-- Other modules also live under 'lua/', for example `lua/config/run.lua` and `lua/config/mise.lua`.
-- Callers require them by name, and `:checkhealth` does not find them by path.
-- The rule in "Where a change goes" in 'AGENTS.md' determines the type of each new module.
--
-- Use one `check_*()` function for each area.
-- Call these functions from `M.check()` in reading order.
-- Neovim uses this structure in '$VIMRUNTIME/lua/vim/health/health.lua'.
--
-- Keep these rules when you add a section (see `:h health-dev`):
-- - Start with `health.start()`.
-- - Return before `health.start()` if the check does not apply.
-- - Always give `warn()` and `error()` a second argument with advice.
--   A warning without a command to run sends the reader elsewhere.
-- - End a section that found no problem with `health.ok()`, never with silence.
-- - Report the version, not only the presence, because an outdated tool fails
--   in more confusing ways than a missing tool.

local M = {}
local health = vim.health

-- Return the first line of `cmd` output, or `nil` if the command cannot run.
local function first_line(cmd)
  local ok, out = pcall(function() return vim.system(cmd):wait() end)
  if not ok or out.code ~= 0 then return nil end
  return vim.trim(vim.split(vim.trim(out.stdout), '\n')[1] or '')
end

-- Report the program version, or the feature that fails without the program.
-- Use this function for every executable check in this file.
-- Add language tools with `report('<tool>', '<what breaks>', '<fix>')` instead of separate checks.
local function report(name, why, advice)
  if vim.fn.executable(name) ~= 1 then
    health.warn('`' .. name .. '` is not available', { advice, why })
    return nil
  end
  local version = first_line({ name, '--version' }) or 'found'
  health.ok(name .. ': ' .. version)
  return version
end

-- Check that each language in `langs` has an installed tree-sitter parser, not only an available parser.
-- 'plugin/40_plugins.lua' uses the same check to select parsers for installation.
-- `advice` takes a language name and returns a correction.
-- Omit `advice` to use the default ("restart with `<lang>` in `languages`").
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
-- Use one section for each supported language.
-- Each section answers the questions that a user asks when something does not work.
-- Is the toolchain present?
-- Which version is active in this session?
-- Can Neovim reach the language server?
-- Is the parser installed?
--
-- Neovim uses the environment of the shell that starts it.
-- The active toolchain can differ from the toolchain in a new terminal.
-- This check identifies the toolchain that this session uses.
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
