-- Supporto Java tramite eclipse.jdt.ls (jdtls), gestito da nvim-jdtls invece che da
-- mason-lspconfig: jdtls vuole un client per-progetto con workspace dedicato e un
-- avvio con argomenti specifici, cosa che il flusso `vim.lsp.config` standard non
-- copre bene. Per questo jdtls NON è in `lsp_servers.lua` ed è escluso da
-- `automatic_enable` in `mason.lua` (altrimenti girerebbero due client sullo stesso
-- buffer). Il binario dei jar è installato da Mason (vedi `mason.lua`).
--
-- Guardia JDK: il language server è esso stesso un processo Java. Non basta che
-- `java` sia raggiungibile: eclipse.jdt.ls è compilato per Java 21+, quindi con una
-- JDK più vecchia il client crasha all'avvio (UnsupportedClassVersionError) senza
-- dare un errore comprensibile. Perciò controlliamo la *versione*, non solo la
-- presenza, e se nessuna JDK adeguata è disponibile non avviamo nulla e avvisiamo
-- una sola volta, in modo pigro (solo aprendo un file Java, `ft = "java"`).
--
-- Da dove prendiamo il `java`, in ordine: (1) il pin macchina-specifico
-- `machine.java_home` (vedi `user/machine.lua`), che vince a prescindere dall'ambiente;
-- (2) `JAVA_HOME` (gli installer JDK — es. Temurin su Windows — spesso lo impostano su
-- una versione più recente di quella lasciata nel PATH); (3) `java` dal PATH. Usiamo la
-- prima JDK >= 21 trovata (il pin è comunque validato: se è < 21 o non eseguibile si
-- scende ai fallback). Questa JVM serve solo a far girare il server; il progetto può
-- compilare con una JVM diversa configurata a parte (`java.configuration.runtimes`).
--
-- Avvio manuale con `java -jar` (non il launcher Python di Mason): così l'unica
-- dipendenza è la JDK, non anche Python.
local M = {
  "mfussenegger/nvim-jdtls",
  ft = "java",
}

local REQUIRED_JDK = 21

-- Major version di una `java.exe` (11, 17, 21...) o nil se non eseguibile/parsabile.
local function major_of(exe)
  local res = vim.system({ exe, "-version" }, { text = true }):wait()
  local out = (res.stderr or "") .. (res.stdout or "")
  -- "1.8.0_x" (legacy, Java 8) vs "21.0.1" (moderno)
  local major = out:match 'version "1%.(%d+)' or out:match 'version "(%d+)'
  return tonumber(major)
end

-- Sceglie l'eseguibile java per il server. Ritorna (exe, major): exe è nil se nessuna
-- JDK è raggiungibile; major è la migliore versione vista (per un messaggio sensato
-- anche quando è troppo vecchia). Calcolato una volta per sessione.
local jdk_exe, jdk_major, jdk_resolved
local function resolve_jdk()
  if jdk_resolved then
    return jdk_exe, jdk_major
  end
  jdk_resolved = true

  -- config solo-Windows: java.exe sotto <home>\bin
  local function exe_of(home)
    if not home or home == "" then
      return nil
    end
    local exe = (home:gsub("[/\\]$", "")) .. "\\bin\\java.exe"
    return vim.uv.fs_stat(exe) and exe or nil
  end

  local candidates = {}
  -- (1) pin macchina-specifico: vince sull'ambiente (comunque validato sotto).
  local machine = pcall(require, "user.core.machine") and require "user.core.machine" or {}
  local pinned = exe_of(machine.java_home)
  if pinned then
    table.insert(candidates, pinned)
  end
  -- (2) JAVA_HOME, (3) java nel PATH.
  local from_env = exe_of(vim.env.JAVA_HOME)
  if from_env then
    table.insert(candidates, from_env)
  end
  if vim.fn.executable "java" == 1 then
    table.insert(candidates, "java")
  end

  for _, exe in ipairs(candidates) do
    local m = major_of(exe)
    if m then
      -- ricorda la versione più alta vista, per il warning se nessuna basta
      if not jdk_major or m > jdk_major then
        jdk_major = m
      end
      if m >= REQUIRED_JDK then
        jdk_exe = exe
        return jdk_exe, jdk_major
      end
    end
  end
  return nil, jdk_major
end

