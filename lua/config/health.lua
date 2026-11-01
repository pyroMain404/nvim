-- ┌──────────────┐
-- │ Health check │
-- └──────────────┘
--
-- Reports what this config assumes about its environment: which programs are
-- installed, at which version, and what stops working without them. Run it with
-- `:checkhealth config` (`:h health-dev`); found by path, never `require`d.

local M = {}
local health = vim.health
local toolchain = require('config.toolchain')

-- NOTE: the second `trim` removes the carriage return a Windows console tool
-- prints, which the first only reaches on the last line of a multi line answer
-- (`java --version`).
local function first_line(cmd)
  local ok, out = pcall(function() return vim.system(cmd):wait() end)
  if not ok or out.code ~= 0 then return nil end
  return vim.trim(vim.split(vim.trim(out.stdout), '\n')[1] or '')
end

-- Report a `toolchain` program: its version, or its path with `check = 'path'`.
-- A program on `PATH` whose `--version` fails (`rustc.exe` left behind by a
-- dropped rustup component) warns instead of reporting a healthy version-less `OK`.
local function check_tool(tool)
  local name = tool.exe
  local advice = vim.iter({ tool.advice, tool.why }):flatten():totable()
  if vim.fn.executable(name) ~= 1 then
    health.warn('`' .. name .. '` is not available', advice)
    return nil
  end
  if tool.check == 'path' then
    local path = vim.fn.exepath(name)
    health.ok(name .. ': ' .. path)
    return path
  end
  local version =
    first_line(vim.list_extend({ name }, tool.version or { '--version' }))
  if version == nil then
    health.warn('`' .. name .. '` is on PATH but its version command failed', advice)
    return nil
  end
  health.ok(name .. ': ' .. version)
  return version
end

local function find_tool(language, exe)
  return vim.iter(language.tools):find(function(tool) return tool.exe == exe end)
end

-- Whether each parser of `language` is installed, the same check
-- 'plugin/40_plugins.lua' uses to decide what to install.
local function check_parsers(language)
  for _, lang in ipairs(language.parsers) do
    if #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) == 0 then
      local fix = "Restart Neovim once with '"
        .. lang
        .. "' in `languages`, and wait"
      if language.bundled then
        fix = 'It ships with Neovim: reinstall it, or run `:TSInstall '
          .. lang
          .. '`'
      end
      health.warn('tree-sitter parser for `' .. lang .. '` is not installed', {
        fix,
        'Highlighting falls back to the legacy syntax file',
      })
    else
      health.ok('tree-sitter parser `' .. lang .. '`: installed')
    end
  end
end

-- NOTE: `:checkhealth` runs every check inside its own nameless report buffer,
-- so the search starts from the buffer the reader came from (`#`), or from the
-- working directory when there is none.
local function source_root(markers)
  local source = vim.fn.bufnr('#')
  if source == -1 or vim.api.nvim_buf_get_name(source) == '' then
    source = vim.fn.getcwd()
  end
  return vim.fs.root(source, markers)
end

-- External tools =============================================================

local function check_external_tools()
  health.start('config: external tools')
  for _, tool in ipairs(toolchain.external) do
    check_tool(tool)
  end
end

-- Language toolchains ========================================================
-- The generic part of every section is in `check_language()`. What is specific
-- to one language is in the `sections` table at the end of this block: `gate`
-- (return before `start()` when the check does not apply), `begin`, `hooks`
-- (replace the check of one program, keyed by `exe`; returning `false` ends the
-- section) and `extra` (after the programs, before the parsers).

local function extra_markdown()
  if #vim.api.nvim_get_runtime_file('lua/render-markdown/init.lua', false) > 0 then
    health.ok('render-markdown.nvim: installed')
  else
    health.warn('render-markdown.nvim is not available', {
      'Start Neovim with network access so vim.pack can install the locked plugin',
      '`<Leader>om` cannot switch Markdown buffers to live or reading view',
    })
  end

  -- 'obsidian.nvim' is an `opt` plugin loaded by the gate in 'config.obsidian':
  -- only its absence from the lockfile is a problem.
  local obsidian_locked = vim.iter(vim.pack.get(nil, { info = false })):any(
    function(plugin) return plugin.spec.name == 'obsidian.nvim' end
  )
  if #vim.api.nvim_get_runtime_file('lua/obsidian/init.lua', false) > 0 then
    health.ok('obsidian.nvim: installed and loaded')
  elseif obsidian_locked then
    health.info(
      'obsidian.nvim: locked, not yet loaded (opens on the first note inside a `.obsidian/` vault)'
    )
  else
    health.warn('obsidian.nvim is not available', {
      'Start Neovim with network access so vim.pack can install the locked plugin',
      'Obsidian vault integration is unavailable until obsidian.nvim is installed',
    })
  end
