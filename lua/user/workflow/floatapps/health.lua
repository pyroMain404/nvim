local M = {}

-- `:checkhealth user.workflow.floatapps` — riporta per ogni app della lista in init.lua se
-- l'eseguibile e' nel PATH (voce attiva) o manca (voce inattiva, silently-continue).
function M.check()
  vim.health.start "user.workflow.floatapps — TUI in terminale flottante (<leader>o)"

  local apps = require("user.workflow.floatapps").apps
  for _, app in ipairs(apps) do
    local exe = app.cmd:match "%S+"
    if vim.fn.executable(exe) == 1 then
      vim.health.ok(("%s — %s → %s"):format(exe, app.desc, app.key))
    else
      vim.health.warn(
        ("%s non nel PATH — %s (%s) inattiva"):format(exe, app.desc, app.key),
        { "Installa `" .. exe .. "` e riavvia Neovim per abilitare la scorciatoia." }
      )
    end
  end
end

return M
