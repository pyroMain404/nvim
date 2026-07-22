-- Regole "all'apertura di un file": esegui un'azione quando un buffer soddisfa una
-- condizione arbitraria (nome, contenuto, filetype, client LSP attaccato, ...). Motore
-- generico e disaccoppiato — i moduli di dominio registrano le proprie regole con
-- M.add{...}, qui si fa solo il dispatch. NON è un plugin: si carica con
-- `require "user.on_open"` (init.lua), prima dei moduli che vi registrano regole.
--
-- Prima regola concreta: aprire un file *.workspace attiva quel workspace (registrata
-- da user/projects; vedi user/projects/group.lua).
--
-- Trigger: BufReadPost/BufNewFile (nome e contenuto del buffer disponibili) e LspAttach
-- (così una condizione può guardare i client LSP, che si agganciano dopo l'apertura).
-- Ogni regola scatta AL MASSIMO una volta per buffer (dedup su buf+nome regola), quindi
-- ri-valutare su più eventi è sicuro e idempotente.

local M = {}

M.rules = {} ---@type { name:string, when:fun(ctx:table):boolean, action:fun(ctx:table) }[]

-- Registra una regola. `when(ctx)` ritorna true per eseguire `action(ctx)`.
-- ctx = { buf, name (path assoluto o ""), filetype, clients() → lista client LSP }.
function M.add(rule)
  assert(type(rule) == "table" and type(rule.name) == "string", "on_open: rule.name mancante")
  assert(type(rule.when) == "function" and type(rule.action) == "function", "on_open: when/action mancanti")
  M.rules[#M.rules + 1] = rule
end

local function make_ctx(buf)
  return {
    buf = buf,
    name = vim.api.nvim_buf_get_name(buf),
    filetype = vim.bo[buf].filetype,
    clients = function()
      return vim.lsp.get_clients { bufnr = buf }
    end,
  }
end

local seen = {} ---@type table<integer, table<string, boolean>> -- [buf] = { [rulename] = true }

local function dispatch(buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  if vim.bo[buf].buftype ~= "" then
    return -- solo buffer su file reali (no terminali, help, prompt, ...)
  end
  local ctx
  for _, r in ipairs(M.rules) do
    local done = seen[buf]
    if not (done and done[r.name]) then
      ctx = ctx or make_ctx(buf)
      local ok, matched = pcall(r.when, ctx)
      if not ok then
        vim.notify("on_open[" .. r.name .. "].when: " .. tostring(matched), vim.log.levels.ERROR)
      elseif matched then
        done = done or {}
        seen[buf] = done
        done[r.name] = true
        local aok, err = pcall(r.action, ctx)
        if not aok then
          vim.notify("on_open[" .. r.name .. "].action: " .. tostring(err), vim.log.levels.ERROR)
        end
      end
    end
  end
end

function M.setup()
  local grp = vim.api.nvim_create_augroup("user_on_open", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = grp,
    callback = function(ev)
      dispatch(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = grp,
    callback = function(ev)
      dispatch(ev.buf)
    end,
  })
  -- Libera lo stato di dedup quando il buffer sparisce (i numeri di buffer si riusano).
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = grp,
    callback = function(ev)
      seen[ev.buf] = nil
    end,
  })
  -- Buffer iniziale (file passato come argomento a nvim, già letto prima di questo setup:
  -- il suo BufReadPost può essere scattato prima che l'autocmd esistesse).
  vim.schedule(function()
    dispatch(vim.api.nvim_get_current_buf())
  end)
end

M.setup()

return M
