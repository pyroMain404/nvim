return {
  -- Mason: LSP/DAP/Linter/Formatter installer
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    opts = {
      ui = { border = "rounded" },
    },
  },

  -- mason-lspconfig: installs servers and auto-enables via vim.lsp
  -- NOTE: nvim-lspconfig is NOT a dependency — using vim.lsp.config natively (Neovim 0.11+)
  {
    "williamboman/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "saghen/blink.cmp",
    },
    config = function()
      -- Diagnostic UI
      vim.diagnostic.config({
        virtual_text = { spacing = 4, prefix = "●" },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = { border = "rounded", source = true },
      })

      -- LspAttach keymaps
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_attach_keymaps", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
          end
          map("K",          vim.lsp.buf.hover,                    "Hover")
          map("<leader>ca", vim.lsp.buf.code_action,              "Code action")
          map("<leader>cr", vim.lsp.buf.rename,                   "Rename")
          map("<leader>cd", vim.diagnostic.open_float,            "Line diagnostics")
          map("[d",         vim.diagnostic.goto_prev,             "Prev diagnostic")
          map("]d",         vim.diagnostic.goto_next,             "Next diagnostic")
          map("<leader>cf", function()
            vim.lsp.buf.format({ async = true })
          end, "Format")
        end,
      })

      -- Global capabilities (applied to every server via '*')
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      -- Per-server configs (vim.lsp.config merges with '*')
      local servers = require("lsp.servers")
      for server, config in pairs(servers) do
        vim.lsp.config(server, config)
      end

      -- Install servers and auto-enable them via vim.lsp.enable
      require("mason-lspconfig").setup({
        ensure_installed = vim.tbl_keys(servers),
        automatic_enable = true,
      })
    end,
  },

  -- Java LSP (configured via ftplugin/java.lua, not mason-lspconfig)
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
  },
}
