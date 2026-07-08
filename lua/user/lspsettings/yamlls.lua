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
    },
  },
}
