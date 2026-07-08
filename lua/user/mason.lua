local M = {
  "williamboman/mason-lspconfig.nvim",
  dependencies = {
    "williamboman/mason.nvim",
  },
}

function M.config()
  local servers = {
    "lua_ls",
    "cssls",
    "html",
    "ts_ls",
    "eslint",
    "pyright",
    "bashls",
    "jsonls",
    "yamlls",
  }

  require("mason").setup {
    ui = {
      border = "rounded",
    },
  }

  require("mason-lspconfig").setup {
    ensure_installed = servers,
  }

  -- tool usati da none-ls, non gestiti da mason-lspconfig
  local tools = { "stylua", "black" }
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