local function warn_once(msg)
  if vim.g.__jdtls_warned then
    return
  end
  vim.g.__jdtls_warned = true
  vim.notify(msg, vim.log.levels.WARN, { title = "nvim-jdtls" })
end

-- eclipse.jdt.ls compila i progetti Java "plain" in una cartella `bin/` nella root.
-- Non la mettiamo nel .gitignore globale (in altri progetti `bin/` può essere codice
-- versionato): la ignoriamo solo qui, dove jdtls gira davvero, nel .git/info/exclude
-- locale del repo — non versionato, invisibile al team. Idempotente. Git ignora solo
-- i file untracked, quindi se `bin/` contiene sorgenti già tracciati restano tali.
-- (I metadati Eclipse .project/.classpath/.factorypath/.settings/ sono invece coperti
-- dal .gitignore globale, perché sono sempre artefatti rigenerabili.)
local function exclude_bin_locally(root)
  local git = vim.uv.fs_stat(root .. "/.git")
  if not git or git.type ~= "directory" then
    return -- nessun repo git standard (o worktree/submodule con .git file): niente da fare
  end
  local exclude_path = root .. "/.git/info/exclude"

  local f = io.open(exclude_path, "r")
  if f then
    for line in f:lines() do
      if line:match "^/?bin/?$" then
        f:close()
        return -- già escluso
      end
    end
    f:close()
  end

  local out = io.open(exclude_path, "a")
  if out then
    out:write "/bin/\n"
    out:close()
  end
end

local function start()
  local java, major = resolve_jdk()
  if not java then
    if not major then
      warn_once(
        ("LSP Java (jdtls) non avviato: nessuna JDK raggiungibile (né JAVA_HOME né 'java' nel PATH).\nInstalla una JDK >= %d."):format(
          REQUIRED_JDK
        )
      )
    else
      warn_once(
        ("LSP Java (jdtls) non avviato: richiede Java >= %d, la migliore trovata è Java %d.\nImposta JAVA_HOME (o il PATH) su una JDK >= %d; il progetto può usare un JDK diverso a parte."):format(
          REQUIRED_JDK,
          major,
          REQUIRED_JDK
        )
      )
    end
    return
  end

  local mason = vim.fn.stdpath "data" .. "/mason/packages/jdtls"
  local launcher = vim.fn.glob(mason .. "/plugins/org.eclipse.equinox.launcher_*.jar")
  if launcher == "" then
    -- I jar non ci sono ancora (installazione Mason non completata): riprova al
    -- prossimo BufEnter invece di partire con un cmd rotto.
    return
  end

  local root = vim.fs.root(0, { "gradlew", "mvnw", "pom.xml", "build.gradle", "build.gradle.kts", ".git" })
    or vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(root, ":p:h:t")
  local workspace_dir = vim.fn.stdpath "data" .. "/jdtls-workspace/" .. project_name

  exclude_bin_locally(root)

  local cmd = {
    java,
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.protocol=true",
    "-Dlog.level=ALL",
    "-Xmx1g",
    "--add-modules=ALL-SYSTEM",
    "--add-opens",
    "java.base/java.util=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.lang=ALL-UNNAMED",
  }

  -- lombok.jar è opzionale: lo aggiunge Mason nel pacchetto jdtls. Se manca, evita
  -- un `-javaagent` verso un file inesistente (jdtls rifiuterebbe di partire).
  local lombok = mason .. "/lombok.jar"
  if vim.uv.fs_stat(lombok) then
    table.insert(cmd, "-javaagent:" .. lombok)
  end

  vim.list_extend(cmd, {
    "-jar",
    launcher,
    "-configuration",
    mason .. "/config_win", -- config OS-specifica; questa config è solo Windows
    "-data",
    workspace_dir,
  })

  local lspconfig = require "user.lsp.lspconfig"
  require("jdtls").start_or_attach {
    cmd = cmd,
    root_dir = root,
    on_attach = lspconfig.on_attach,
    capabilities = lspconfig.common_capabilities(),
  }
end

function M.config()
  -- Aggancia i buffer Java successivi...
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("UserJdtls", { clear = true }),
    pattern = "java",
    callback = start,
  })
  -- ...e il buffer che ha appena caricato il plugin (l'autocmd FileType è già scattato).
  if vim.bo.filetype == "java" then
    start()
  end
end

return M
