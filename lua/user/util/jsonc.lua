-- Parsing di JSON "con commenti" (JSONC), il dialetto usato dai file di VSCode
-- (.vscode/tasks.json, *.code-workspace): commenti // e /* */ e virgole finali.
-- Sorgente unica riusata da user/jobs (task .vscode) e user/projects (workspace).

local M = {}

-- Rimuove commenti // e /* */ e virgole finali da un JSONC, rispettando le stringhe
-- (un "http://" dentro una stringa non viene toccato).
function M.strip(s)
  local out, i, n = {}, 1, #s
  local in_str, esc = false, false
  while i <= n do
    local c = s:sub(i, i)
    if in_str then
      out[#out + 1] = c
      if esc then
        esc = false
      elseif c == "\\" then
        esc = true
      elseif c == '"' then
        in_str = false
      end
      i = i + 1
    else
      local c2 = s:sub(i, i + 1)
      if c == '"' then
        in_str = true
        out[#out + 1] = c
        i = i + 1
      elseif c2 == "//" then
        while i <= n and s:sub(i, i) ~= "\n" do
          i = i + 1
        end
      elseif c2 == "/*" then
        i = i + 2
        while i <= n and s:sub(i, i + 1) ~= "*/" do
          i = i + 1
        end
        i = i + 2
      else
        out[#out + 1] = c
        i = i + 1
      end
    end
  end
  return (table.concat(out):gsub(",%s*([%]}])", "%1"))
end

-- Decodifica una stringa JSONC in tabella Lua, o nil se malformata.
function M.decode(data)
  if not data then
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, M.strip(data))
  if not ok then
    return nil
  end
  return decoded
end

return M
