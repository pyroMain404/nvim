-- ┌──────────────┐
-- │ Health check │
-- └──────────────┘
--
-- This file reports the state of what this config assumes about its environment:
-- which external programs are installed, at which version, and what stops working
-- when one of them is missing. Run it with `:checkhealth config`.
--
-- `:checkhealth` discovers any 'lua/**/health.lua' on `:h 'runtimepath'` and
-- names the check after its path, so this one is reachable as `config`. It is
-- also why this file is not `require`d from anywhere: unlike 'config/run.lua'
-- next to it, which the ftplugins ask for by name, this one is found.
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

  -- The Node of *this directory* is not the one the servers run on, and the
  -- difference is the whole point: a `mise` shim resolves from the current
  -- directory, so a project pinning an old Node hands it to every program
  -- started inside it. The files in 'after/lsp/' override that for the two
  -- servers alone (`MISE_NODE_VERSION`), which is why a project can keep the
  -- Node its build needs. Reported here because neither half is visible from
  -- inside Neovim: below the minimum the server dies on its own source and no
  -- client ever attaches, with nothing wrong in the project.
  --
  -- 18 is the floor of `typescript-language-server` 6, the older of the two
  -- requirements; `ngserver` asks for less. Measured on Node 14, the ceiling of
  -- Angular 15 and the pin of the PASS portal: `SyntaxError: Unexpected token
  -- '??='`, in a message that reaches no log Neovim reads.
  local project_node = first_line({ 'node', '--version' })
  local major = tonumber((project_node or ''):match('^v?(%d+)'))
  if project_node == nil then
    health.info('node: no version answered here, so nothing to compare')
  elseif major ~= nil and major < 18 then
    health.info(
      ('node %s in this directory, below the 18 `ts_ls` needs: the servers '):format(
        project_node
      )
        .. 'take the newest one `mise` has instead, see `after/lsp/ts_ls.lua`'
    )
  else
    health.ok('node in this directory: ' .. project_node)
  end

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
  --
  -- Searched from the buffer the reader came from, not from buffer 0 as this
  -- used to do: `:checkhealth` opens its own report buffer first and runs the
  -- checks inside it, so buffer 0 is a nameless scratch buffer and
  -- `vim.fs.root()` answers nil for it. Every run therefore said "not inside an
  -- Angular project", one started from a project included - and with it went
  -- the version check below, the one voice of this section that catches a
  -- server on the wrong major.
  --
  -- NOTE: the working directory is not the answer either, and it is the
  -- tempting one. `MiniMisc.setup_auto_root()` puts it on the root of the
  -- *repository*, while 'angular.json' can sit well below it: measured on the
  -- PASS portal, cwd is the checkout and the Angular project is four
  -- directories down, so a search upward from cwd finds nothing.
  local source = vim.fn.bufnr('#')
  if source == -1 or vim.api.nvim_buf_get_name(source) == '' then
    source = vim.fn.getcwd()
  end
  local root = vim.fs.root(source, { 'angular.json', 'nx.json' })
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

-- The oldest Java release jdtls agrees to start on, read from the launcher.
--
-- The number lives in one place and it is not this file: 'bin/jdtls.py' raises
-- `Exception: jdtls requires at least Java 21` and that string is the only
-- statement of the requirement anywhere. Writing 21 here instead would be a
-- copy that stays behind on the day the server raises its minimum - which is
-- exactly the day this check exists for, because the symptom then is a language
-- server that quietly never attaches.
--
-- `mise which` resolves the shim to the real script, whose sibling is the
-- Python it runs. Anything unexpected on the way - jdtls installed some other
-- way, the message reworded upstream - returns `nil`, and the caller reports
-- nothing rather than a number it invented.
local function jdtls_minimum_java()
  local launcher = first_line({ 'mise', 'which', 'jdtls' })
  if launcher == nil then return nil end
  local ok, lines =
    pcall(vim.fn.readfile, vim.fs.joinpath(vim.fs.dirname(launcher), 'jdtls.py'))
  if not ok then return nil end
  for _, line in ipairs(lines) do
    local minimum = line:match('requires at least Java (%d+)')
    if minimum ~= nil then return tonumber(minimum) end
  end
  return nil
end

