-- Debug Adapter Protocol (nvim-dap) con adapter per l'ATTACH a un editor Unity in
-- esecuzione. Unity non si "lancia" dal debugger: si attacca al Mono/soft-debugger
-- dell'editor già aperto. L'adapter usato è "vstuc" (Visual Studio Tools for Unity),
-- eseguito via `dotnet` sul dll dell'estensione; l'endpoint (host:porta) del
-- debugger Unity si scopre con UnityAttachProbe.dll dello stesso pacchetto.
--
-- I dll dell'adapter NON sono ridistribuibili qui: arrivano dall'estensione VS Code
-- "Visual Studio Tools for Unity" (id visualstudiotoolsforunity.vstuc). Li risolviamo
-- a runtime da posizioni note (o da machine.vstuc_dir / vim.g.vstuc_dir); se non ci sono, l'adapter non
-- viene registrato e l'attach avvisa in modo pigro invece di rompersi all'avvio.
-- Prerequisito comune: `dotnet` nel PATH (lo stesso di roslyn, user/roslyn.lua).

local M = {
  "mfussenegger/nvim-dap",
  dependencies = {
    -- UI a pannelli (scopes/stack/breakpoints/repl) + libreria async richiesta
    { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
    -- valori delle variabili inline come virtual text durante il debug
    "theHamsta/nvim-dap-virtual-text",
  },
  -- Caricato aprendo un file C#: l'unico adapter configurato è Unity/C#, e da un
  -- buffer C# si fa l'attach. Le keymap generiche di debug (breakpoint, step...) e la
  -- UI restano comunque utili in quel contesto.
  ft = "cs",
}

-- Cerca la cartella `bin/` dell'estensione vstuc, che contiene sia
-- "Visual Studio Tools for Unity.dll" (l'adapter) sia "UnityAttachProbe.dll".
-- Ordine: override runtime `vim.g.vstuc_dir` -> pin macchina-specifico
-- `machine.vstuc_dir` (user/machine.lua) -> estensioni VS Code (stable/insiders/server).
local function find_vstuc_dir()
  if vim.g.vstuc_dir and vim.uv.fs_stat(vim.g.vstuc_dir) then
    return vim.g.vstuc_dir
  end
  local machine = pcall(require, "user.machine") and require "user.machine" or {}
  if machine.vstuc_dir and vim.uv.fs_stat(machine.vstuc_dir) then
    return machine.vstuc_dir
  end
  local home = vim.uv.os_homedir()
  local ext_roots = {
    home .. "/.vscode/extensions",
    home .. "/.vscode-insiders/extensions",
    home .. "/.vscode-server/extensions",
  }
  for _, root in ipairs(ext_roots) do
    -- id: visualstudiotoolsforunity.vstuc-<versione>; prendi la più recente
    local matches = vim.fn.glob(root .. "/visualstudiotoolsforunity.vstuc-*/bin", true, true)
    table.sort(matches) -- ordinamento lessicale: la versione più alta va in fondo
    local dir = matches[#matches]
    if dir and vim.uv.fs_stat(dir) then
      return dir
    end
  end
  return nil
end

-- Scopre l'endpoint del debugger Unity via UnityAttachProbe.dll e lo passa a
-- `resolve("host:porta")` (o `resolve(nil)` in caso di annullamento/errore). Stile
-- callback perché la scelta con più editor aperti (vim.ui.select) è asincrona: il
-- chiamante usa questa funzione dentro una coroutine dap (vedi endPoint sotto).
-- Best-effort: se il probe non c'è o l'output non è parsabile, si ricade
-- sull'inserimento manuale dell'endpoint.
local function unity_endpoint(dir, resolve)
  local probe = dir .. "/UnityAttachProbe.dll"
  local function ask_manual()
    local input = vim.fn.input "Endpoint Unity (host:porta): "
    resolve(input ~= "" and input or nil)
  end
  if not vim.uv.fs_stat(probe) then
    return ask_manual()
  end
  local res = vim.system({ "dotnet", probe }, { text = true }):wait()
  local ok, decoded = pcall(vim.json.decode, res.stdout or "")
  if not ok or type(decoded) ~= "table" then
    return ask_manual()
  end
  -- Normalizza: il probe elenca i target; ogni voce ha un indirizzo e una porta.
  -- I nomi dei campi variano tra versioni, quindi li cerchiamo in modo tollerante.
  local targets = {}
  for _, t in pairs(decoded) do
    if type(t) == "table" then
      local host = t.address or t.host or t.ipAddress or "127.0.0.1"
      local port = t.debuggerPort or t.port or t.debuggingPort
      if port then
        table.insert(targets, {
          endpoint = ("%s:%d"):format(host, port),
          label = ("%s (%s:%d)"):format(t.projectName or t.name or "Unity", host, port),
        })
      end
    end
  end
  if #targets == 0 then
    return ask_manual()
  elseif #targets == 1 then
    return resolve(targets[1].endpoint)
  end
  vim.ui.select(targets, {
    prompt = "Editor Unity a cui attaccarsi:",
    format_item = function(t)
      return t.label
    end,
  }, function(t)
    resolve(t and t.endpoint or nil)
  end)
end

local function setup_unity(dap)
  if vim.fn.executable "dotnet" ~= 1 then
    return false
  end
  local dir = find_vstuc_dir()
  if not dir then
    return false
  end
  dap.adapters.vstuc = {
    type = "executable",
    command = "dotnet",
    args = { dir .. "/Visual Studio Tools for Unity.dll" },
    name = "vstuc",
  }
  dap.configurations.cs = dap.configurations.cs or {}
  table.insert(dap.configurations.cs, {
    type = "vstuc",
    request = "attach",
    name = "Attach to Unity",
    logFile = vim.fn.stdpath "cache" .. "/vstuc.log",
    -- nvim-dap valuta i valori-funzione della config; per l'async va restituita una
    -- coroutine sospesa che risveglia la run-coroutine col risultato (o dap.ABORT).
    -- Vedi :h dap-configuration ("To support asynchronous operations...").
    endPoint = function()
      return coroutine.create(function(dap_run_co)
        unity_endpoint(dir, function(ep)
          coroutine.resume(dap_run_co, ep or dap.ABORT)
        end)
      end)
    end,
  })
  return true
end

function M.config()
  local dap = require "dap"
  local dapui = require "dapui"

  dapui.setup()
  require("nvim-dap-virtual-text").setup {}

  -- Apri/chiudi automaticamente il pannello UI con la sessione di debug.
  dap.listeners.after.event_initialized["dapui_config"] = function()
    dapui.open()
  end
  dap.listeners.before.event_terminated["dapui_config"] = function()
    dapui.close()
  end
  dap.listeners.before.event_exited["dapui_config"] = function()
    dapui.close()
  end

  local unity_ok = setup_unity(dap)

  local wk = require "which-key"
  wk.add {
    { "<leader>dc", "<cmd>lua require('dap').continue()<cr>", desc = "Continue / Start" },
    { "<leader>db", "<cmd>lua require('dap').toggle_breakpoint()<cr>", desc = "Toggle Breakpoint" },
    {
      "<leader>dB",
      "<cmd>lua require('dap').set_breakpoint(vim.fn.input('Condizione breakpoint: '))<cr>",
      desc = "Conditional Breakpoint",
    },
    { "<leader>di", "<cmd>lua require('dap').step_into()<cr>", desc = "Step Into" },
    { "<leader>do", "<cmd>lua require('dap').step_over()<cr>", desc = "Step Over" },
    { "<leader>dO", "<cmd>lua require('dap').step_out()<cr>", desc = "Step Out" },
    { "<leader>dr", "<cmd>lua require('dap').repl.toggle()<cr>", desc = "Toggle REPL" },
    { "<leader>dl", "<cmd>lua require('dap').run_last()<cr>", desc = "Run Last" },
    { "<leader>dt", "<cmd>lua require('dap').terminate()<cr>", desc = "Terminate" },
    { "<leader>du", "<cmd>lua require('dapui').toggle()<cr>", desc = "Toggle UI" },
  }

  -- Scorciatoia dedicata all'attach Unity: avvisa in modo pigro se l'adapter non
  -- è stato registrato (dotnet o estensione vstuc mancanti), invece di fallire muto.
  if unity_ok then
    wk.add {
      { "<leader>dU", "<cmd>lua require('dap').continue()<cr>", desc = "Attach to Unity" },
    }
  else
    wk.add {
      {
        "<leader>dU",
        function()
          vim.notify(
            "Attach Unity non disponibile: serve `dotnet` nel PATH e l'estensione "
              .. "VS Code 'Visual Studio Tools for Unity' (id visualstudiotoolsforunity.vstuc).\n"
              .. "In alternativa imposta `vstuc_dir` in lua/user/machine.lua (o vim.g.vstuc_dir) "
              .. "alla cartella bin/ che contiene 'Visual Studio Tools for Unity.dll'.",
            vim.log.levels.WARN,
            { title = "nvim-dap (Unity)" }
          )
        end,
        desc = "Attach to Unity (non disponibile)",
      },
    }
  end
end

return M
