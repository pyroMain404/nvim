return {
  "nvim-treesitter/nvim-treesitter",
  -- Must load eagerly: Neovim 0.12 triggers ftplugins that use treesitter
  -- before BufReadPost fires, causing "Parser could not be created" errors.
  lazy = false,
  priority = 800,
  build = ":TSUpdate",
  cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
  opts = {
    -- Neovim 0.12 ships these parsers bundled — do NOT re-install them:
    -- bash, c, lua, markdown, markdown_inline, python, query, regex, toml, vim, vimdoc
    ensure_installed = {
      -- Web
      "html", "css", "javascript", "typescript", "tsx",
      -- Backend
      "java", "rust", "go", "cpp",
      -- Config / Data
      "json", "yaml", "xml",
      -- Tools
      "dockerfile", "git_config", "gitcommit", "gitignore",
    },
    -- Don't reinstall parsers already bundled with Neovim
    ignore_install = {
      "bash", "c", "lua", "markdown", "markdown_inline",
      "python", "query", "regex", "toml", "vim", "vimdoc",
    },
    highlight = { enable = true },
    indent = { enable = true },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection    = "<C-space>",
        node_incremental  = "<C-space>",
        scope_incremental = false,
        node_decremental  = "<BS>",
      },
    },
  },
  config = function(_, opts)
    require("nvim-treesitter").setup(opts)
  end,
}
