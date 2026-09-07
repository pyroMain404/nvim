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
--
-- NOTE: the second `trim` is what removes the carriage return of a program
-- that prints CRLF, which every Windows console tool does. Trimming the whole
-- output only reaches the last line, so a one line answer looked clean while
-- a multi line one (`java --version`, `mvn --version`) carried a `\r` into
-- the middle of the health report and broke it in two.
local function first_line(cmd)
  local ok, out = pcall(function() return vim.system(cmd):wait() end)
  if not ok or out.code ~= 0 then return nil end
  return vim.trim(vim.split(vim.trim(out.stdout), '\n')[1] or '')
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

  -- These three are ordinary system utilities: what breaks without them is a
  -- convenience, not this config, so they come from the system package manager
  report(
    'git',
    "'mini.git' and 'mini.diff' show no data",
    'Install it with `winget install Git.Git`'
  )
  report(
    'rg',
    '`<Leader>ff` and `<Leader>fg` get slower',
    'Install it with `winget install BurntSushi.ripgrep.GNU`'
  )
  report(
    'lazygit',
    '`<Leader>tl` warns and does nothing',
    'Install it with `winget install JesseDuffield.lazygit`'
  )
  -- The next two are the opposite case: without them a change to this config
  -- can not be finished or a language can not be added, so they are declared in
  -- `mise` and the advice says so.
  --
  -- Not reported by any runtime healthcheck, yet `AGENTS.md` requires
  -- `stylua --check .` to pass before a change is finished
  report(
    'stylua',
    'config formatting can not be checked, and `<Leader>lf` does nothing in Lua',
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

-- Lua is both a language this config supports and the language it is written
-- in, so this section is also what says whether the config can be worked on.
local function check_lua()
  health.start('config: Lua')

  -- 'after/lsp/lua_ls.lua' is inert without it, and `<Leader>lh`, `<Leader>lR`
  -- and `<Leader>la` report that no server supports the method
  report(
    'lua-language-server',
    'Lua buffers lose completion, diagnostics, rename and go to definition',
    'Install it with `mise use -g lua-language-server@latest`'
  )
  -- Neovim bundles this parser, so a missing one means a broken install rather
  -- than a language left uninstalled
  if #vim.api.nvim_get_runtime_file('parser/lua.*', false) == 0 then
    health.warn('tree-sitter parser for `lua` is not installed', {
      'It ships with Neovim: reinstall it, or run `:TSInstall lua`',
      'Highlighting falls back to the legacy syntax file',
    })
  else
    health.ok('tree-sitter parser `lua`: installed')
  end
end

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

local function check_angular()
  health.start('config: Angular')

  -- Everything below runs through Node, so a missing one explains all the rest
  report(
    'node',
    'neither language server starts, and `:make` has no `npx` to call',
    'Install it with `mise use -g node@20`'
  )

  -- `ngserver --version` is not a way to ask: the binary refuses to start
  -- without the `--tsProbeLocations` that 'nvim-lspconfig' computes from the
  -- project, so presence is all this can honestly report. Which major is
  -- installed matters more than that anyway, and the next check is what says it
  if vim.fn.executable('ngserver') ~= 1 then
    health.warn('`ngserver` is not available', {
      'Install it with `mise use -g npm:@angular/language-server@<major>`',
      'That global one is only the fallback: the major has to be the one of '
        .. 'the project, and a project on another major pins it in its own '
        .. 'mise.toml',
      'Templates lose completion, diagnostics and go to definition',
    })
  else
    health.ok('ngserver: ' .. vim.fn.exepath('ngserver'))
  end
  -- `angularls` answers about templates and not about TypeScript, so without
  -- this one a '.ts' buffer gets no diagnostics at all
  report(
    'typescript-language-server',
    'TypeScript buffers lose completion, diagnostics, rename and go to definition',
    'Install it with `mise use -g npm:typescript-language-server@latest`'
  )
  -- Declared in 'plugin/40_plugins.lua' for every filetype an Angular project
  -- holds, so `<Leader>lf` silently falls back to a server without it
  report(
    'prettier',
    '`<Leader>lf` falls back to a language server that formats differently',
    'Install it with `mise use -g npm:prettier@latest`'
  )

  -- `angularls` probes the project's own 'node_modules' for the Angular
  -- language service, and `:make` runs the project's own compiler through
  -- `npx`. Both fail in a checkout where nobody ran the install, and the
  -- failure looks like a broken config rather than a missing directory.
  local root = vim.fs.root(0, { 'angular.json', 'nx.json' })
  if root == nil then
    health.info('not inside an Angular project: nothing else to check here')
  elseif vim.uv.fs_stat(vim.fs.joinpath(root, 'node_modules')) == nil then
    health.warn("'" .. root .. "' has no 'node_modules'", {
      'Run `npm install` there',
      '`angularls` finds no language service to load, and `:make` no compiler',
    })
  else
    health.ok('project dependencies: installed in ' .. root)
    -- The server is one program and the language service it loads is another,
    -- taken from this project: a server newer than the project calls into an
    -- API that is not there yet. The failure is loud in ':LspLog' and silent
    -- everywhere else — the client attaches, and no diagnostic ever arrives.
    -- NOTE: the fix belongs to the project and not to the global `mise` config.
    -- Neovim starts `ngserver` through a `mise` shim, and a shim resolves the
    -- version from the current directory: a pin in the project's own mise.toml
    -- follows the checkout and is right for every project at once, while the
    -- global one can only ever be right for the major it was installed for.
    local manifest = vim.fs.joinpath(root, 'package.json')
    local ok, blob = pcall(vim.fn.readblob, manifest)
    local deps = ok and (vim.json.decode(blob) or {}).dependencies or {}
    local version = (deps['@angular/core'] or ''):match('%d+')
    if version == nil then
      health.info('no `@angular/core` in ' .. manifest)
    else
      local fix = ('mise use npm:@angular/language-server@%s'):format(version)
      health.info(
        ('project is on Angular %s, so `ngserver` has to be that major. '):format(
          version
        ) .. ('Pin it there: `%s`, run in %s'):format(fix, root)
      )
    end
  end

  -- The parser has to be installed, not merely available. `angular` is the one
  -- that reads a template; the rest are the other files a component is made of
  for _, lang in ipairs({ 'angular', 'typescript', 'html', 'css', 'scss', 'json' }) do
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

local function check_java()
  health.start('config: Java')

  -- Which JDK answers here. `mise` resolves it through its shims, so a project
  -- with its own 'mise.toml' can change the answer without changing anything
  -- in this config
  local version = first_line({ 'java', '--version' })
  if version == nil then
    return health.warn('`java` is not available', {
      'Install it with `mise use -g java@temurin-21`',
      "Nothing in 'after/lsp/jdtls.lua' can start without a JDK",
    })
  end
  health.ok('java: ' .. version .. ' (' .. vim.fn.exepath('java') .. ')')
  -- jdtls 1.61 refuses to start on anything older, and says so only in a log
  local major = tonumber(version:match('(%d+)'))
  if major ~= nil and major < 21 then
    health.warn('the JDK in this session is older than 21', {
      'Install a newer one with `mise use -g java@temurin-21`',
      'jdtls refuses to start on it, whatever the project targets',
    })
  end

  report(
    'javac',
    "`:make` does nothing in a file that belongs to no build ('compiler/javac')",
    'It comes with the JDK: `mise use -g java@temurin-21`'
  )
  report(
    'mvn',
    '`:make test` and `:make compile` do nothing in a Maven project',
    'Install it with `mise use -g maven@3.9`'
  )

  -- Presence only, on purpose: 'jdtls' has no `--version`, and its Windows
  -- wrapper ends with a `pause` that would wait for a key nobody can press.
  -- The version is the one pinned in the `mise` line below
  local install_jdtls = 'Install it with `mise use -g '
    .. '"http:jdtls[url=https://download.eclipse.org/jdtls/milestones/1.61.0/'
    .. 'jdt-language-server-1.61.0-202609031315.tar.gz,bin_path=bin]@1.61.0"`'
  if vim.fn.executable('jdtls') ~= 1 then
    health.warn('`jdtls` is not available', {
      install_jdtls,
      'Java buffers lose completion, diagnostics, rename and go to definition',
    })
  else
    health.ok('jdtls: ' .. vim.fn.exepath('jdtls'))
    -- The server is a JVM program, but what starts it is 'bin/jdtls.py'
    report(
      'python',
      'the `jdtls` launcher is a Python script and never starts the server',
      'Install it with `mise use -g python@3.12`'
    )
  end

  -- The parser has to be installed, not merely available. This is the same
  -- check 'plugin/40_plugins.lua' uses to decide what to install.
  -- `xml` is here for 'pom.xml', which a Maven project is read from as often
  -- as its sources
  for _, lang in ipairs({ 'java', 'xml' }) do
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
  check_lua()
  check_rust()
  check_angular()
  check_java()
end

return M
