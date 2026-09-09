-- ┌───────┐
-- │ jdtls │
-- └───────┘
--
-- This file contains configuration of the Java language server.
-- Source: https://github.com/eclipse-jdtls/eclipse.jdt.ls
-- Install: see `check_java()` in 'lua/config/health.lua' for the exact `mise`
-- line. The server is a JVM program launched by 'bin/jdtls', a Python script,
-- so `java` and `python` both have to be reachable; the `mise` shim is what
-- carries them, which is why 'jdtls' is called by name and not by path.
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
--
-- `cmd` is deliberately absent from what this file returns. Every
-- 'lsp/jdtls.lua' found on 'runtimepath' is merged with
-- `vim.tbl_deep_extend('force')`, which merges tables but *replaces* functions,
-- and the one in 'nvim-lspconfig' defines `cmd` as a function: it builds the
-- `-data` workspace directory under `:h stdpath()` cache from the project root
-- and adds the JVM arguments of `$JDTLS_JVM_ARGS`. Writing `cmd` here as the
-- usual list would delete all of that and make every project share one
-- workspace. Its `root_markers` are two ordered groups (`mvnw`, `gradlew`,
-- '.git' first, then 'pom.xml' and the Gradle build files), which is what keeps
-- a multi-module build on one client instead of one per module. Run
-- `:=vim.lsp.config['jdtls']` to read the merged result; buffer-local behavior
-- belongs in an `:h LspAttach` autocommand.
--
-- Everything this file knows about which JDKs exist it asks `mise`, and
-- everything it knows about which one a project needs it asks the server. No
-- Java version is written down here: a list kept by hand was the previous
-- design, and its failure mode is silent - a release nobody remembered to add
-- is a project checked against the wrong class library, which looks exactly
-- like working autocompletion.
--
-- NOTE: 'nvim-jdtls' is the plugin the server's own documentation points at,
-- and it is the exclusive kind: it starts and owns the client, so it replaces
-- this file rather than adding to it. What it brings on top of what is here is
-- the JDT extensions Neovim knows nothing about - test runner, debug adapter,
-- `organizeImports`, extract refactorings, decompiled sources. Worth taking
-- when that is the day's work, not before.

-- The major release of a Java version, in any of the spellings that reach this
-- file: 'temurin-8.0.504+1' and '1.8' are 8, 'temurin-21.0.12+101.0.LTS' and
-- '21' are 21, 'graalvm-community-21.0.2' is 21.
--
-- Two rules cover all of them. Everything before the first digit is a vendor
-- name and is dropped - dropping a *vendor prefix* instead (`^%a[%w]*%-`) was
-- the first version of this line, and it silently skipped every vendor whose
-- name carries a hyphen. Then a leading `1.` is the pre-9 spelling, where the
-- release is the second number.
local function major_of(version)
  local digits = tostring(version):gsub('^%D+', '')
  local first, second = digits:match('^(%d+)%.?(%d*)')
  local major = tonumber(first)
  if major == 1 then major = tonumber(second) end
  return major
end

-- The Eclipse execution environment of a release, which is how both jdtls and
-- the `runtimes` setting name a JDK. Java 8 is the one not spelled after its
-- major, and the server is strict about it.
local function execution_environment(major)
  return major == 8 and 'JavaSE-1.8' or ('JavaSE-' .. major)
end

