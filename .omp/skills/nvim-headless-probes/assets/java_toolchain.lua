--- 18. Check the JDK for jdtls and the JDK for project checks.
---
--- This language-specific probe checks failures that give no visible warning.
--- A server with the wrong JDK does not attach and reports the error only in its own log, not
--- Neovim.
--- If `runtimes` lacks the project release, jdtls checks against its own JDK class library.
--- The server can then accept calls that the build rejects. Both failures can look like a healthy
--- session.
---
--- Failure meanings:
---   No client attached: The server refused to start, usually because its JDK is too old.
---   No `MISE_JAVA_VERSION`: 'after/lsp/jdtls.lua' found no JDK through `mise`.
---   The server then used the project JDK.
---   No runtime for the project release: The required JDK is absent.
---   The server thus checks against the wrong class library.
---   No build import: Import failed. The server uses a bare JDK for answers, including the
---   release.
---
--- Parameters:
---   before: Run this snippet first when the buffer needs to open again.
---   release: Specify the expected project release in jdtls form ('1.8', '11', '21').
---            Without this optional value, the probe reports the server answer without an
---   assertion.
---   timeout: Specify the project import wait limit. The default is 120000 ms.
---            The first import downloads build dependencies.
---
--- Give the file to open to the driver (`-File`). Use `-Cwd` to select the project.
--- `mise` resolves the checkout toolchain from the current directory.
--- Run the probe in each repository because results can differ.
---
---   ./run.ps1 java_toolchain -Cwd <repo> -File <repo>/src/.../Thing.java `
---     -Params @{ release = '1.8' } -TimeoutSec 300
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  P.eval('before')
  local timeout = P.param('timeout', 120000)

  -- Check attachment first, rather than assuming it. A server with a JDK below its minimum cannot
  -- attach.
  local idle, ms, note = P.wait_lsp({ timeout = timeout })
  P.check(
    'jdtls attached and finished importing',
    idle,
    ('%dms - %s'):format(ms, note)
  )

  local client = vim.lsp.get_clients({ bufnr = 0, name = 'jdtls' })[1]
  if client == nil then
    return P.fail(
      'no jdtls client on this buffer',
      'check `:LspLog` for "requires at least Java", and `:checkhealth config`'
    )
  end
  P.info('root: ' .. tostring(client.root_dir))

  -- This is the server process JDK. The value is `nil` if `mise` found none.
  -- The server then uses the project JDK, which works only if that JDK is new enough.
  local server_jdk = vim.tbl_get(client.config, 'cmd_env', 'MISE_JAVA_VERSION')
  P.check('the server was given a JDK of its own', server_jdk ~= nil, server_jdk)

  -- Report the project JDK separately from the server JDK. Do not assert its version: 8 and 11
  -- are valid.
  -- The configuration works correctly when an older project JDK does not prevent server startup.
  local project_jdk = vim.system({ 'java', '-version' }):wait()
  P.info('project JDK: ' .. vim.split(vim.trim(project_jdk.stderr or ''), '\n')[1])

  local runtimes = vim.tbl_get(client.settings, 'java', 'configuration', 'runtimes')
    or {}
  local names = {}
  for _, runtime in ipairs(runtimes) do
    names[#names + 1] = runtime.name
  end
  P.check(
    'jdtls was told about at least one JDK',
    #names > 0,
    table.concat(names, ', ')
  )

  local function execute(command, arguments)
    local answer = client:request_sync('workspace/executeCommand', {
      command = command,
      arguments = arguments,
    }, 20000, 0)
    return (answer or {}).result
  end

  -- Check build import before trusting the answers below.
  -- An unreachable repository or an unresolved parent POM can prevent import.
  -- jdtls then answers from a bare JDK project at its own release, so all later checks can pass
  -- incorrectly.
  -- On '~/workspace/RGI/assimoco-pass-platform-batch', absent Maven credentials caused an empty
  -- project list.
  -- The server reported compliance 21 while 'pom.xml' specified 11.
  local projects = execute('java.project.getAll', {}) or {}
  P.check(
    'the build was imported',
    #projects > 0,
    #projects > 0 and table.concat(projects, ', ')
      or 'none - open the build file, the error is reported there as a diagnostic'
  )

  -- Ask the server for the project release instead of reading 'pom.xml'.
  -- jdtls resolves the build system settings, and the editor uses that answer.
  --
  -- NOTE: `java.project.getSettings` is a jdtls delegate command outside LSP.
  -- It takes a project URI and keys; the client root identifies the project without a buffer.
  -- Wait for `wait_lsp()` first, or the command reports an incomplete workspace.
  local settings = execute('java.project.getSettings', {
    vim.uri_from_fname(client.root_dir),
    { 'org.eclipse.jdt.core.compiler.source' },
  })
  local source = vim.tbl_get(settings or {}, 'org.eclipse.jdt.core.compiler.source')
  if source == nil then
    return P.fail(
      'the server did not answer what this project compiles against',
      vim.inspect(settings)
    )
  end
  P.expect('project compliance', P.param('release'), source)

  -- The project target release must match a JDK in the jdtls runtime list.
  -- Both sides use `1.8`, the pre-9 name for release 8.
  local wanted = (source == '1.8' or source == '8') and 'JavaSE-1.8'
    or ('JavaSE-' .. source)
  P.check(
    ('a runtime answers for Java %s'):format(source),
    vim.tbl_contains(names, wanted),
    ('%s wanted, declared: %s'):format(wanted, table.concat(names, ', '))
  )
end)
