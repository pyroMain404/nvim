-- ┌─────────────────────┐
-- │ Languages and tools │
-- └─────────────────────┘
--
-- The one declaration of what each language needs: parsers, servers, formatters
-- and the programs `:checkhealth config` verifies. Read by 'plugin/40_plugins.lua'
-- and 'lua/config/health.lua'; the order of `languages` is the order of both.

local M = {}

local function mise(spec) return 'Install it with `mise use -g ' .. spec .. '`' end
local function winget(id) return 'Install it with `winget install ' .. id .. '`' end

local jdk_minimum = 21
local jdtls_version = '1.61.0'
local jdtls_build = '202609031315'
local install_jdk = ('Install one with `mise install java@temurin-%d`'):format(
  jdk_minimum
)
local install_toolchain = 'Install one with `rustup toolchain install stable`'
local install_llvm = winget('LLVM.LLVM')
local install_jdtls = mise(
  ('"http:jdtls[url=https://download.eclipse.org/jdtls/milestones/%s/'):format(
    jdtls_version
  )
    .. ('jdt-language-server-%s-%s.tar.gz,bin_path=bin]@%s"'):format(
      jdtls_version,
      jdtls_build,
      jdtls_version
    )
)

-- Programs the config uses when they are there and does without when they are
-- not. `git`, `rg` and `lazygit` are system utilities; the rest is declared in `mise`.
M.external = {
  {
    exe = 'git',
    why = "'mini.git' and 'mini.diff' show no data",
    advice = winget('Git.Git'),
  },
  {
    exe = 'rg',
    why = '`<Leader>ff` and `<Leader>fg` get slower',
    advice = mise('ripgrep@latest'),
  },
  {
    exe = 'lazygit',
    why = '`<Leader>tl` warns and does nothing',
    advice = mise('lazygit@latest'),
  },
  {
    exe = 'stylua',
    why = 'config formatting can not be checked, and `<Leader>lf` does nothing in Lua',
    advice = mise('stylua@latest'),
  },
  {
    exe = 'tree-sitter',
    why = 'no parser can be installed or updated, `:TSUpdate` included',
    advice = mise('tree-sitter@latest')
      .. ', and make sure the '
      .. "'mise' shims directory is on PATH: on Windows nothing puts it there",
  },
  {
    exe = 'mise',
    why = 'no declared tool - language server, formatter, linter, runtime - '
      .. 'installs or updates',
    advice = winget('jdx.mise') .. ', then run `mise doctor`',
  },
}

