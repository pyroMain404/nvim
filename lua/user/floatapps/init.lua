local M = {}

-- Single source of truth per le TUI aperte in un terminale flottante toggleabile
-- (lazygit, lazydocker, ...). Aggiungere una app = aggiungere una riga qui:
--   * il keymap si registra SOLO se l'eseguibile e' nel PATH (silently-continue,
--     nessun notify allo startup se manca), stessa filosofia della guardia LSP;
--   * lo stato di ogni voce (installata o no) e' riportato da
--     `:checkhealth user.floatapps` (vedi health.lua), cosi' anche le app non
--     installate restano scopribili senza sporcare which-key con voci morte.
-- Altre candidate facili da aggiungere: gh dash ("gh dash", serve l'estensione),
-- atac, serpl, dust/ncdu, broot, harlequin.
M.apps = {
  { key = "<leader>og", cmd = "lazygit", desc = "lazygit" },
  { key = "<leader>od", cmd = "lazydocker", desc = "lazydocker" },
  { key = "<leader>os", cmd = "lazysql", desc = "lazysql" },
  { key = "<leader>op", cmd = "posting", desc = "posting" },
  { key = "<leader>oj", cmd = "jqp", desc = "jqp" },
  { key = "<leader>ob", cmd = "btop", desc = "btop" },
  { key = "<leader>of", cmd = "yazi", desc = "yazi" },
  { key = "<leader>ou", cmd = "gdu", desc = "gdu" },
  { key = "<leader>ok", cmd = "k9s", desc = "k9s" },
}

-- Cache dei Terminal per comando: ogni app ha il suo float persistente che il
-- keymap apre/chiude (toggle) invece di crearne uno nuovo ogni volta.
local terminals = {}

function M.toggle(cmd)
  local term = terminals[cmd]
  if not term then
    local Terminal = require("toggleterm.terminal").Terminal
    term = Terminal:new { cmd = cmd, direction = "float", hidden = true }
    terminals[cmd] = term
  end
  term:toggle()
end

-- Registra i keymap sotto <leader>o. Chiamata dal config di toggleterm (VeryLazy),
-- cosi' toggleterm e' gia' disponibile quando si preme la scorciatoia.
function M.setup_keymaps()
  for _, app in ipairs(M.apps) do
    local exe = app.cmd:match "%S+"
    if vim.fn.executable(exe) == 1 then
      -- Solo modalita' normale: registrarli anche in "t" (terminale) fa attendere
      -- `timeoutlen` a ogni <Space> digitato in insert-terminal, perche' il leader
      -- e' <Space> e nvim non sa se stai componendo <leader>o... — vedi keymap sotto <leader>o.
      vim.keymap.set("n", app.key, function()
        M.toggle(app.cmd)
      end, { desc = app.desc, noremap = true, silent = true })
    end
  end
end

return M
