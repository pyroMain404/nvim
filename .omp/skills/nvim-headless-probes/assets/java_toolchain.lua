--- 18. Which JDK jdtls runs on, and which one it checks the project against.
---
--- The only probe in this directory that is about one language, and it is here
--- for the reason the others are generic: this contract breaks *silently*.
--- A server started on the wrong JDK does not attach at all, with nothing in
--- Neovim and the message in its own log; a project whose release is missing
--- from `runtimes` is checked against the class library of the JDK the server
--- runs on, which accepts calls that its build then rejects. Both look like a
--- healthy session, so neither is ever noticed by looking.
---
--- What can fail here, and what each failure accuses:
---   - no client attached      the server refused to start, almost always
---                             because the JDK it got is older than its minimum
---   - no `MISE_JAVA_VERSION`  'after/lsp/jdtls.lua' found no JDK through
---                             `mise`, and the server fell back to the
---                             project's
---   - no runtime for the      the release this project compiles against has no
---     project's release       JDK installed, so it is being checked against
---                             the wrong class library
---   - the build was not       the import failed, and everything the server
---     imported                answers comes from a bare JDK instead of the
---                             build - including the release it claims
---
--- Parameters:
---   before    snippet run first, when the buffer needs to be reopened
---   release   the release the project is expected to target, as jdtls spells
---             it ('1.8', '11', '21'). Optional: without it the probe reports
---             what the server answered instead of asserting it
---   timeout   how long to wait for the server to import the project, default
---             120000 ms - a first import downloads the build's dependencies
---
--- The file to open is given to the driver (`-File`), and `-Cwd` decides which
--- project is being probed: the toolchain of a checkout is resolved by `mise`
--- from the current directory, so the same probe answers differently from two
--- different repositories, which is the whole point of running it in both.
---
---   ./run.ps1 java_toolchain -Cwd <repo> -File <repo>/src/.../Thing.java `
---     -Params @{ release = '1.8' } -TimeoutSec 300
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  P.eval('before')
  local timeout = P.param('timeout', 120000)

  -- Attaching at all is the first assertion, not a precondition: it is exactly
  -- what fails when the server is handed a JDK older than it accepts.
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

  -- The JDK the server process itself was given. It is `nil` when the config
  -- found none through `mise`, and then the server is running on whatever the
  -- project resolves to - which happens to work only while the project's own
  -- toolchain is new enough.
  local server_jdk = vim.tbl_get(client.config, 'cmd_env', 'MISE_JAVA_VERSION')
  P.check('the server was given a JDK of its own', server_jdk ~= nil, server_jdk)

  -- The JDK the *project* resolves to, which is the one this probe exists to
  -- show is not the same thing. Reported, never asserted: 8 and 11 are normal
  -- answers, and the config is right precisely when they do not stop the server.
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

  -- Whether the build was imported at all, and it is not a formality: with a
  -- failed import - an unreachable repository, a parent POM that does not
  -- resolve - jdtls answers every question below from a bare JDK project at its
  -- own release. Every check then passes while nothing in the buffer is being
  -- read from the build, which is the shape of a probe that would pass anyway.
  -- Measured on '~/workspace/RGI/assimoco-pass-platform-batch' with the Maven
  -- credentials unset: empty here, compliance answered as 21, 'pom.xml' 11.
  local projects = execute('java.project.getAll', {}) or {}
  P.check(
    'the build was imported',
    #projects > 0,
    #projects > 0 and table.concat(projects, ', ')
      or 'none - open the build file, the error is reported there as a diagnostic'
  )

  -- What the project compiles against, asked to the server rather than read
  -- from 'pom.xml': jdtls has already resolved it from whatever build system
  -- the project uses, and that answer is the one the editor acts on.
  --
  -- NOTE: `java.project.getSettings` is a delegate command of jdtls, outside
  -- LSP. It takes a project URI and the keys to read; the root of the client is
  -- a project, so no buffer is needed. Asked before the import has finished it
  -- answers about a workspace still being built - which is why `wait_lsp()`
  -- above is not optional.
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

  -- The contract itself: the release the project targets has to be one of the
  -- JDKs jdtls was told about. `1.8` is the release 8, spelled the pre-9 way on
  -- both sides of this comparison.
  local wanted = (source == '1.8' or source == '8') and 'JavaSE-1.8'
    or ('JavaSE-' .. source)
  P.check(
    ('a runtime answers for Java %s'):format(source),
    vim.tbl_contains(names, wanted),
    ('%s wanted, declared: %s'):format(wanted, table.concat(names, ', '))
  )
end)
