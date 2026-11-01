-- ┌───────┐
-- │ jdtls │
-- └───────┘
--
-- Install: `check_java()` in 'lua/config/health.lua'. 'bin/jdtls' needs `java`
-- and `python`, carried by the `mise` shim, so it is called by name.
-- `cmd` is absent: the inherited function builds a per-project `-data`
-- directory (see the `tbl_deep_extend` NOTE in 'after/lsp/ts_ls.lua').
--
-- NOTE: 'nvim-jdtls' replaces this file rather than adding to it; it brings the
-- test runner, debug adapter and refactorings.

local mise = require('config.mise')

-- Major release of any version spelling ('temurin-8.0.504+1' and '1.8' are 8).
local function major_of(version)
  local digits = tostring(version):gsub('^%D+', '')
  local first, second = digits:match('^(%d+)%.?(%d*)')
  local major = tonumber(first)
  if major == 1 then major = tonumber(second) end
  return major
end

-- Eclipse execution environment name; Java 8 is the one not spelled after its major.
local function execution_environment(major)
  return major == 8 and 'JavaSE-1.8' or ('JavaSE-' .. major)
end

-- Installed JDKs, oldest first, one per release.
--
-- NOTE: two JDKs of one release collapse to whichever `mise` lists first.
-- NOTE: `mise` absent makes `vim.system()` throw `ENOENT`, hence the `pcall`
-- inside `config.mise.installed()`.
local installed_jdks = mise.installed('java')
local jdks = {}
if installed_jdks ~= nil then
  local seen = {}
  for _, entry in ipairs(installed_jdks) do
    if entry.path ~= nil then
      local major = major_of(entry.version)
      if major ~= nil and seen[major] == nil then
        seen[major] = true
        jdks[#jdks + 1] = {
          major = major,
          version = entry.version,
          path = entry.path,
        }
      end
    end
  end
  table.sort(jdks, function(a, b) return a.major < b.major end)
end

-- The JDK the server itself runs on: 'bin/jdtls.py' uses `$JAVA_HOME`, then
-- `java` on PATH, and refuses a too-old one only in its own log, so a project
-- pinning Java 11 leaves no client attached. `MISE_JAVA_VERSION` points this
-- process alone at the newest installed release; the health check reports an
-- unmet minimum.
--
-- NOTE: it must be this variable, not `JAVA_HOME`: the `mise` shim recomputes
-- `JAVA_HOME` from the working directory. Use the exact installed version, not
-- an alias a project's 'mise.toml' can shadow.
local server_entry = mise.newest(
  'java',
  function(entry) return entry.path ~= nil and major_of(entry.version) ~= nil end
)
local server_jdk = server_entry
    and { major = major_of(server_entry.version), version = server_entry.version }
  or nil
if server_jdk == nil then
  vim.notify_once(
    'no JDK is installed through `mise`, so jdtls falls back to the JDK of the '
      .. 'project and will not start if that one is too old: install one with '
      .. '`mise install java@temurin-<major>`, and see `:checkhealth config` '
      .. 'for the release it needs',
    vim.log.levels.WARN
  )
end

-- Without these the class library is the server's own and accepts calls the build rejects.
local runtimes = {}
for _, jdk in ipairs(jdks) do
  runtimes[#runtimes + 1] = {
    name = execution_environment(jdk.major),
    path = jdk.path,
  }
end

-- Warn when the project targets a release no installed JDK provides, or when
-- its build was not imported (jdtls then answers as a bare JDK project at its
-- own release, so believing the compliance would be a silent pass). The
-- compliance is asked to the server, not parsed from the build file.
--
-- NOTE: `java.project.getAll` and `java.project.getSettings` are jdtls delegate
-- commands, not LSP (verified against jdtls 1.61). A multi-module build is
-- answered for by its root alone.
local function warn_about_toolchain(client)
  local function execute(command, arguments, on_answer)
    client:request(
      'workspace/executeCommand',
      { command = command, arguments = arguments },
      function(err, result)
        if err == nil then on_answer(result) end
      end
    )
  end
  local project = vim.fs.basename(client.root_dir)
  local server_release = server_jdk ~= nil and server_jdk.major or '?'

  execute('java.project.getAll', {}, function(projects)
    if type(projects) ~= 'table' or #projects == 0 then
      return vim.notify_once(
        ('%s: no project was imported, so what jdtls answers about this code '):format(
          project
        )
          .. ('comes from a bare JDK %s and not from the build. The reason is '):format(
            server_release
          )
          .. 'reported as an error on the build file itself',
        vim.log.levels.WARN
      )
    end

    execute('java.project.getSettings', {
      vim.uri_from_fname(client.root_dir),
      { 'org.eclipse.jdt.core.compiler.source' },
    }, function(settings)
      if type(settings) ~= 'table' then return end
      local major = major_of(settings['org.eclipse.jdt.core.compiler.source'])
      if major == nil then return end

      local wanted = execution_environment(major)
      for _, runtime in ipairs(runtimes) do
        if runtime.name == wanted then return end
      end
      vim.notify_once(
        ('%s targets Java %d, and no JDK %d is installed through `mise`: it is '):format(
          project,
          major,
          major
        )
          .. ('checked against Java %s, the release jdtls itself runs on, which '):format(
            server_release
          )
          .. ('accepts calls its build rejects. `mise install java@temurin-%d`'):format(
            major
          ),
        vim.log.levels.WARN
      )
    end)
  end)
end

return {
  -- Nil without a JDK: the server stays on the project's JDK, warned above.
  cmd_env = server_jdk ~= nil and { MISE_JAVA_VERSION = server_jdk.version } or nil,

  handlers = {
    -- `ServiceReady` (jdtls notification) is the last status, after the import.
    ['language/status'] = function(_, result, ctx)
      if result == nil or result.type ~= 'ServiceReady' then return end
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      if client ~= nil and client.root_dir ~= nil then
        warn_about_toolchain(client)
      end
    end,
  },

  -- The `java.*` keys of the Eclipse JDT server, answered to `workspace/configuration`.
  settings = {
    java = {
      configuration = {
        -- The default 'interactive' asks a question Neovim answers with nothing,
        -- so new dependencies stay unknown until a restart.
        updateBuildConfiguration = 'automatic',

        runtimes = runtimes,
      },

      -- Fetch the sources jar so `<Leader>ls` does not land in a decompiled stub.
      maven = { downloadSources = true },
      eclipse = { downloadSources = true },

      -- Feeds the signature window of 'mini.completion' (`:h MiniCompletion.config`).
      signatureHelp = { enabled = true },
    },
  },
}
