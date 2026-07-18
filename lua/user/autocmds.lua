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
  callback = function(args)
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
    -- default sarebbe "en": senza questo ogni parola italiana risulta errata.
    vim.opt_local.spelllang = { "it", "en" }

    -- Etichette which-key per i comandi spell builtin, solo in questi buffer
    -- (dove lo spell è attivo). Sono voci "solo desc": senza rhs which-key non
    -- rimappa il tasto (vedi mappings.lua), aggiunge solo il nome nel popup.
    -- Guard per-buffer: lazy.nvim ri-emette FileType quando carica un plugin
    -- con ft= (markview su markdown), altrimenti registreremmo i doppioni.
    local ok, wk = pcall(require, "which-key")
    if ok and not vim.b[args.buf].spell_wk_labeled then
      vim.b[args.buf].spell_wk_labeled = true
      wk.add {
        { "zg", desc = "Spell: aggiungi al dizionario", buffer = args.buf },
        { "zw", desc = "Spell: marca come errata", buffer = args.buf },
        { "zG", desc = "Spell: aggiungi (solo sessione)", buffer = args.buf },
        { "zug", desc = "Spell: annulla aggiunta", buffer = args.buf },
        { "zuw", desc = "Spell: annulla marcatura", buffer = args.buf },
        { "z=", desc = "Spell: suggerimenti", buffer = args.buf },
        { "]s", desc = "Spell: errore successivo", buffer = args.buf },
        { "[s", desc = "Spell: errore precedente", buffer = args.buf },
      }
    end
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
-- Grafana Alloy (.alloy): nessun LSP disponibile e nessun parser treesitter
-- dedicato. La sintassi deriva da HCL/River, quindi mappiamo al filetype "hcl"
-- per un'evidenziazione approssimativa (il parser hcl è in treesitter.lua).
-- Non è semantica: niente diagnostica/completion, solo highlight.
-- Shader Unity. HLSL puro (.hlsl/.hlsli) e gli include/compute di Unity (.cginc CG/HLSL,
-- .compute compute shader): filetype "hlsl", highlight via il parser treesitter hlsl
-- (treesitter.lua). ShaderLab (.shader) è il wrapper dichiarativo di Unity: il builtin
-- lo rileva come "gdshader" (Godot, errato), qui lo forziamo a "shaderlab" (highlight
-- approssimativo via grammatica hlsl, vedi treesitter.lua). vim.filetype.add ha priorità
-- sul rilevamento di default.
vim.filetype.add {
  extension = {
    alloy = "hcl",
    hlsl = "hlsl",
    hlsli = "hlsl",
    cginc = "hlsl",
    compute = "hlsl",
    shader = "shaderlab",
  },
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

-- Nel runtime non esiste un ftplugin per hlsl/shaderlab: senza commentstring il
-- commento C-style (gc / mini.comment) non funzionerebbe. Lo impostiamo a mano.
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "hlsl", "shaderlab" },
  callback = function()
    vim.bo.commentstring = "// %s"
  end,
})

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
