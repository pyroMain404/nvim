-- ┌───────┐
-- │ jdtls │
-- └───────┘
--
-- For installation, see `check_java()` in 'lua/config/health.lua'.
-- The server starts 'bin/jdtls' by name, because it needs `java` and `python` from the `mise` shim.

-- The inherited `cmd` function creates a `-data` directory for each project.
-- This file leaves `cmd` out; see the `tbl_deep_extend` NOTE in 'after/lsp/ts_ls.lua'.
--
-- NOTE: 'nvim-jdtls' replaces this file instead of extending it.
-- It supplies the test runner, debug adapter, and refactorings.

local mise = require('config.mise')

-- This returns the major release for each version format ('temurin-8.0.504+1' and '1.8' give 8).
local function major_of(version)
  local digits = tostring(version):gsub('^%D+', '')
  local first, second = digits:match('^(%d+)%.?(%d*)')
  local major = tonumber(first)
  if major == 1 then major = tonumber(second) end
  return major
end

-- This returns the Eclipse execution environment name; only Java 8 uses a name different from its
-- major release.
local function execution_environment(major)
  return major == 8 and 'JavaSE-1.8' or ('JavaSE-' .. major)
end

-- This list contains installed JDKs, oldest first, with one JDK per release.
--
-- NOTE: If two JDKs have the same release, the code keeps the first JDK that `mise` lists.
-- NOTE: Without `mise`, `vim.system()` throws `ENOENT`.
-- Thus, `config.mise.installed()` uses `pcall`.
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

-- 'bin/jdtls.py' uses `$JAVA_HOME`, then `java` on PATH, to select the server JDK.
-- It refuses a JDK that is too old and writes the refusal only in its own log.
-- Thus, a project that pins Java 11 leaves no client attached.
-- `MISE_JAVA_VERSION` selects the newest installed release for this process only; the health check
-- reports an unmet minimum.
--
-- NOTE: The code sets this variable, not `JAVA_HOME`.
-- The `mise` shim recalculates `JAVA_HOME` from the working directory.
-- The code uses the exact installed version, not an alias that a project's 'mise.toml' can override.
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

-- Without these runtimes, the server uses its own class library and accepts calls that the build
-- rejects.
local runtimes = {}
for _, jdk in ipairs(jdks) do
  runtimes[#runtimes + 1] = {
    name = execution_environment(jdk.major),
    path = jdk.path,
  }
end

-- Warn if no installed JDK supplies the target release, or if jdtls did not import the build.
-- Without an imported build, jdtls reports its own JDK release; trusting this compliance value
-- would silently accept the wrong release.
-- The code asks the server for the compliance level and does not parse the build file.
--
-- NOTE: `java.project.getAll` and `java.project.getSettings` are jdtls delegate commands, not LSP
-- (verified against jdtls 1.61).
-- Only the root represents a multi-module build.
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
  -- Without a JDK, this value is nil; the server uses the project's JDK, with the warning above.
  cmd_env = server_jdk ~= nil and { MISE_JAVA_VERSION = server_jdk.version } or nil,

  -- Without this capability, definition returns nothing for a class without project sources, such
  -- as a JDK or jar class.
  -- With it, definition returns a `jdt://` URI.
  -- 'plugin/40_plugins.lua' requests its text from the server through `java/classFileContents`.
  init_options = {
    extendedClientCapabilities = { classFileContentsSupport = true },
  },

  handlers = {
    -- The jdtls notification `ServiceReady` is the final status after the import.
    ['language/status'] = function(_, result, ctx)
      if result == nil or result.type ~= 'ServiceReady' then return end
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      if client ~= nil and client.root_dir ~= nil then
        warn_about_toolchain(client)
      end
    end,
  },

  -- These Eclipse JDT server `java.*` keys supply the response to `workspace/configuration`.
  settings = {
    java = {
      configuration = {
        -- The default 'interactive' asks a question that Neovim does not answer.
        -- Thus, new dependencies stay unknown until a restart.
        updateBuildConfiguration = 'automatic',

        runtimes = runtimes,
      },

      -- Fetch the sources jar so `<Leader>ls` does not open a decompiled stub.
      maven = { downloadSources = true },
      eclipse = { downloadSources = true },

      -- This supplies the signature window of 'mini.completion' (`:h MiniCompletion.config`).
      signatureHelp = { enabled = true },
    },
  },
}
