-- ┌──────────────┐
-- │ Health check │
-- └──────────────┘
--
-- This check reports installed programs, their versions and features that need them.
-- Run `:checkhealth config` (`:h health-dev`).
-- Neovim finds this check by path, not through `require`.

local M = {}
local health = vim.health
local toolchain = require('config.toolchain')

-- NOTE: Windows console tools can print carriage returns (`java --version`).
-- The first `trim` removes only the carriage return at the end of the output.
-- The second `trim` removes the one on the first line.
local function first_line(cmd)
  local ok, out = pcall(function() return vim.system(cmd):wait() end)
  if not ok or out.code ~= 0 then return nil end
  return vim.trim(vim.split(vim.trim(out.stdout), '\n')[1] or '')
end

-- Report a `toolchain` program's version, or its path with `check = 'path'`.
-- Warn if a program on `PATH` fails `--version`, instead of reporting `OK` without a version.
-- This can occur with `rustc.exe` after removal of a rustup component.
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

-- Check each parser of `language` with the installation check from 'plugin/40_plugins.lua'.
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

-- NOTE: `:checkhealth` runs each check in its own unnamed report buffer.
-- Search from the previous buffer (`#`), or from the working directory if no previous buffer
-- exists.
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
-- `check_language()` handles the common checks; `sections` below supplies language-specific checks.
-- `gate` returns before `start()` if the check does not apply.
-- `begin` starts the section.
-- `hooks` replaces program checks by `exe`; returning `false` ends the section.
-- `extra` runs after the program checks and before the parser checks.

local function extra_markdown()
  if #vim.api.nvim_get_runtime_file('lua/render-markdown/init.lua', false) > 0 then
    health.ok('render-markdown.nvim: installed')
  else
    health.warn('render-markdown.nvim is not available', {
      'Start Neovim with network access so vim.pack can install the locked plugin',
      '`<Leader>om` cannot switch Markdown buffers to live or reading view',
    })
  end

  -- The gate in 'config.obsidian' loads 'obsidian.nvim' as an `opt` plugin.
  -- Only its absence from the lockfile indicates a problem.
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

-- A project's 'rust-toolchain.toml' can select a different toolchain here.
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

-- 'after/lsp/' sets `MISE_NODE_VERSION` for the two servers, independently of this directory's Node
-- version.
-- Below the minimum version, the server fails to parse its source, so no client attaches.
-- Node 14 produced `SyntaxError: Unexpected token '??='` in a message that no log records.
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

-- NOTE: The working directory is not necessarily the project root.
-- 'angular.json' can be below the repository root that `MiniMisc.setup_auto_root()` selects.
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
    -- NOTE: A `mise` shim starts `ngserver` and resolves its version from the current directory.
    -- The project's mise.toml therefore pins the major version, not the global mise.toml.
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

-- The project's JDK (`java`) can differ from the JDK for jdtls.
-- 'after/lsp/jdtls.lua' supplies the newest JDK from `mise` through `MISE_JAVA_VERSION`.
-- Read the resolved config to check that this JDK exists and meets the minimum version.
--
-- NOTE: jdtls reports an older JDK only in its own log, so it looks like a server attachment
-- failure.
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
    -- In a `mise` version string ('temurin-21.0.12+101.0.LTS'), the first number after the vendor
    -- names the release.
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

-- Read the execution environments from the resolved 'after/lsp/jdtls.lua' config to match the
-- server settings.
-- Check only the path: `jdtls` has no `--version`, and its Windows wrapper ends with a `pause`.
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
    -- 'after/lsp/jdtls.lua' warns if an imported project targets a release without a runtime here.
    -- Do not warn again here.
    health.info(
      'A project on a release missing from this list is checked against the '
        .. "server's own JDK, and says so when it is opened"
    )
  end
  check_tool(tool)
end

local function extra_cpp(language)
  -- Without a compilation database, clangd assumes `clang some_file.cc` instead of failing.
  -- It then reports errors on valid `#include`s, which look like config errors.
  local root = source_root(language.markers)
  if root == nil then
    health.info('not inside a C or C++ project: nothing else to check here')
    return
  end
  -- clangd searches the file's parent directories and their 'build/' subdirectory.
  -- `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` writes the database there. Other build directory names are
  -- outside the search.
  -- A manually written `compile_flags.txt` is an alternative, but it gives no background indexing.
  local database = vim
    .iter({
      vim.fs.joinpath(root, 'compile_commands.json'),
      vim.fs.joinpath(root, 'build', 'compile_commands.json'),
      vim.fs.joinpath(root, 'compile_flags.txt'),
    })
    :find(vim.uv.fs_stat)
  -- TODO: Make the advice match the build system of a real GDExtension checkout.
  -- 'godot-cpp' historically uses SCons (`scons compiledb=yes` writes the database); recent
  -- versions also include 'CMakeLists.txt'.
  -- The advice below names only CMake, so it can misleadingly prescribe an unsupported command.
  -- Wrong advice reads as authoritative, so it is worse than no advice.
  --
  -- No GDExtension project exists on this machine; defer changes to avoid guessing its build
  -- system.
  -- This branch exists to avoid advice that depends on guesses.
  --
  -- First, check a real project's root for 'SConstruct' and 'CMakeLists.txt' before changing this
  -- branch.
  -- Keep CMake advice if 'CMakeLists.txt' exists; use `scons compiledb=yes` only if 'SConstruct'
  -- exists alone.
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
  -- Show the C++ standard from the flags; no other check shows it.
  -- Read only the file's start because real project databases contain megabytes (`:h readblob()`).
  local standard = nil
  local ok, blob = pcall(vim.fn.readblob, database, 0, 8192)
  if ok then standard = tostring(blob):match('%-std=[%w%+]+') end
  health.ok(
    'compilation database: '
      .. database
      .. (standard and (' (' .. standard .. ')') or '')
  )
end

-- The Godot toolchain belongs to a game, not the machine.
-- This section reports nothing outside a game to avoid "no Godot project here" in unrelated
-- reports.
local function gate_godot(language) return source_root(language.markers) end

local function begin_godot(_, root) health.ok('Godot project: ' .. root) end

-- `vim.fn.executable()` accepts a `mise` shim without checking its version.
-- A directory without a declared version answers `No version is set for shim`.
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

-- NOTE: The port is a machine resource. A second Godot editor on another game gets no port.
-- Buffers then attach to the first editor and show the other game's symbols.
-- Report the port without testing a connection: "the editor is closed" is valid, not a failure.
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

-- Check the interpreter that `:Run` and basedpyright use here, not only `python` on PATH.
-- The Microsoft Store alias exists on PATH but runs nothing.
local function hook_python(tool)
  local cwd = vim.fn.getcwd()
  local python = require('config.python').interpreter(cwd)
  if python == nil then
    health.warn('no Python interpreter found', { tool.advice, tool.why })
  elseif python:find('WindowsApps', 1, true) then
    health.warn('interpreter is the Microsoft Store alias: ' .. python, {
      'Put a real Python before it on PATH (`mise use -g python@3.12` and the mise shims directory), or disable the alias in Settings > Apps > App execution aliases',
      'The alias opens the Store instead of running scripts',
    })
  else
    health.ok('interpreter for ' .. cwd .. ': ' .. python)
    local version = first_line({ python, '--version' })
    if version then health.info(version) end
  end
end

local sections = {
  Markdown = { extra = extra_markdown },
  Rust = { hooks = { rustup = hook_rustup } },
  Python = { hooks = { python = hook_python } },
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
