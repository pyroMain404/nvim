-- Supporto C#/.NET (progetti Unity inclusi) tramite il language server Roslyn
-- (Microsoft.CodeAnalysis.LanguageServer), gestito da seblyng/roslyn.nvim invece
-- che da mason-lspconfig: roslyn.nvim risolve da sé il target (soluzione/progetto)
-- e abilita il client, cosa che il flusso `vim.lsp.config` + `automatic_enable`
-- non copre. Per questo "roslyn" NON è in lsp_servers.lua ed è quindi già FUORI da
-- `automatic_enable`; il pacchetto Mason "roslyn" (registry Crashdummyy) si installa
-- dalla lista `tools` in mason.lua, guardato su `dotnet`.
--
-- Il server è un processo .NET: senza `dotnet` nel PATH non parte. Guardiamo il
-- caricamento del plugin su quella precondizione (`cond`) e, se manca, avvisiamo in
-- modo pigro aprendo un file C# (coerente con la filosofia dei warning: visibile,
-- non silenziato, solo quando è un problema reale).
--
-- Orientato ai progetti Unity:
--   broad_search = true  -> cerca la .sln anche nelle sottocartelle: Unity genera
--                           la soluzione accanto ad Assets/, non sempre nella root
--                           da cui si apre nvim.
--   lock_target  = true  -> dopo il primo attach fissa la soluzione scelta, così il
--                           cambio buffer non ri-avvia la scelta del target.

local function has_dotnet()
  return vim.fn.executable "dotnet" == 1
end

-- Avviso pigro se manca dotnet. Registrato al caricamento del modulo (lo `spec` in
-- init.lua richiede questo file all'avvio), scatta una sola volta aprendo un buffer
-- C#. È indipendente da `cond` (che impedisce del tutto il caricamento del plugin),
-- così l'assenza del server non resta silenziosa.
if not has_dotnet() then
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "cs",
    once = true,
    callback = function()
      vim.notify(
        "LSP C# (roslyn) non avviato: 'dotnet' non è nel PATH.\nInstalla il .NET SDK e riapri il terminale.",
        vim.log.levels.WARN,
        { title = "roslyn.nvim" }
      )
    end,
  })
end

local M = {
  "seblyng/roslyn.nvim",
  branch = "main",
  ft = "cs",
  cond = has_dotnet,
}

function M.config()
  -- Aggancia il client Roslyn agli stessi on_attach/capabilities condivisi (keymap
  -- LSP, inlay hints) usati dagli altri server. roslyn.nvim legge e fonde
  -- vim.lsp.config("roslyn", ...) quando abilita il client.
  local lspconfig = require "user.lspconfig"
  vim.lsp.config("roslyn", {
    on_attach = lspconfig.on_attach,
    capabilities = lspconfig.common_capabilities(),
  })

  require("roslyn").setup {
    broad_search = true,
    lock_target = true,
  }
end

return M
