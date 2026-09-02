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
--
-- What this file can not tell you it has to show you: Neovim inherits the
-- environment of the shell that started it, so a program installed a minute ago
-- may still be invisible here, and a version manager may be resolving a different
-- one than a fresh terminal does. The versions below are the ones this session
-- actually sees, which is the point of reporting them.

local M = {}
local health = vim.health

-- Read the first line of `cmd` output, or `nil` if it can not be run
local function first_line(cmd)
  local ok, out = pcall(function() return vim.system(cmd):wait() end)
  if not ok or out.code ~= 0 then return nil end
  return vim.split(vim.trim(out.stdout), '\n')[1]
end

-- Report an external program: its version when present, what breaks when not
local function report(name, why, advice)
  if vim.fn.executable(name) ~= 1 then
    return health.warn('`' .. name .. '` is not available', { advice, why })
  end
  health.ok(name .. ': ' .. (first_line({ name, '--version' }) or 'found'))
end

-- External tools =============================================================
-- Programs the config uses when they are there and does without when they are
-- not. None of them is required for startup (`:h mini.nvim-general-principles`).
local function check_external_tools()
  health.start('config: external tools')

  report('git', "'mini.git' and 'mini.diff' show no data", 'Install Git')
  report(
    'rg',
    '`<Leader>ff` and `<Leader>fg` get slower',
    'Install it with `mise use -g ripgrep@latest`'
  )
  report(
    'lazygit',
    '`<Leader>tl` warns and does nothing',
    'Install it with `mise use -g lazygit@latest`'
  )
  -- Not reported by any runtime healthcheck, yet `AGENTS.md` requires
  -- `stylua --check .` to pass before a change is finished
  report(
    'stylua',
    'config formatting can not be checked',
    'Install it with `mise use -g stylua@latest`'
  )
  -- 'nvim-treesitter' shells out to this to build a parser, so a missing CLI
  -- shows up much later, as a language that stays uninstalled
  report(
    'tree-sitter',
    'no parser can be installed or updated, `:TSUpdate` included',
    'Install it with `mise use -g tree-sitter@latest`, and make sure the '
      .. "'mise' shims directory is on PATH: on Windows nothing puts it there"
  )
end

-- Language toolchains ========================================================
-- One section per language the config supports. Answer the questions asked when
-- something does not work: is the toolchain there, which version is active in
-- this session, is the language server reachable, is the parser installed.

local function check_rust()
  health.start('config: Rust')

  if vim.fn.executable('rustup') ~= 1 then
    return health.warn('`rustup` is not available', {
      'Install it from https://rustup.rs',
      "Nothing in 'after/lsp/rust_analyzer.lua' can start without a toolchain",
    })
  end

  -- Which toolchain answers here, which a project's 'rust-toolchain.toml' can
  -- change and a stale shell can pin to yesterday's
  local toolchain = first_line({ 'rustup', 'show', 'active-toolchain' })
  health.ok('active toolchain: ' .. (toolchain or 'unknown'))
  local install_toolchain = 'Install one with `rustup toolchain install stable`'
  report('rustc', 'nothing compiles', install_toolchain)
  report('cargo', '`:make check` and `:make test` do nothing', install_toolchain)

  -- Installed through `rustup` rather than `mise` on purpose: the server is
  -- built from the commit of the active toolchain, and for a language whose
  -- server ships with the compiler that alignment is what keeps them agreeing
  report(
    'rust-analyzer',
    'Rust buffers lose completion, diagnostics, rename and go to definition',
    'Install it with `rustup component add rust-analyzer rust-src`'
  )
  -- 'after/lsp/rust_analyzer.lua' sets `check.command = 'clippy'`, so without
  -- it the server reports no diagnostics at all rather than falling back
  report(
    'cargo-clippy',
    'the server is configured to check with clippy and finds nothing to run',
    'Install it with `rustup component add clippy`'
  )

  -- The parser has to be installed, not merely available. This is the same
  -- check 'plugin/40_plugins.lua' uses to decide what to install.
  -- `sql` is here because 'after/queries/rust/injections.scm' parses the SQL
  -- inside the `sqlx` macros with it, and stays inert while it is missing
  for _, lang in ipairs({ 'rust', 'toml', 'sql' }) do
    if #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) == 0 then
      health.warn('tree-sitter parser for `' .. lang .. '` is not installed', {
        "Restart Neovim once with '" .. lang .. "' in `languages`, and wait",
        'Highlighting falls back to the legacy syntax file',
      })
    else
      health.ok('tree-sitter parser `' .. lang .. '`: installed')
    end
  end
end

function M.check()
  check_external_tools()
  check_rust()
end

return M