end

-- Which toolchain answers here: a project's 'rust-toolchain.toml' can change it
local function hook_rustup(tool, language)
  if vim.fn.executable('rustup') ~= 1 then
    health.warn('`rustup` is not available', { tool.advice, tool.why })
    return false
  end
  local active = first_line({ 'rustup', 'show', 'active-toolchain' })
  if active == nil then
    health.warn('no active Rust toolchain', {
      find_tool(language, 'rustc').advice,
      tool.why,
    })
  else
    health.ok('active toolchain: ' .. active)
  end
end

-- The Node of *this directory* is not the one the servers run on: 'after/lsp/'
-- overrides it (`MISE_NODE_VERSION`) for the two servers alone. Below the floor
-- the server dies on its own source and no client ever attaches. Measured on
-- Node 14: `SyntaxError: Unexpected token '??='`, in a message no log reads.
local function hook_node(tool, language)
  local project_node = check_tool(tool)
  local major = tonumber((project_node or ''):match('^v?(%d+)'))
  if project_node == nil then
    health.info('node: no version answered here, so nothing to compare')
  elseif major ~= nil and major < language.node_minimum then
    health.info(
      ('node %s in this directory, below the %d `ts_ls` needs: the servers '):format(
        project_node,
        language.node_minimum
      )
        .. 'take the newest one `mise` has instead, see `after/lsp/ts_ls.lua`'
    )
  else
    health.ok('node in this directory: ' .. project_node)
  end
end

-- NOTE: the working directory is not the project root: 'angular.json' can sit
-- well below the repository root `MiniMisc.setup_auto_root()` chooses.
local function extra_angular(language)
  local root = source_root(language.markers)
  if root == nil then
    health.info('not inside an Angular project: nothing else to check here')
  elseif vim.uv.fs_stat(vim.fs.joinpath(root, 'node_modules')) == nil then
    health.warn("'" .. root .. "' has no 'node_modules'", {
      'Run `npm install` there',
      '`angularls` finds no language service to load, and `:make` no compiler',
    })
  else
    health.ok('project dependencies: installed in ' .. root)
    -- NOTE: `ngserver` loads the project's language service, and Neovim starts
    -- it through a `mise` shim that resolves from the current directory, so the
    -- major is pinned in the project's own mise.toml, not in the global one.
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
end

-- The JDK of the *project* (`java`) is not the one jdtls runs on: 'after/lsp/jdtls.lua'
-- hands the server the newest JDK `mise` has, through `MISE_JAVA_VERSION`. What
-- has to hold is that such a JDK exists and is new enough, so the resolved
-- config is read instead of naming a version here.
--
-- NOTE: below the minimum jdtls says so only in its own log, so an unmet
-- requirement looks like a server that simply does not attach.
local function hook_java(tool, language)
  local minimum = language.minimum
  local version = first_line({ 'java', '--version' })
  if version == nil then
    health.warn('`java` is not available', { tool.advice, tool.why })
    return false
  end
  health.ok('java: ' .. version .. ' (' .. vim.fn.exepath('java') .. ')')

  local server_jdk =
    vim.tbl_get(vim.lsp.config['jdtls'] or {}, 'cmd_env', 'MISE_JAVA_VERSION')
  if server_jdk == nil then
    health.warn('jdtls has no JDK of its own', {
      language.install_jdk,
      'It falls back to the JDK of the project, and a project on an older '
        .. 'release then leaves no client attached',
    })
  else
    -- A `mise` version string ('temurin-21.0.12+101.0.LTS'): the release is the
    -- first number after the vendor name
    local release = tonumber(server_jdk:gsub('^%D+', ''):match('^%d+'))
    if release ~= nil and release < minimum then
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
        ('jdtls JDK: %s, minimum required is %d'):format(server_jdk, minimum)
      )
    end
  end
end

