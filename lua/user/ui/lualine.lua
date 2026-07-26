local M = {
  "nvim-lualine/lualine.nvim",
  dependencies = {
    "AndreM222/copilot-lualine",
  },
}

function M.config()
  -- Indicatore dei job in background: "▶ N" quando ce n'è almeno uno attivo,
  -- vuoto altrimenti. Il dettaglio/controllo è nel pannello <leader>oo.
  local function jobs_indicator()
    local ok, jobs = pcall(require, "user.workflow.jobs")
    if not ok then
      return ""
    end
    local n = jobs.running()
    return n > 0 and ("▶ " .. n) or ""
  end

  require("lualine").setup {
    options = {
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
      ignore_focus = { "NvimTree" },
      -- Le finestre di agentic.nvim disegnano da sé i propri titoli/decorazioni:
      -- lualine non deve sovrascriverle (vedi README di agentic, sezione Lualine).
      disabled_filetypes = {
        statusline = { "AgenticChat", "AgenticInput", "AgenticCode", "AgenticFiles", "AgenticDiagnostics" },
        winbar = { "AgenticChat", "AgenticInput", "AgenticCode", "AgenticFiles", "AgenticDiagnostics" },
      },
    },
    sections = {
      lualine_a = {},
      lualine_b = { "branch" },
      lualine_c = { "diagnostics" },
      lualine_x = {
        { jobs_indicator, color = { fg = "#7dcfff", gui = "bold" } },
        "copilot",
        "filetype",
      },
      lualine_y = { "progress" },
      lualine_z = {},
    },
    extensions = { "quickfix", "man", "fugitive" },
  }
end

return M
