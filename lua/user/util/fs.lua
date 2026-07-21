-- Helper di filesystem/path puri (idempotenti, stateless, senza dipendenze dal
-- dominio): sorgente unica riusata da più moduli. Vedi anche user/util/jsonc.lua.

local M = {}

-- Legge un file per intero, o nil se non apribile.
function M.read_file(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local data = fd:read "*a"
  fd:close()
  return data
end

-- Un path è assoluto? (Windows `C:\...`/`C:/...` o POSIX `/...`.)
function M.is_absolute(p)
  return p:match "^%a:[/\\]" ~= nil or p:match "^[/\\]" ~= nil
end

return M
