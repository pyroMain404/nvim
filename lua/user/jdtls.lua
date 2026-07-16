-- Supporto Java tramite eclipse.jdt.ls (jdtls), gestito da nvim-jdtls invece che da
-- mason-lspconfig: jdtls vuole un client per-progetto con workspace dedicato e un
-- avvio con argomenti specifici, cosa che il flusso `vim.lsp.config` standard non
-- copre bene. Per questo jdtls NON è in `lsp_servers.lua` ed è escluso da
-- `automatic_enable` in `mason.lua` (altrimenti girerebbero due client sullo stesso
-- buffer). Il binario dei jar è installato da Mason (vedi `mason.lua`).
--
-- Guardia JDK: il language server è esso stesso un processo Java. Non basta che
-- `java` sia nel PATH: eclipse.jdt.ls è compilato per Java 21+, quindi con una JDK
-- più vecchia il client crasha all'avvio (UnsupportedClassVersionError) senza dare
-- un errore comprensibile. Perciò controlliamo la *versione*, non solo la presenza,
-- e se è insufficiente non avviamo nulla e avvisiamo una sola volta, in modo pigro
-- (solo aprendo un file Java, perché il plugin è lazy su `ft = "java"`).
--
-- Nota: questa JDK serve solo a far girare il server; il progetto può essere
-- compilato con una JVM diversa configurata a parte (impostazione `java.configuration.runtimes`).
--
-- Avvio manuale con `java -jar` (non il launcher Python di Mason): così l'unica
-- dipendenza è la JDK, non anche Python.
local M = {
  "mfussenegger/nvim-jdtls",
  ft = "java",
}

local REQUIRED_JDK = 21

-- Major di Java nel PATH (11, 17, 21...) o nil se `java` manca. Calcolato una volta.
local jdk_major, jdk_checked
local function java_major()
  if jdk_checked then
    return jdk_major
  end
  jdk_checked = true
  if vim.fn.executable "java" == 1 then
    local res = vim.system({ "java", "-version" }, { text = true }):wait()
    local out = (res.stderr or "") .. (res.stdout or "")
    -- "1.8.0_x" (legacy, Java 8) vs "21.0.1" (moderno)
    local major = out:match 'version "1%.(%d+)' or out:match 'version "(%d+)'
    jdk_major = tonumber(major)
  end
  return jdk_major
end

local function warn_once(msg)
  if vim.g.__jdtls_warned then
    return
  end
  vim.g.__jdtls_warned = true
  vim.notify(msg, vim.log.levels.WARN, { title = "nvim-jdtls" })
end

local function start()
  local major = java_major()
  if not major then
    warn_once(("LSP Java (jdtls) non avviato: 'java' non è nel PATH.\nInstalla una JDK >= %d."):format(REQUIRED_JDK))
    return
  end
  if major < REQUIRED_JDK then
    warn_once(
      ("LSP Java (jdtls) non avviato: richiede Java >= %d, trovato Java %d.\nAggiorna la JDK nel PATH (il progetto può usare un JDK diverso a parte)."):format(
        REQUIRED_JDK,
        major
      )
    )
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

  local cmd = {
    "java",
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

  local lspconfig = require "user.lspconfig"
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