-- Every JDK `mise` has installed, oldest release first, one entry per release.
--
-- Asking `mise` is what keeps both the patch level and the list itself out of
-- this file: the directory is 'temurin-8.0.504+1' today and something else
-- after the next update, and the set of releases changes whenever a project
-- arrives on one nobody had met yet. It costs one process while this file is
-- read, once per session.
--
-- NOTE: two JDKs of the same release collapse into one entry, and which of the
-- two wins is decided by comparing the version strings - arbitrary between
-- vendors, but stable across runs. They share a class library, so for
-- `runtimes` it makes no difference; it does decide which one the server runs
-- on when the newest release happens to be installed twice.
--
-- NOTE: `mise` absent makes `vim.system()` throw `ENOENT` rather than return a
-- failing exit code, which at this point would abort the rest of the file and
-- leave the server without its settings - hence the `pcall`, in the shape
-- `first_line()` of 'lua/config/health.lua' uses for the same reason.
local function installed_jdks()
  local ok, out = pcall(
    function() return vim.system({ 'mise', 'ls', 'java', '--json' }):wait() end
  )
  if not ok or out.code ~= 0 then return {} end

  local decoded, entries = pcall(vim.json.decode, out.stdout)
  if not decoded or type(entries) ~= 'table' then return {} end

  local by_release = {}
  for _, entry in ipairs(entries) do
    local major = nil
    if entry.installed and entry.install_path ~= nil then
      major = major_of(entry.version)
    end
    local known = major ~= nil and by_release[major] or nil
    if major ~= nil and (known == nil or known.version < entry.version) then
      by_release[major] = {
        major = major,
        version = entry.version,
        path = entry.install_path,
      }
    end
  end

  local jdks = vim.tbl_values(by_release)
  table.sort(jdks, function(a, b) return a.major < b.major end)
  return jdks
end

local jdks = installed_jdks()

