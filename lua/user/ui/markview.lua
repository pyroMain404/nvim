local M = {
  "OXY2DEV/markview.nvim",
  -- Anche "AgenticChat": il buffer chat di agentic.nvim è filetype AgenticChat
  -- (col parser treesitter markdown già registrato), non "markdown" → senza
  -- questo ft markview non si caricherebbe mai aprendo la chat.
  ft = { "markdown", "AgenticChat" },
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
}

function M.config()
  require("markview").setup {
    -- preview disabilitato di default: il buffer sorgente resta grezzo
    -- (coerente con conceallevel = 0 in options.lua). Il rendering avviene
    -- solo nel buffer laterale dello splitview, aperto a richiesta.
    preview = {
      enable = false,
      splitview_winopts = { split = "right" },
      -- Di default markview renderizza solo in { "n", "no", "c" }: appena passi
      -- a insert (per scrivere nel prompt) o a visual (per selezionare nella
      -- chat), il ModeChanged globale fa clear() su TUTTI i buffer enabled →
      -- la chat perde il rendering (header senza sfondo, allineati a sinistra).
      -- Aggiungo insert e visual così il preview della chat resta stabile
      -- mentre digiti nel prompt o selezioni testo. hybrid_modes resta vuoto:
      -- la chat è output da leggere, non la si edita → niente smascheramento
      -- attorno al cursore. Tocca di fatto solo AgenticChat, l'unico buffer
      -- enabled (tutto il resto ha preview.enable = false).
      modes = { "n", "no", "c", "i", "v", "V" },
    },
  }

  -- La chat di agentic è output da LEGGERE, non sorgente da editare: lì il
  -- markdown va renderizzato SEMPRE, non on-demand come i .md normali. Con
  -- preview.enable = false markview non attacca né abilita alcun buffer da
  -- solo (il buffer chat è per giunta `buftype = "nofile"`, scartato di
  -- default): qui lo attacchiamo E ne abilitiamo il preview a mano, solo per
  -- il filetype AgenticChat, lasciando grezzo tutto il resto. FileType scatta
  -- a ogni (ri)creazione del buffer chat. attach() è idempotente (no-op se già
  -- agganciato); enable() forza enable=true per QUEL buffer.
  --
  -- Il redraw automatico però NON basta: agentic scrive la chat con
  -- nvim_buf_set_lines (API), che non emette TextChanged: markview non
  -- ridisegnerebbe i blocchi (code block, heading, hrule) aggiunti in streaming
  -- finché non sposti il cursore o rifocalizzi la finestra (è il "prima/dopo il
  -- focus" incoerente). nvim_buf_attach ci notifica anche le modifiche via API:
  -- a ogni cambio forziamo un render dell'intero buffer (commands.render →
  -- actions.render, indipendente da cursore/mode), debounced per non pesare
  -- sui tanti chunk dello streaming.
  local group = vim.api.nvim_create_augroup("user_markview_agentic", { clear = true })

  -- Nasconde i marcatori markdown (#, **, `) nella chat, come <leader>mm su un
  -- .md. Il conceal degli extmark di markview richiede conceallevel >= 1 sulla
  -- FINESTRA (opzione window-local), ma il default globale è 0 (options.lua) e
  -- il on_enable di markview qui non lo imposta in modo affidabile. concealcursor
  -- = "nvic" combacia con preview.modes → marcatori nascosti anche sotto il
  -- cursore (la chat è da leggere, non da editare).
  local function apply_conceal(buf)
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      vim.wo[win].conceallevel = 3
      vim.wo[win].concealcursor = "nvic"
    end
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "AgenticChat",
    callback = function(args)
      local buf = args.buf
      local mv = require "markview"
      mv.commands.attach(buf)
      mv.commands.enable(buf)

      -- conceallevel è window-local: all'apertura iniziale la finestra della chat
      -- può non esistere ancora qui, e lazy (che carica markview su ft=AgenticChat)
      -- ri-emette FileType ma NON BufWinEnter → l'autocmd sotto non scatterebbe.
      -- Applichiamo perciò sia ora sia sul tick successivo, a finestra pronta.
      apply_conceal(buf)
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          apply_conceal(buf)
        end
      end)

      -- FileType può riscattare sullo stesso buffer: un solo hook per buffer.
      if vim.b[buf].markview_agentic_hooked then
        return
      end
      vim.b[buf].markview_agentic_hooked = true

      local timer = assert(vim.uv.new_timer())
      local function schedule_render()
        timer:stop()
        timer:start(
          75,
          0,
          vim.schedule_wrap(function()
            if vim.api.nvim_buf_is_valid(buf) then
              pcall(mv.commands.render, buf)
            end
          end)
        )
      end

      vim.api.nvim_buf_attach(buf, false, {
        on_lines = schedule_render,
        on_reload = schedule_render,
        on_detach = function()
          if not timer:is_closing() then
            timer:stop()
            timer:close()
          end
        end,
      })
    end,
  })

  -- Rientri successivi nella finestra della chat (cambio finestra / riapertura).
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(args)
      if vim.bo[args.buf].filetype == "AgenticChat" then
        apply_conceal(args.buf)
      end
    end,
  })

  local wk = require "which-key"
  wk.add {
    { "<leader>m", group = "Markdown" },
    { "<leader>ms", "<cmd>Markview splitToggle<cr>", desc = "Split preview" },
    { "<leader>mm", "<cmd>Markview toggle<cr>", desc = "Toggle inline preview" },
  }
end

return M
