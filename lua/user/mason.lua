local M = {
  "williamboman/mason-lspconfig.nvim",
  dependencies = {
    "williamboman/mason.nvim",
  },
}

function M.config()
  local lsp_servers = require "user.lsp_servers"
  local servers, skipped = lsp_servers.resolve()
  lsp_servers.warn_skipped(skipped)

  require("mason").setup {
    ui = {
      border = "rounded",
    },
    -- Registry aggiuntivo Crashdummyy: fornisce il pacchetto "roslyn" (server LSP C#
    -- allineato alla versione vscode), assente dal registry ufficiale mason-org.
    -- `registries` SOSTITUISCE il default, quindi mason-org va elencato esplicitamente:
    -- ometterlo romperebbe tutti gli altri pacchetti (stylua, black, gli LSP...).
    registries = {
      "github:mason-org/mason-registry",
      "github:Crashdummyy/mason-registry",
    },
  }

  require("mason-lspconfig").setup {
    ensure_installed = servers,
    -- automatic_enable abilita TUTTI i server già installati in Mason (itera su
    -- registry.get_installed_package_names(), non su ensure_installed): toglierli
    -- da ensure_installed NON basta a spegnerli finché il pacchetto resta installato.
    -- - jdtls: gestito da nvim-jdtls (user/jdtls.lua); escluderlo evita un secondo
    --   client in conflitto sui buffer java.
    -- - cssls: sostituito da somesass_ls (gestisce css/scss/sass). Il pacchetto può
    --   restare installato sulla macchina: senza questa esclusione verrebbe
    --   riabilitato e si attaccherebbe ai .css insieme a somesass_ls, con doppia
    --   diagnostica/hover.
    automatic_enable = { exclude = { "jdtls", "cssls" } },
  }

  -- tool usati da none-ls, non gestiti da mason-lspconfig, più il binario jdtls
  -- (server LSP Java gestito da nvim-jdtls). jdtls si installa solo con una JDK nel
  -- PATH: senza `java` il language server non parte comunque, quindi è spreco scaricarlo
  -- (l'avvio effettivo richiede Java 21+, controllato in user/jdtls.lua).
  -- tree-sitter-cli: binario che tree-sitter-manager (user/treesitter.lua) usa per
  -- compilare i parser; Mason lo scarica precompilato (github release) e lo mette in
  -- mason/bin sul PATH. Su questa macchina il build dei parser usa zig (unico compiler).
  local tools = { "stylua", "black", "tree-sitter-cli" }
  if vim.fn.executable "java" == 1 then
    table.insert(tools, "jdtls")
  end
  -- roslyn: server LSP C# (registry Crashdummyy), gestito da roslyn.nvim
  -- (user/roslyn.lua), NON da mason-lspconfig — perciò resta FUORI da
  -- `automatic_enable`. È un processo .NET: senza `dotnet` nel PATH non parte,
  -- quindi è spreco scaricarlo (stesso pattern di jdtls con `java`).
  if vim.fn.executable "dotnet" == 1 then
    table.insert(tools, "roslyn")
  end
  local registry = require "mason-registry"
  registry.refresh(function()
    for _, name in ipairs(tools) do
      local pkg = registry.get_package(name)
      if not pkg:is_installed() then
        pkg:install()
      end
    end
  end)
end

return M