-- The JDK the *server itself* runs on, which is not the one a project is
-- compiled against. 'bin/jdtls.py' picks it in this order: `--java-executable`,
-- then `$JAVA_HOME/bin/java`, then whatever `java` the PATH resolves to
-- (`get_java_executable`, line 22) - and it refuses to start below a minimum of
-- its own, saying so only in its own log: 'Exception: jdtls requires at least
-- Java 21' there, and nothing at all in Neovim.
--
-- That last case is the trap, because it ties the server to the toolchain of
-- the project being opened. A repository pinning Java 11 through `mise` - every
-- PASS repository under '~/workspace/RGI' does - leaves no client attached,
-- with nothing wrong in the project and no message anywhere the user is
-- looking. `MISE_JAVA_VERSION` decouples the two for this process alone: the
-- server starts on the JDK chosen here, while the same directory keeps
-- resolving the JDK its build needs for every other command.
--
-- The newest installed release is that choice, rather than a version named
-- here, and it is what makes the day jdtls raises its minimum an installation
-- instead of an edit: `mise install java@temurin-<major>` and the server moves.
-- Naming one meant keeping this file in step with a number written inside the
-- launcher, which nothing here can see. The health check reads that number and
-- is where an unmet minimum is reported.
--
-- NOTE: it has to be this variable and not `JAVA_HOME`. `jdtls` is itself a
-- `mise` shim, and a shim *recomputes* `JAVA_HOME` from the tools of its working
-- directory, overwriting whatever it inherited - measured: `JAVA_HOME=<21>
-- mise exec -- printenv JAVA_HOME` answers with the 11 of that project. Setting
-- `JAVA_HOME` here looks right, changes nothing, and fails silently. The exact
-- installed version is what `mise` is asked for, because that string resolves
-- from any directory, while an alias can be shadowed by a project's 'mise.toml'.
local server_jdk = jdks[#jdks]
if server_jdk == nil then
  vim.notify_once(
    'no JDK is installed through `mise`, so jdtls falls back to the JDK of the '
      .. 'project and will not start if that one is too old: install one with '
      .. '`mise install java@temurin-<major>`, and see `:checkhealth config` '
      .. 'for the release it needs',
    vim.log.levels.WARN
  )
end

-- The JDKs a project may be compiled against, named after the execution
-- environments of Eclipse. The server compiles with its own JDK unless told
-- otherwise, so on a project targeting a different release the compliance level
-- read from 'pom.xml' is right and the class library is not: a method that
-- release does not have is completed and accepted in the buffer, and then
-- rejected by the real build.
--
-- NOTE: this list stopped being optional when the server got its own JDK above.
-- While it ran on whatever `java` the project resolved to, the two agreed by
-- accident and an omission here cost nothing.
local runtimes = {}
for _, jdk in ipairs(jdks) do
  runtimes[#runtimes + 1] = {
    name = execution_environment(jdk.major),
    path = jdk.path,
  }
end

-- Say so when the project targets a release no installed JDK provides.
--
-- This is the one gap `runtimes` cannot close on its own: declaring every JDK
-- `mise` has says nothing about the JDK it does not have, and the result of
-- that mismatch is a project silently checked against the release the server
-- runs on. Nothing in the buffer looks wrong - the compliance level is right,
-- the class library is not - so it surfaces as a build rejecting code the
-- editor accepted, hours later.
--
-- The compliance is asked to the server rather than read from 'pom.xml': jdtls
-- has already resolved it from whatever build system the project uses - Maven,
-- Gradle, Ant or none - and parsing any of those here would be a second, worse
-- answer to a question that already has one.
--
-- The answer only means something once the build has been imported, which is
-- why the first request asks whether one was. When the import fails - an
-- unreachable repository, a parent POM that does not resolve - jdtls keeps
-- answering: it falls back to a bare JDK project at its own release, so the
-- compliance it reports is its own and always has a runtime. Believing it turns
-- every failed import into a silent pass, and that is the state of every PASS
-- repository under '~/workspace/RGI' while the Maven credentials are unset.
-- Measured there: `java.project.getAll` empty, compliance answered as 21,
-- 'pom.xml' saying 11, and one error on 'pom.xml' about the parent POM.
--
-- NOTE: `java.project.getAll` and `java.project.getSettings` are delegate
-- commands of jdtls, not part of LSP. The first answers with the URIs of the
-- projects it imported, the second takes the URI of one of them and the keys to
-- read, and answers with the Eclipse compiler settings
-- ('org.eclipse.jdt.core.compiler.source' is '1.8' on a Java 8 project).
-- Verified against jdtls 1.61.
--
-- NOTE: the root of the client is one project, and a multi-module build whose
-- modules target different releases is answered for by the root alone. Worth
-- knowing before trusting the silence; not worth one request per module.
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
  -- Nil when no JDK is installed, which leaves the field out of the merged
  -- config and the server back on the JDK of the project - degraded, warned
  -- about above, not broken.
  cmd_env = server_jdk ~= nil and { MISE_JAVA_VERSION = server_jdk.version } or nil,

  handlers = {
    -- `language/status` is a notification of jdtls, outside LSP, and the only
    -- thing that says when the project has finished being imported. Asking
    -- before that answers about a workspace the server is still building.
    -- Observed order on a Maven project: `Starting`, `ProjectStatus`,
    -- `Started`, then `ServiceReady` last.
    ['language/status'] = function(_, result, ctx)
      if result == nil or result.type ~= 'ServiceReady' then return end
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      if client ~= nil and client.root_dir ~= nil then
        warn_about_toolchain(client)
      end
    end,
  },

  -- Structure of these settings comes from jdtls, not from Neovim: they are
  -- the `java.*` keys of the Eclipse JDT language server, documented with the
  -- VS Code extension that drives it
  -- (https://github.com/redhat-developer/vscode-java#supported-vs-code-settings).
  -- Neovim hands them over when the server asks with `workspace/configuration`.
  -- Only settings whose default is off are here.
  settings = {
    java = {
      configuration = {
        -- With the default 'interactive' the server asks before re-reading
        -- 'pom.xml', through a request Neovim answers with nothing, so a
        -- dependency added to the build stays unknown and its imports keep
        -- being reported as errors until the server is restarted.
        updateBuildConfiguration = 'automatic',

        -- Which JDK a project is checked against, built above from what `mise`
        -- has installed. An empty list is the default behavior, which is what
        -- `mise` being unavailable falls back to.
        runtimes = runtimes,
      },

      -- `<Leader>ls` on a symbol of a dependency otherwise lands in a
      -- decompiled stub with no parameter names and no comments. These two
      -- make the build tool fetch the sources jar, which is the Java
      -- equivalent of `rust-src`. The cost is paid once per dependency.
      maven = { downloadSources = true },
      eclipse = { downloadSources = true },

      -- Off by default in jdtls, and it is what fills the signature window of
      -- 'mini.completion' while typing the arguments of a call
      -- (`:h MiniCompletion.config`).
      signatureHelp = { enabled = true },
    },
  },
}
