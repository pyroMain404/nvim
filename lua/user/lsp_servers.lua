-- Elenco centralizzato dei server LSP gestiti da mason-lspconfig, condiviso da
-- mason.lua (ensure_installed) e lspconfig.lua (vim.lsp.config). Alcuni pacchetti
-- Mason delegano la build a un toolchain di sistema (es. gopls richiede il
-- compilatore Go): se manca, mason-lspconfig ritenterebbe l'installazione ad
-- ogni avvio fallendo sempre. Per evitarlo, il server viene escluso finché il
-- prerequisito non compare nel PATH: nessun errore, nessun retry inutile, e
-- torna disponibile in automatico al riavvio successivo all'installazione del
-- prerequisito.
--
-- Il warning sui server saltati NON viene mostrato all'avvio: sarebbe rumore per
-- chi non lavora in quel linguaggio. Viene invece emesso in modo pigro solo
-- quando si apre un buffer che quel server avrebbe servito (campo `filetypes`,
-- eventualmente ristretto a un workspace via `root_markers`).
local M = {}

-- Ogni voce può dichiarare:
--   requires    = eseguibile richiesto sul PATH per installare/eseguire il server
--                 (nil = nessun prerequisito, Mason scarica un binario precompilato)
--   filetypes   = filetype che il server servirebbe (dal campo `filetypes` di
--                 nvim-lspconfig, in `nvim-data/lazy/nvim-lspconfig/lsp/<s>.lua`):
--                 gate per il warning pigro. Va dichiarato per i server con
--                 `requires`, altrimenti il warning ricade all'avvio.
--   root_markers = se presente, il warning scatta solo dentro un workspace che
--                 contiene uno di questi marker risalendo dalle cartelle padre;
--                 serve per i server che condividono filetype comuni (es.
--                 angularls su typescript/html) per non avvisare ovunque.
local all_servers = {
  { name = "lua_ls" },
  -- somesass_ls (Some Sass) SOSTITUISCE cssls: gestisce scss/sass E css con lo
  -- stesso feature set di vscode-css-language-server (completion, hover,
  -- diagnostica, colori — "Its feature set matches that of vscode-css-language-server"),
  -- aggiungendoci la navigazione workspace-wide su variabili/mixin/@use/@forward.
  -- Il default nvim-lspconfig registra solo scss/sass: il css va aggiunto ai
  -- filetypes (lspsettings/somesass_ls.lua). NON copre less (cssls sì): se un
  -- domani serve, reintrodurre cssls ristretto a filetypes = { "less" }.
  { name = "somesass_ls" },
  -- tailwindcss: hover/completion/color-swatch sulle utility class. Il default
  -- root_dir usa `.git` come fallback (Tailwind v4) → si attaccherebbe in OGNI
  -- repo git; lspsettings/tailwindcss.lua lo restringe ai progetti Tailwind veri
  -- (config file o dipendenza tailwindcss in package.json), come il gating di angularls.
  { name = "tailwindcss" },
  { name = "html" },
  { name = "ts_ls" },
  { name = "eslint" },
  { name = "pyright" },
  { name = "bashls" },
  { name = "jsonls" },
  { name = "yamlls" },
  { name = "rust_analyzer" },
  { name = "clangd" },
  { name = "gopls", requires = "go", filetypes = { "go", "gomod", "gowork", "gotmpl" } },
  { name = "dockerls", requires = "npm", filetypes = { "dockerfile" } },
  { name = "docker_compose_language_service", requires = "npm", filetypes = { "yaml.docker-compose" } },
  { name = "helm_ls" },
  -- pacchetto Mason npm:@angular/language-server; si attacca solo dentro
  -- workspace con angular.json/nx.json (root_markers in nvim-lspconfig),
  -- quindi non interferisce con progetti TS/JS non Angular. Per lo stesso
  -- motivo il warning è ristretto a quei workspace.
  {
    name = "angularls",
    requires = "npm",
    filetypes = { "typescript", "html", "typescriptreact", "htmlangular" },
    root_markers = { "angular.json", "nx.json" },
  },
}

--- @return string[] servers, table[] skipped (voci di all_servers saltate)
function M.resolve()
  local servers, skipped = {}, {}
  for _, s in ipairs(all_servers) do
    if not s.requires or vim.fn.executable(s.requires) == 1 then
      table.insert(servers, s.name)
    else
      table.insert(skipped, s)
    end
  end
  return servers, skipped
end

--- Registra i warning pigri per i server saltati per prerequisiti mancanti.
--- Una sola volta per sessione (mason.lua e lspconfig.lua chiamano entrambi
--- resolve()). Ogni server viene segnalato al massimo una volta, quando si apre
--- un buffer che lo avrebbe attivato.
function M.warn_skipped(skipped)
  if #skipped == 0 or vim.g.__lsp_servers_warned then
    return
  end
  vim.g.__lsp_servers_warned = true

  local warned = {}

  local function warn(s)
    if warned[s.name] then
      return
    end
    warned[s.name] = true
    vim.notify(
      ("LSP non installato per prerequisito mancante:\n- %s (richiede '%s' nel PATH)"):format(s.name, s.requires),
      vim.log.levels.WARN,
      { title = "mason-lspconfig" }
    )
  end

  -- Avvisa per un server solo se il buffer lo avrebbe attivato: filetype giusto
  -- e, quando il server richiede un workspace, un root marker nelle cartelle padre.
  local function maybe_warn(s, buf)
    if warned[s.name] or not s.filetypes then
      return
    end
    if not vim.tbl_contains(s.filetypes, vim.bo[buf].filetype) then
      return
    end
    if s.root_markers then
      local name = vim.api.nvim_buf_get_name(buf)
      local from = name ~= "" and vim.fs.dirname(name) or vim.uv.cwd()
      if not vim.fs.find(s.root_markers, { upward = true, path = from })[1] then
        return
      end
    end
    warn(s)
  end

  local group = vim.api.nvim_create_augroup("LspServersSkippedWarn", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(args)
      for _, s in ipairs(skipped) do
        maybe_warn(s, args.buf)
      end
    end,
  })

  -- Server senza filetypes dichiarati: non c'è un trigger pigro, avvisa subito
  -- (comportamento storico). E copri i buffer già aperti prima di questo autocmd.
  for _, s in ipairs(skipped) do
    if not s.filetypes then
      warn(s)
    end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      for _, s in ipairs(skipped) do
        maybe_warn(s, buf)
      end
    end
  end
end

return M