-- The execution environments 'after/lsp/jdtls.lua' declares, read from the
-- resolved config so they cannot drift from what the server is told. `jdtls`
-- has no `--version` and its Windows wrapper ends with a `pause`: path only.
local function hook_jdtls(tool)
  local declared = vim.tbl_get(
    vim.lsp.config['jdtls'] or {},
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
    -- Not a warning: 'after/lsp/jdtls.lua' warns when the project it imported
    -- compiles against a release that no runtime here answers for.
    health.info(
      'A project on a release missing from this list is checked against the '
        .. "server's own JDK, and says so when it is opened"
    )
  end
  check_tool(tool)
end

local function extra_cpp(language)
  -- Without a compilation database clangd does not fail, it GUESSES: it assumes
  -- `clang some_file.cc` and reports errors on perfectly valid `#include`s,
  -- which is indistinguishable from a broken config.
  local root = source_root(language.markers)
  if root == nil then
    health.info('not inside a C or C++ project: nothing else to check here')
    return
  end
  -- Where clangd looks: the file's parents and their 'build/' subdirectory,
  -- where `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` writes it. Any other build
  -- directory name is out of reach. `compile_flags.txt` is the hand written
  -- alternative and has no background indexing.
  local database = vim
    .iter({
      vim.fs.joinpath(root, 'compile_commands.json'),
      vim.fs.joinpath(root, 'build', 'compile_commands.json'),
      vim.fs.joinpath(root, 'compile_flags.txt'),
    })
    :find(vim.uv.fs_stat)
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
    return
  end
  -- The C++ standard of the flags, which nothing else shows. Only the head of
  -- the file: the database of a real project is megabytes (`:h readblob()`).
  local standard = nil
  local ok, blob = pcall(vim.fn.readblob, database, 0, 8192)
  if ok then standard = tostring(blob):match('%-std=[%w%+]+') end
  health.ok(
    'compilation database: '
      .. database
      .. (standard and (' (' .. standard .. ')') or '')
  )
end

-- The whole toolchain of Godot is a game's, not the machine's: a section saying
-- "no Godot project here" would be noise in every other report, so this is the
-- one section that reports nothing when it does not apply.
local function gate_godot(language) return source_root(language.markers) end

local function begin_godot(_, root) health.ok('Godot project: ' .. root) end

-- `vim.fn.executable()` alone calls a `mise` shim healthy whatever version it
-- resolves: a directory that declares none answers `No version is set for shim`.
local function hook_godot(tool, language, root)
  if vim.fn.executable('godot') ~= 1 then
    health.warn('`godot` is not available', { tool.advice, tool.why })
    return
  end
  local version = first_line({ 'godot', '--version' })
  if version == nil then
    health.warn('`godot` is on PATH but answers no version in this directory', {
      ('Declare one for the game: `mise use %s`, run in %s'):format(
        language.pin,
        root
      ),
      'A `mise` shim resolves the version from the current directory, so it '
        .. 'exists and refuses to run where no mise.toml names the engine',
    })
  else
    health.ok('godot: ' .. version)
  end
end

-- NOTE: the port is a machine resource: a second Godot opened on another game
-- gets no port at all, so a buffer attaches to the first editor and answers
-- with the other game's symbols. Reported, never tested: connecting would turn
-- "the editor is closed", a legitimate choice, into a failure.
local function extra_godot()
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
end

local sections = {
  Markdown = { extra = extra_markdown },
  Rust = { hooks = { rustup = hook_rustup } },
  Angular = { hooks = { node = hook_node }, extra = extra_angular },
  Java = { hooks = { java = hook_java, jdtls = hook_jdtls } },
  ['C++'] = { extra = extra_cpp },
  Godot = {
    gate = gate_godot,
    begin = begin_godot,
    hooks = { godot = hook_godot },
    extra = extra_godot,
  },
}

local function check_language(language)
  local spec = sections[language.name] or {}
  local ctx = nil
  if spec.gate then
    ctx = spec.gate(language)
    if ctx == nil then return end
  end

  health.start('config: ' .. language.name)
  if spec.begin then spec.begin(language, ctx) end
  for _, tool in ipairs(language.tools or {}) do
    local hook = spec.hooks and spec.hooks[tool.exe]
    if hook then
      if hook(tool, language, ctx) == false then return end
    elseif tool.needs == nil or vim.fn.executable(tool.needs) == 1 then
      check_tool(tool)
    end
  end
  if spec.extra then spec.extra(language, ctx) end
  check_parsers(language)
end

function M.check()
  check_external_tools()
  for _, language in ipairs(toolchain.languages) do
    if language.health ~= false then check_language(language) end
  end
end

return M