local function check_java()
  health.start('config: Java')

  -- NOTE: the fallback is only reached when the launcher could not be read at
  -- all, which in practice means jdtls is not installed - and the check that
  -- says so is a few lines below. 21 is the minimum of jdtls 1.61, kept here
  -- because advice with a placeholder in it is advice nobody can run.
  local minimum = jdtls_minimum_java()
  local install_jdk = ('Install one with `mise install java@temurin-%s`'):format(
    minimum or 21
  )

  -- Which JDK answers here. `mise` resolves it through its shims, so a project
  -- with its own 'mise.toml' can change the answer without changing anything
  -- in this config. This is the JDK of the *project*: `:make`, `javac` and the
  -- build use it, and it is expected to be whatever that project targets — 8 or
  -- 11 are normal answers and not a problem
  local version = first_line({ 'java', '--version' })
  if version == nil then
    return health.warn('`java` is not available', {
      install_jdk .. " and pin the project one in its 'mise.toml'",
      "Nothing in 'after/lsp/jdtls.lua' can start without a JDK",
    })
  end
  health.ok('java: ' .. version .. ' (' .. vim.fn.exepath('java') .. ')')

  -- The JDK jdtls runs on, which is *not* the one above: 'after/lsp/jdtls.lua'
  -- hands the server the newest JDK `mise` has installed, through
  -- `MISE_JAVA_VERSION`, so that it starts in a project pinned to an older
  -- toolchain. What has to hold here is that such a JDK exists and is new
  -- enough, not that it is the active one — checking the session JDK instead
  -- would report a healthy Java 11 project as broken.
  --
  -- Read from the resolved config rather than named here. Which version the
  -- server gets is a decision of that file, and a second copy of it in this one
  -- would keep answering after the decision changed.
  --
  -- NOTE: below the minimum, jdtls says so only in its own log and nothing at
  -- all in Neovim, so an unmet requirement looks like a language server that
  -- simply does not attach. That is what makes it worth checking here.
  local jdtls_config = vim.lsp.config['jdtls'] or {}
  local server_jdk = vim.tbl_get(jdtls_config, 'cmd_env', 'MISE_JAVA_VERSION')
  if server_jdk == nil then
    health.warn('jdtls has no JDK of its own', {
      install_jdk,
      'It falls back to the JDK of the project, and a project on an older '
        .. 'release then leaves no client attached',
    })
  else
    -- Always a `mise` version string ('temurin-21.0.12+101.0.LTS'), never the
    -- legacy '1.8' spelling an Eclipse compliance level can carry, so the
    -- release is the first number after the vendor name
    local release = tonumber(server_jdk:gsub('^%D+', ''):match('^%d+'))
    if minimum ~= nil and release ~= nil and release < minimum then
      health.warn(
        ('jdtls needs Java %d and the newest one installed is %d'):format(
          minimum,
          release
        ),
        {
          ('Install it with `mise install java@temurin-%d`'):format(minimum),
          'Until then the server refuses to start and no client attaches to a '
            .. 'Java buffer',
        }
      )
    else
      health.ok(
        ('jdtls JDK: %s%s'):format(
          server_jdk,
          minimum ~= nil and (', minimum required is %d'):format(minimum) or ''
        )
      )
    end
  end

  report(
    'javac',
    "`:make` does nothing in a file that belongs to no build ('compiler/javac')",
    'It comes with the JDK, whichever release the project targets'
  )
  report(
    'mvn',
    '`:make test` and `:make compile` do nothing in a Maven project',
    'Install it with `mise use -g maven@3.9`'
  )

  -- Not programs this config runs, but directories it hands over: the execution
  -- environments 'after/lsp/jdtls.lua' declares, so that a project targeting a
  -- release other than the server's own is checked against the class library it
  -- is really compiled with.
  --
  -- Read from the resolved config rather than from a list kept here. The two
  -- lists used to be written twice and had to agree; asking the config is the
  -- only version of this check that cannot drift away from what the server is
  -- actually told.
  local declared = vim.tbl_get(
    jdtls_config,
    'settings',
    'java',
    'configuration',
    'runtimes'
  ) or {}
  if #declared == 0 then
    health.warn('jdtls is told about no JDK at all', {
      'Install one with `mise install java@temurin-<major>` — never `mise use -g`',
      'Every project is then checked against the class library of the JDK the '
        .. 'server runs on, which accepts calls that its build then rejects',
    })
  else
    for _, runtime in ipairs(declared) do
      health.ok(runtime.name .. ' runtime for jdtls: ' .. runtime.path)
    end
    -- Not a warning, because a release missing from this list is only a problem
    -- for a project that targets it, and this list says nothing about which
    -- projects exist. That case is caught where it can be: 'after/lsp/jdtls.lua'
    -- asks the server what the project it just imported compiles against, and
    -- warns when no runtime here answers for it.
    health.info(
      'A project on a release missing from this list is checked against the '
        .. "server's own JDK, and says so when it is opened"
    )
  end

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

