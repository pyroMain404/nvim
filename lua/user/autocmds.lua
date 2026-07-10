vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  callback = function()
    vim.cmd "set formatoptions-=cro"
  end,
})

vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = {
    "netrw",
    "Jaq",
    "qf",
    "git",
    "help",
    "man",
    "lspinfo",
    "oil",
    "spectre_panel",
    "lir",
    "DressingSelect",
    "tsplayground",
    "",
  },
  callback = function()
    vim.cmd [[
      nnoremap <silent> <buffer> q :close<CR>
      set nobuflisted
    ]]
  end,
})

vim.api.nvim_create_autocmd({ "CmdWinEnter" }, {
  callback = function()
    vim.cmd "quit"
  end,
})

vim.api.nvim_create_autocmd({ "VimResized" }, {
  callback = function()
    vim.cmd "tabdo wincmd ="
  end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  pattern = { "!vim" },
  callback = function()
    vim.cmd "checktime"
  end,
})

vim.api.nvim_create_autocmd({ "TextYankPost" }, {
  callback = function()
    vim.highlight.on_yank { higroup = "Visual", timeout = 40 }
  end,
})

vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "gitcommit", "markdown", "NeogitCommitMessage" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- filetype "yaml.docker-compose": senza, sia yamlls (schema dedicato) sia
-- docker_compose_language_service (che lo richiede esplicitamente) trattano
-- il file come yaml generico.
--
-- filetype "helm" / "yaml.helm-values": necessari perché helm_ls (lspconfig.lua)
-- si attacca solo a questi filetype. Il plugin towolf/vim-helm (usato per
-- l'evidenziazione sintattica) fornisce anche un proprio ftdetect ma è
-- inaffidabile qui: usa '/' come separatore e su Windows expand("%:p") ritorna
-- '\', quindi "templates/*.yaml" non viene mai riconosciuto; per "values*.yaml"
-- perde inoltre la race con il rilevamento nativo (setfiletype è no-op se il
-- filetype è già stato assegnato). vim.filetype.add ha priorità sui matcher di
-- default e Neovim normalizza sempre il path con '/' anche su Windows, quindi
-- qui funziona in modo affidabile.
vim.filetype.add {
  pattern = {
    [".*docker%-compose.*%.ya?ml"] = "yaml.docker-compose",
    [".*compose%.ya?ml"] = "yaml.docker-compose",
    [".*/templates/.*%.ya?ml"] = "helm",
    [".*/templates/.*%.tpl"] = "helm",
    [".*/values.*%.ya?ml"] = function(path)
      local dir = vim.fs.dirname(path)
      if vim.fs.find("Chart.yaml", { path = dir, upward = true, limit = 1 })[1] then
        return "yaml.helm-values"
      end
    end,
  },
}

vim.api.nvim_create_autocmd({ "CursorHold" }, {
  callback = function()
    local status_ok, luasnip = pcall(require, "luasnip")
    if not status_ok then
      return
    end
    if luasnip.expand_or_jumpable() then
      -- ask maintainer for option to make this silent
      -- luasnip.unlink_current()
      vim.cmd [[silent! lua require("luasnip").unlink_current()]]
    end
  end,
})
