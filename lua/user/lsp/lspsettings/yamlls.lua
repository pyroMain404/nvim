return {
  settings = {
    yaml = {
      schemaStore = {
        -- disabilitato: gli schemi arrivano da schemastore.nvim (lista aggiornata)
        enable = false,
        url = "",
      },
      schemas = require("schemastore").yaml.schemas(),
      validate = true,
      hover = true,
      completion = true,
      -- rilevamento automatico dei manifest Kubernetes (basato su apiVersion/kind,
      -- non sul nome file) per validare deployment/service/configmap ecc.
      kubernetes = true,
    },
  },
}
