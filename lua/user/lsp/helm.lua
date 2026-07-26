-- Rileva il filetype "helm" per i chart Helm (templates/*.yaml, values.yaml
-- ecc. accanto a un Chart.yaml) e fornisce l'evidenziazione sintattica: senza
-- questo, i file restano semplice "yaml" e helm_ls (lspconfig.lua) non si
-- attacca mai, perché richiede esplicitamente i filetype "helm"/"yaml.helm-values".
local M = {
  "towolf/vim-helm",
}

return M
