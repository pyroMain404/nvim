-- https://github.com/mrjosh/helm-ls
-- helm_ls delega la validazione YAML a yaml-language-server (installato via
-- mason, e già in PATH grazie a mason.nvim) per avere schema/hover anche
-- dentro i template Helm.
return {
  settings = {
    ["helm-ls"] = {
      yamlls = {
        path = "yaml-language-server",
      },
    },
  },
}
