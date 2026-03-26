-- nvim-jdtls configuration (loaded automatically for .java files)
local jdtls = require("jdtls")

local mason_registry = require("mason-registry")
local jdtls_path = mason_registry.get_package("jdtls"):get_install_path()

local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_name

-- Detect OS for config
local os_config = "linux"
if vim.fn.has("mac") == 1 then
  os_config = "mac"
elseif vim.fn.has("win32") == 1 then
  os_config = "win"
end

local config = {
  cmd = {
    "java",
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.protocol=true",
    "-Dlog.level=ALL",
    "-Xmx2g",
    "--add-modules=ALL-SYSTEM",
    "--add-opens", "java.base/java.util=ALL-UNNAMED",
    "--add-opens", "java.base/java.lang=ALL-UNNAMED",
    "-jar", vim.fn.glob(jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar"),
    "-configuration", jdtls_path .. "/config_" .. os_config,
    "-data", workspace_dir,
  },

  root_dir = require("jdtls.setup").find_root({ ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }),

  settings = {
    java = {
      signatureHelp = { enabled = true },
      contentProvider = { preferred = "fernflower" },
      completion = {
        favoriteStaticMembers = {
          "org.junit.Assert.*",
          "org.junit.jupiter.api.Assertions.*",
          "org.mockito.Mockito.*",
          "java.util.Objects.requireNonNull",
          "java.util.Objects.requireNonNullElse",
        },
        filteredTypes = {
          "com.sun.*",
          "io.micrometer.shaded.*",
          "java.awt.*",
          "jdk.*",
          "sun.*",
        },
      },
      sources = {
        organizeImports = {
          starThreshold = 9999,
          staticStarThreshold = 9999,
        },
      },
      codeGeneration = {
        toString = {
          template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
        },
        useBlocks = true,
      },
      configuration = {
        -- Adjust runtimes for your installed JDKs
        runtimes = {
          { name = "JavaSE-17", path = vim.fn.expand("~/.sdkman/candidates/java/17-open/") },
          { name = "JavaSE-21", path = vim.fn.expand("~/.sdkman/candidates/java/21-open/") },
        },
      },
    },
  },

  init_options = {
    bundles = {},
  },

  on_attach = function(_, bufnr)
    local map = function(keys, func, desc)
      vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "JDTLS: " .. desc })
    end
    map("<leader>co", jdtls.organize_imports, "Organize imports")
    map("<leader>cv", jdtls.extract_variable, "Extract variable")
    map("<leader>cc", jdtls.extract_constant, "Extract constant")
    map("<leader>ct", jdtls.test_nearest_method, "Test nearest method")
    map("<leader>cT", jdtls.test_class, "Test class")
    vim.keymap.set("v", "<leader>cm", function()
      jdtls.extract_method(true)
    end, { buffer = bufnr, desc = "JDTLS: Extract method" })
  end,
}

-- Resolve debug/test bundles if mason packages are installed
local bundles = {}
local java_debug_path = mason_registry.get_package("java-debug-adapter"):get_install_path()
local java_debug_bundle = vim.fn.glob(java_debug_path .. "/extension/server/com.microsoft.java.debug.plugin-*.jar", true)
if java_debug_bundle ~= "" then
  table.insert(bundles, java_debug_bundle)
end

local java_test_path = mason_registry.get_package("java-test"):get_install_path()
local java_test_bundles = vim.split(
  vim.fn.glob(java_test_path .. "/extension/server/*.jar", true),
  "\n"
)
for _, bundle in ipairs(java_test_bundles) do
  if bundle ~= "" then
    table.insert(bundles, bundle)
  end
end

config.init_options.bundles = bundles

jdtls.start_or_attach(config)
