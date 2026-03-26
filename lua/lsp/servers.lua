-- LSP server configurations
-- Each key is a server name recognized by lspconfig
-- Capabilities are merged in plugins/lsp.lua

return {
  lua_ls = {
    settings = {
      Lua = {
        workspace = { checkThirdParty = false },
        telemetry = { enable = false },
        diagnostics = {
          globals = { "vim", "Snacks" },
        },
        completion = { callSnippet = "Replace" },
      },
    },
  },

  -- TypeScript/JavaScript via vtsls (wraps VSCode TS extension)
  vtsls = {
    filetypes = {
      "javascript", "javascriptreact",
      "typescript", "typescriptreact",
    },
    settings = {
      complete_function_calls = true,
      vtsls = {
        enableMoveToFileCodeAction = true,
        autoUseWorkspaceTsdk = true,
        experimental = {
          maxInlayHintLength = 30,
          completion = { enableServerSideFuzzyMatch = true },
        },
      },
      typescript = {
        updateImportsOnFileMove = { enabled = "always" },
        suggest = { completeFunctionCalls = true },
        inlayHints = {
          enumMemberValues = { enabled = true },
          functionLikeReturnTypes = { enabled = true },
          parameterNames = { enabled = "literals" },
          parameterTypes = { enabled = true },
          propertyDeclarationTypes = { enabled = true },
          variableTypes = { enabled = false },
        },
      },
    },
  },

  -- Angular Language Service
  angularls = {},

  -- HTML
  html = {},

  -- CSS
  cssls = {},

  -- JSON
  jsonls = {
    settings = {
      json = {
        validate = { enable = true },
      },
    },
  },

  -- YAML
  yamlls = {
    settings = {
      yaml = {
        keyOrdering = false,
      },
    },
  },

  -- ESLint
  eslint = {
    settings = {
      workingDirectories = { mode = "auto" },
    },
  },

  -- Rust
  rust_analyzer = {
    settings = {
      ["rust-analyzer"] = {
        cargo = { allFeatures = true },
        checkOnSave = { command = "clippy" },
      },
    },
  },

  -- Go
  gopls = {
    settings = {
      gopls = {
        analyses = { unusedparams = true },
        staticcheck = true,
        gofumpt = true,
      },
    },
  },
}
