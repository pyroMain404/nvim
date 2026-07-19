-- tailwindcss si attacca solo nei progetti Tailwind reali.
--
-- Il root_dir di default (nvim-data/lazy/nvim-lspconfig/lsp/tailwindcss.lua)
-- include `.git` come fallback per Tailwind v4 (dove il config file non è più
-- obbligatorio): questo però farebbe agganciare il server in QUALSIASI repo git,
-- anche non-Tailwind, aggiungendo un processo node e completion di utility class
-- ovunque. Coerente col gating di angularls (angular.json/nx.json), qui
-- restringiamo l'attach ai workspace che hanno un config Tailwind/PostCSS oppure
-- la dipendenza `tailwindcss` in package.json (che copre anche i progetti v4,
-- che quella dipendenza ce l'hanno comunque). I filetypes (html/css/js/... )
-- restano quelli del default.
local util = require "lspconfig.util"

return {
  root_dir = function(bufnr, on_dir)
    local root_files = {
      "tailwind.config.js",
      "tailwind.config.cjs",
      "tailwind.config.mjs",
      "tailwind.config.ts",
      "postcss.config.js",
      "postcss.config.cjs",
      "postcss.config.mjs",
      "postcss.config.ts",
    }
    local fname = vim.api.nvim_buf_get_name(bufnr)
    root_files = util.insert_package_json(root_files, "tailwindcss", fname)
    local found = vim.fs.find(root_files, { path = fname, upward = true })[1]
    if found then
      on_dir(vim.fs.dirname(found))
    end
  end,
}
