local M = {
  "SmiteshP/nvim-navic",
}

function M.config()
  local icons = require "user.icons"
  require("nvim-navic").setup {
    icons = icons.kind,
    highlight = true,
    lsp = {
      auto_attach = true,
      preference = { "ts_ls" },
    },
    click = true,
    separator = " " .. icons.ui.ChevronRight .. " ",
    depth_limit = 0,
    depth_limit_indicator = "..",
  }

  -- Breadcrumb nella winbar (in cima alla finestra), separata dalla lualine.
  -- navic è solo un fornitore di dati: `auto_attach` lo collega da sé agli LSP,
  -- qui ci limitiamo ad accendere/spegnere la winbar sulle finestre giuste.
  -- L'espressione si auto-valuta a runtime; usa lo snippet raccomandato dalla doc.
  local WINBAR = "%{%v:lua.require'nvim-navic'.get_location()%}"

  local function has_symbols(buf)
    for _, c in pairs(vim.lsp.get_clients { bufnr = buf }) do
      if c:supports_method "textDocument/documentSymbol" then
        return true
      end
    end
    return false
  end

  local function refresh(win)
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      return -- finestre flottanti: niente breadcrumb
    end
    local buf = vim.api.nvim_win_get_buf(win)
    -- Non tocchiamo i buffer speciali (buftype != ""): terminali toggleterm
    -- — che hanno già la propria winbar —, nvim-tree, alpha, ecc.
    if vim.bo[buf].buftype ~= "" then
      return
    end
    vim.wo[win].winbar = has_symbols(buf) and WINBAR or ""
  end

  vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach", "BufWinEnter" }, {
    group = vim.api.nvim_create_augroup("user_navic_winbar", { clear = true }),
    callback = function(args)
      -- Rinfresca ogni finestra che mostra il buffer coinvolto.
      for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
        refresh(win)
      end
    end,
  })
end

return M
