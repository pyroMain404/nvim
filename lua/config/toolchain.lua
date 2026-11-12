-- ┌─────────────────────┐
-- │ Languages and tools │
-- └─────────────────────┘
--
-- This module declares parsers, servers, formatters and programs for `:checkhealth config`.
-- 'plugin/40_plugins.lua' and 'lua/config/health.lua' read it.
-- Both use the order of `languages`.

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

-- The config uses these programs if they exist, but also works without them.
-- `git`, `rg` and `lazygit` are system utilities; `mise` declares the others.
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

-- `name` supplies the language health section title; `health = false` omits the section.
-- Neovim includes `bundled` parsers; `markers` identify a project for the language.
-- The check uses `--version`, or only the path with `check = 'path'`.
-- The check runs only if `needs` is installed.
-- A tool without `--version` supplies its command in `version` (`go version`).
M.languages = {
  {
    name = 'Lua',
    bundled = true,
    parsers = { 'lua' },
    servers = { 'lua_ls' },
    -- stylua reads '.stylua.toml' at the root, so `<Leader>lf` and `stylua --check` agree.
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
    -- Only the frontmatter injection uses `yaml`.
    parsers = { 'markdown', 'yaml' },
  },
  {
    name = 'Rust',
    -- `toml` parses the manifest; only 'after/queries/rust/injections.scm' uses `sql`.
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
    -- `angular` parses templates; the other parsers handle the other component files.
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
    -- `typescript-language-server` 6 requires this minimum; `ngserver` requires less.
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
    -- NOTE: `ngserver` loads the project's `@angular/language-service`, so their major versions
    -- must match.
    -- A newer version fails without a message.
  },
  {
    name = 'Java',
    -- `xml` parses 'pom.xml'.
    parsers = { 'java', 'xml' },
    servers = { 'jdtls' },
    -- jdtls requires this minimum release; 'bin/jdtls.py' raises an error with an older release.
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
    -- `cpp` requires `c`; `cmake` and `make` parse build files.
    parsers = { 'cpp', 'c', 'cmake', 'make' },
    servers = { 'clangd' },
    -- clang-format reads the project's '.clang-format'; the server does not.
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
    name = 'Go',
    -- `gomod` and `gowork` parse 'go.mod' and 'go.work'.
    parsers = { 'go', 'gomod', 'gowork' },
    servers = { 'gopls' },
    -- gofmt gives results that agree with `gofmt -l` in the project's CI.
    formatters = { go = { 'gofmt' } },
    tools = {
      {
        exe = 'go',
        version = { 'version' },
        why = "nothing compiles, and `:make` and `:Run` ('after/ftplugin/go.lua') do nothing",
        advice = mise('go@latest'),
      },
      {
        exe = 'gopls',
        version = { 'version' },
        why = 'Go buffers lose completion, diagnostics, rename and go to definition',
        advice = mise('go:golang.org/x/tools/gopls@latest'),
      },
      {
        exe = 'gofmt',
        check = 'path',
        why = '`<Leader>lf` falls back to the server, which formats the same way',
        advice = 'It comes with the Go toolchain',
      },
    },
  },
  {
    name = 'Python',
    parsers = { 'python' },
    -- `basedpyright` checks types; `ruff` checks lint.
    -- 'after/lsp/basedpyright.lua' selects the interpreter.
    servers = { 'basedpyright', 'ruff' },
    -- ruff reads the project's 'pyproject.toml' or 'ruff.toml', as CI does.
    -- `ruff server` checks lint only.
    formatters = { python = { 'ruff_format' } },
    tools = {
      {
        exe = 'python',
        why = '`:Run` refuses and basedpyright resolves no imports',
        advice = mise('python@3.12'),
      },
      {
        exe = 'basedpyright',
        why = 'Python buffers lose completion, type diagnostics, rename and go to definition',
        advice = mise('npm:basedpyright@latest'),
      },
      {
        exe = 'ruff',
        why = '`<Leader>lf` has nothing to call and lint diagnostics are gone',
        advice = mise('ruff@latest'),
      },
    },
  },
  {
    name = 'Godot',
    -- `gdshader` also includes `gdshaderinc`; `godot_resource` parses '.tscn' and '.tres'.
    parsers = { 'gdscript', 'gdshader', 'godot_resource' },
    servers = { 'gdscript' },
    -- The Godot server does not format, so `<Leader>lf` calls gdformat.
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
    -- NOTE: The Godot editor serves requests over TCP, so `cmd` is a function.
    -- Do not override `cmd`. The port belongs to the machine.
  },
}

-- Return a flat list without duplicates, in the order of `languages`.
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
