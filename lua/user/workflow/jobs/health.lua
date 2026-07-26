local M = {}

-- `:checkhealth user.workflow.jobs` — riporta root rilevata, sorgenti di task attive, file
-- di config trovati, task scoperti e job attualmente in esecuzione.
function M.check()
  vim.health.start "user.workflow.jobs — job in background (<leader>o)"

  local uv = vim.uv or vim.loop
  local cfg = require "user.workflow.jobs.config"
  local providers = require "user.workflow.jobs.providers"
  local jobs = require "user.workflow.jobs"

  local root = providers.root()
  vim.health.info("Root progetto: " .. root)

  -- Gruppo di progetti fratelli (job condivisi), se più di uno.
  local roots = providers.roots()
  if #roots > 1 then
    vim.health.info(("Gruppo di %d progetti fratelli — job condivisi:"):format(#roots))
    for _, r in ipairs(roots) do
      vim.health.info("  · " .. r)
    end
  end

  -- File di config per-progetto rilevati.
  local files = {
    { cfg.local_file, "il nostro formato" },
    { ".vscode/tasks.json", "vscode" .. (cfg.providers.vscode == false and " (provider disabilitato)" or "") },
    { "package.json", "npm" .. (cfg.providers.npm == false and " (provider disabilitato)" or "") },
    { "pom.xml", "maven" .. (cfg.providers.maven == false and " (provider disabilitato)" or "") },
  }
  for _, spec in ipairs(files) do
    local path = root .. "/" .. spec[1]
    if uv.fs_stat(path) then
      vim.health.ok(("%s presente — %s"):format(spec[1], spec[2]))
    else
      vim.health.info(("%s assente — %s"):format(spec[1], spec[2]))
    end
  end

  -- Task effettivamente scoperti (dopo merge e dedup), su tutto il gruppo.
  local tasks = providers.collect()
  if #tasks == 0 then
    vim.health.warn("Nessun task scoperto", { "Crea .nvim/tasks.json (pannello <leader>oo → tasto 'e')." })
  else
    vim.health.ok(("%d task disponibili"):format(#tasks))
    for _, t in ipairs(tasks) do
      vim.health.info(("  · %s → %s  [%s]"):format(t.name, t.cmd, t.source))
    end
  end

  -- Job in esecuzione.
  local running = jobs.running()
  if running > 0 then
    vim.health.ok(("%d job in esecuzione"):format(running))
  else
    vim.health.info "Nessun job in esecuzione"
  end
end

return M