-- Per language: `name` is the title of its health section (`health = false`
-- gives it none), `bundled` parsers ship with Neovim, `markers` identify a
-- project of the language. A tool is checked for its `--version`, by path only
-- with `check = 'path'`, and only when `needs` is installed.
M.languages = {
  {
    name = 'Lua',
    bundled = true,
    parsers = { 'lua' },
    servers = { 'lua_ls' },
    -- Reads the '.stylua.toml' at the root, so `<Leader>lf` and `stylua --check` agree
    formatters = { lua = { 'stylua' } },
    tools = {
      {
        exe = 'lua-language-server',
        why = 'Lua buffers lose completion, diagnostics, rename and go to definition',
        advice = mise('lua-language-server@latest'),
      },
    },
  },
  { name = 'Vim help', health = false, parsers = { 'vimdoc' } },
  {
    name = 'Markdown',
    -- `yaml` is only used through the injection that parses the frontmatter
    parsers = { 'markdown', 'yaml' },
  },
  {
    name = 'Rust',
    -- `toml` for the manifest; `sql` only through 'after/queries/rust/injections.scm'
    parsers = { 'rust', 'toml', 'sql' },
    servers = { 'rust_analyzer' },
    formatters = { rust = { 'rustfmt' } },
    tools = {
      {
        exe = 'rustup',
        why = "Nothing in 'after/lsp/rust_analyzer.lua' can start without a toolchain",
        advice = 'Install it from https://rustup.rs',
      },
      { exe = 'rustc', why = 'nothing compiles', advice = install_toolchain },
      {
        exe = 'cargo',
        why = '`:make check` and `:make test` do nothing',
        advice = install_toolchain,
      },
      {
        exe = 'rustfmt',
        why = '`<Leader>lf` falls back to a server that formats differently',
        advice = 'Install it with `rustup component add rustfmt`',
      },
      {
        exe = 'rust-analyzer',
        why = 'Rust buffers lose completion, diagnostics, rename and go to definition',
        advice = 'Install it with `rustup component add rust-analyzer rust-src`',
      },
      {
        exe = 'cargo-clippy',
        why = 'the server is configured to check with clippy and finds nothing to run',
        advice = 'Install it with `rustup component add clippy`',
      },
    },
  },
  {
    name = 'Angular',
    -- `angular` reads a template, the rest are the other files of a component
    parsers = { 'angular', 'typescript', 'html', 'css', 'scss', 'json' },
    servers = { 'angularls', 'ts_ls' },
    formatters = {
      typescript = { 'prettier' },
      javascript = { 'prettier' },
      html = { 'prettier' },
      htmlangular = { 'prettier' },
      css = { 'prettier' },
      scss = { 'prettier' },
      json = { 'prettier' },
    },
    markers = { 'angular.json', 'nx.json' },
    -- The floor of `typescript-language-server` 6; `ngserver` asks for less
    node_minimum = 18,
    tools = {
      {
        exe = 'node',
        why = 'neither language server starts, and `:make` has no `npx` to call',
        advice = mise('node@20'),
      },
      {
        exe = 'ngserver',
        check = 'path',
        why = 'Templates lose completion, diagnostics and go to definition',
        advice = {
          mise('npm:@angular/language-server@<major>'),
          'That global one is only the fallback: the major has to be the one of '
            .. 'the project, and a project on another major pins it in its own '
            .. 'mise.toml',
        },
      },
      {
        exe = 'typescript-language-server',
        why = 'TypeScript buffers lose completion, diagnostics, rename and go to definition',
        advice = mise('npm:typescript-language-server@latest'),
      },
      {
        exe = 'tsc',
        why = 'a `.ts` file outside any Node project gets no `ts_ls` at all, instead of falling back',
        advice = mise('npm:typescript@latest'),
      },
      {
        exe = 'prettier',
        why = '`<Leader>lf` falls back to a language server that formats differently',
        advice = mise('npm:prettier@latest'),
      },
    },
    -- NOTE: `ngserver` loads the `@angular/language-service` of the project it
    -- opens, so its major must be the project's; a newer one fails quietly.
  },
  {
    name = 'Java',
    -- `xml` is for 'pom.xml'
    parsers = { 'java', 'xml' },
    servers = { 'jdtls' },
    -- The oldest release jdtls starts on: 'bin/jdtls.py' raises without it
    minimum = jdk_minimum,
    install_jdk = install_jdk,
    tools = {
      {
        exe = 'java',
        why = "Nothing in 'after/lsp/jdtls.lua' can start without a JDK",
        advice = install_jdk .. " and pin the project one in its 'mise.toml'",
      },
      {
        exe = 'javac',
        why = "`:make` does nothing in a file that belongs to no build ('compiler/javac')",
        advice = 'It comes with the JDK, whichever release the project targets',
      },
      {
        exe = 'mvn',
        why = '`:make test` and `:make compile` do nothing in a Maven project',
        advice = mise('maven@3.9'),
      },
      {
        exe = 'jdtls',
        check = 'path',
        why = 'Java buffers lose completion, diagnostics, rename and go to definition',
        advice = install_jdtls,
      },
      {
        exe = 'python',
        needs = 'jdtls',
        why = 'the `jdtls` launcher is a Python script and never starts the server',
        advice = mise('python@3.12'),
      },
    },
  },
  {
    name = 'C++',
    -- `c` is required by `cpp`; `cmake` and `make` are the build files
    parsers = { 'cpp', 'c', 'cmake', 'make' },
    servers = { 'clangd' },
    -- Reads the project's '.clang-format', which the server would not
    formatters = { cpp = { 'clang-format' }, c = { 'clang-format' } },
    markers = {
      'CMakeLists.txt',
      'compile_commands.json',
      'compile_flags.txt',
      'Makefile',
    },
    tools = {
      {
        exe = 'clangd',
        why = 'C and C++ buffers lose completion, diagnostics, rename and go to definition',
        advice = install_llvm,
      },
      {
        exe = 'clang++',
        why = 'this is the compiler a CMake- or LLVM-configured C/C++ project builds with',
        advice = install_llvm,
      },
      {
        exe = 'clang-format',
        why = '`<Leader>lf` falls back to a server that formats differently',
        advice = install_llvm,
      },
      {
        exe = 'clang-tidy',
        check = 'path',
        why = 'the server is configured to lint with clang-tidy and finds nothing to run',
        advice = install_llvm,
      },
      {
        exe = 'cmake',
        why = "`:make` has nothing to run ('compiler/cmake.lua')",
        advice = mise('cmake@4'),
      },
      {
        exe = 'ninja',
        why = 'CMake falls back to a slower generator',
        advice = mise('ninja@1.13'),
      },
      {
        exe = 'make',
        why = "`:make` in a plain-Makefile project ('after/ftplugin/c.lua') does nothing",
        advice = winget('GnuWin32.Make') .. ', or use a CMake project',
      },
    },
  },
  {
    name = 'Godot',
    -- `gdshader` also carries `gdshaderinc`; `godot_resource` reads '.tscn' and '.tres'
    parsers = { 'gdscript', 'gdshader', 'godot_resource' },
    servers = { 'gdscript' },
    -- The Godot server does not format, so this is what `<Leader>lf` calls
    formatters = { gdscript = { 'gdformat' } },
    markers = { 'project.godot' },
    pin = 'godot@4',
    tools = {
      {
        exe = 'godot',
        why = 'No engine means no language server, and `:make` has nothing to call',
        advice = mise('godot@4'),
      },
      {
        exe = 'gdformat',
        why = '`<Leader>lf` and `<Leader>lF` have nothing to call in a GDScript buffer',
        advice = mise('pipx:gdtoolkit@4.5.0'),
      },
    },
    -- NOTE: the server is the Godot editor itself, over TCP, so `cmd` is a
    -- function and must not be overridden; the port belongs to the machine.
  },
}

-- Flat, deduplicated, in the order of `languages`
local function collect(field)
  local out, seen = {}, {}
  for _, language in ipairs(M.languages) do
    for _, item in ipairs(language[field] or {}) do
      if not seen[item] then
        seen[item] = true
        out[#out + 1] = item
      end
    end
  end
  return out
end

function M.parsers() return collect('parsers') end

function M.servers() return collect('servers') end

function M.formatters_by_ft()
  local out = {}
  for _, language in ipairs(M.languages) do
    for ft, names in pairs(language.formatters or {}) do
      out[ft] = vim.deepcopy(names)
    end
  end
  return out
end

return M