local function check_cpp()
  health.start('config: C++')

  -- One LLVM install gives the server, the compiler, the formatter and the
  -- linter at the same version: that is why it comes from WinGet and not from
  -- `mise`, the same reason `rust-analyzer` comes from `rustup`. Hence one
  -- piece of advice for the four of them.
  local install_llvm = 'Install it with `winget install LLVM.LLVM`'
  report(
    'clangd',
    'C and C++ buffers lose completion, diagnostics, rename and go to definition',
    install_llvm
  )
  report('clang++', 'nothing compiles', install_llvm)
  report(
    'clang-format',
    '`<Leader>lf` falls back to a server that formats differently',
    install_llvm
  )
  -- 'after/lsp/clangd.lua' passes `--clang-tidy`: without the binary the
  -- server does not fail, it simply produces none of those diagnostics.
  --
  -- Reported by path and not by version, unlike the three above: the first
  -- line of `clang-tidy --version` is the LLVM banner - measured, it reads
  -- `LLVM (http://llvm.org/):` and the number is on the line after - and the
  -- version is the one of the install above anyway, which is the whole point
  -- of taking the four from one release.
  if vim.fn.executable('clang-tidy') ~= 1 then
    health.warn('`clang-tidy` is not available', {
      install_llvm,
      'the server is configured to lint with clang-tidy and finds nothing to run',
    })
  else
    health.ok('clang-tidy: ' .. vim.fn.exepath('clang-tidy'))
  end

  report(
    'cmake',
    "`:make` has nothing to run ('compiler/cmake.lua')",
    'Install it with `mise use -g cmake@4`'
  )
  report(
    'ninja',
    'CMake falls back to a slower generator',
    'Install it with `mise use -g ninja@1.13`'
  )

  -- The check that matters more than all the others: is there a compilation
  -- database for the project this reader came from?
  --
  -- Without one clangd does not fail, it GUESSES: it attaches, answers, and
  -- fills the buffer with errors about perfectly valid `#include`s, because it
  -- assumes the file is built as `clang some_file.cc` and knows none of the
  -- include paths of the project. It is the most common failure of C++ in an
  -- editor and it is indistinguishable from a broken config while nobody names
  -- it.
  --
  -- Searched from the alternate buffer for the reason spelled out in
  -- `check_angular()`: `:checkhealth` runs inside its own report buffer, so
  -- buffer 0 is a nameless scratch one and `vim.fs.root()` answers nil for it.
  local source = vim.fn.bufnr('#')
  if source == -1 or vim.api.nvim_buf_get_name(source) == '' then
    source = vim.fn.getcwd()
  end
  local root = vim.fs.root(source, {
    'CMakeLists.txt',
    'compile_commands.json',
    'compile_flags.txt',
    'Makefile',
  })
  if root == nil then
    health.info('not inside a C or C++ project: nothing else to check here')
  else
    -- Where clangd looks: the parent directories of the file and, in each of
    -- them, a 'build/' subdirectory (documented at
    -- https://clangd.llvm.org/installation#compile_commandsjson). That second
    -- half is what makes a CMake project work with no extra step, because
    -- `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` writes the file into the build
    -- directory and not at the root - measured with the Ninja generator, which
    -- puts it in 'build/compile_commands.json'. A build directory named
    -- anything else is out of reach and has to be linked or copied to the
    -- root.
    local database = nil
    for _, path in ipairs({
      vim.fs.joinpath(root, 'compile_commands.json'),
      vim.fs.joinpath(root, 'build', 'compile_commands.json'),
      -- The hand written alternative, for a project simple enough that every
      -- file takes the same flags. Background indexing does not work with it,
      -- so it is reported as what it is.
      vim.fs.joinpath(root, 'compile_flags.txt'),
    }) do
      if vim.uv.fs_stat(path) ~= nil then database = path end
    end
    -- TODO: the advice below names one build system, and a GDExtension
    -- checkout may not be able to run it: 'godot-cpp' is historically built
    -- with SCons (`scons compiledb=yes` writes the database), while recent
    -- versions also ship a 'CMakeLists.txt'. A reader there is told to run a
    -- command that may not apply, which is worse than silence because it
    -- reads as authoritative.
    -- Not now: there is no GDExtension project on this machine, so which of
    -- the two that checkout actually uses would be a guess, and an advice
    -- derived from a guess is the thing this branch exists to avoid.
    -- First step, on the first real one: look for 'SConstruct' and
    -- 'CMakeLists.txt' at its root before writing a line. Both or CMake only,
    -- nothing to do here. SConstruct only, this branch grows a case that
    -- names `scons compiledb=yes` instead.
    if database == nil then
      health.warn(("no compilation database for '%s'"):format(root), {
        'Generate one with `cmake -S . -B build -G Ninja '
          .. '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`, run at that root',
        'For a build directory not named `build`, link or copy its '
          .. "'compile_commands.json' to the root, or name it in the project's "
          .. "'.clangd' (`CompileFlags: CompilationDatabase: <dir>`)",
        'clangd does not fail without one: it assumes `clang <file>` at the '
          .. 'newest standard, so it reports errors on valid includes of the '
          .. 'project and accepts code the build then rejects',
      })
    else
      -- Which C++ standard this project is written in, read where clangd reads
      -- it: the flags of a translation unit. It is reported because nothing
      -- else says it - a buffer looks the same whether the server checks it
      -- against C++11 or C++23 - and because a database generated before
      -- `CMAKE_CXX_STANDARD` was raised keeps answering the old one.
      -- Only the head of the file: one entry is a kilobyte at most, and the
      -- database of a real project is megabytes (`:h readblob()` takes an
      -- offset and a size for exactly this)
      local standard = nil
      local ok, blob = pcall(vim.fn.readblob, database, 0, 8192)
      if ok then standard = tostring(blob):match('%-std=[%w%+]+') end
      health.ok(
        'compilation database: '
          .. database
          .. (standard and (' (' .. standard .. ')') or '')
      )
    end
  end

  -- The parser has to be installed, not merely available. This is the same
  -- check 'plugin/40_plugins.lua' uses to decide what to install. `c` is there
  -- because the `cpp` parser requires it, `cmake` and `make` because the files
  -- a project is built from are read as often as its sources
  for _, lang in ipairs({ 'cpp', 'c', 'cmake', 'make' }) do
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

-- Godot is the only section that reports on nothing when it does not apply, and
-- the reason is that its whole toolchain is a game's, not the machine's: a
-- section saying "no Godot project here" is not a check, it is noise in every
-- other report.
--
-- Searched from the buffer the reader came from and not from buffer 0, for the
-- reason `check_angular()` documents above: `:checkhealth` runs inside its own
-- nameless report buffer, so `vim.fs.root(0, …)` answers nil for every run.
local function check_godot()
  local source = vim.fn.bufnr('#')
  if source == -1 or vim.api.nvim_buf_get_name(source) == '' then
    source = vim.fn.getcwd()
  end
  local root = vim.fs.root(source, { 'project.godot' })
  if root == nil then return end

  health.start('config: Godot')
  health.ok('Godot project: ' .. root)

  -- The engine is the prerequisite of everything else here: it holds the
  -- language server, and it is what `:make` calls. Two failures, not one, and
  -- the second is the one `vim.fn.executable()` alone would call healthy - a
  -- `mise` shim exists on PATH whatever version it does or does not resolve,
  -- and a directory that declares none answers `No version is set for shim`
  -- while everything keeps looking installed
  if vim.fn.executable('godot') ~= 1 then
    health.warn('`godot` is not available', {
      'Install it with `mise use -g godot@4`',
      'No engine means no language server, and `:make` has nothing to call',
    })
  else
    local version = first_line({ 'godot', '--version' })
    if version == nil then
      health.warn('`godot` is on PATH but answers no version in this directory', {
        ('Declare one for the game: `mise use godot@4`, run in %s'):format(root),
        'A `mise` shim resolves the version from the current directory, so it '
          .. 'exists and refuses to run where no mise.toml names the engine',
      })
    else
      health.ok('godot: ' .. version)
    end
  end

  -- Declared in 'plugin/40_plugins.lua' for `gdscript`. Without it `<Leader>lf`
  -- falls through to `lsp_format`, and the Godot server does not format at all
  report(
    'gdformat',
    '`<Leader>lf` and `<Leader>lF` have nothing to call in a GDScript buffer',
    'Install it with `mise use -g pipx:gdtoolkit@4.5.0`'
  )

  -- The port is a machine resource and not a project one, which is the failure
  -- worth naming here: a second Godot opened on another game gets NO port at
  -- all - it does not fall back to another one - so a buffer of this project
  -- attaches to the first editor and answers with the symbols of the other
  -- game, silently. Reported, never tested: connecting would turn "the editor
  -- is closed", which is a legitimate choice, into a failure of the user's
  local port = vim.env.GDScript_Port
  if port == nil then
    health.info(
      'the language server is the Godot editor itself, on 127.0.0.1:6005 - no '
        .. 'client at all means it is closed, and only the semantics are gone. '
        .. 'A second game opened at the same time needs `godot --lsp-port` and '
        .. "a matching `GDScript_Port` in its own '.nvim.lua'"
    )
  else
    health.info(
      ('GDScript_Port is %s, so this project expects a Godot started with '):format(
        port
      ) .. ('`--lsp-port %s` rather than the default 6005'):format(port)
    )
  end

  -- The parser has to be installed, not merely available. This is the same
  -- check 'plugin/40_plugins.lua' uses to decide what to install. `gdshader`
  -- also carries the `gdshaderinc` filetype that 'ftdetect/godot.lua' assigns,
  -- and `godot_resource` is what reads a '.tscn' or a '.tres'
  for _, lang in ipairs({ 'gdscript', 'gdshader', 'godot_resource' }) do
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
  check_cpp()
  check_godot()
end

return M
