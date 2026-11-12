-- ┌─────────────┐
-- │ mise tools  │
-- └─────────────┘
--
-- 'after/lsp/ts_ls.lua' and `jdtls.lua` use these helpers.

local M = {}

-- Return installed versions of `tool` as `{ version, path }`, newest first, or `nil` on failure.
-- NOTE: Each caller requests a different tool once per session, so no cache is necessary.
function M.installed(tool)
  local ok, out = pcall(
    function() return vim.system({ 'mise', 'ls', tool, '--json' }):wait() end
  )
  if not ok or out.code ~= 0 then return nil end

  local decoded, entries = pcall(vim.json.decode, out.stdout)
  if not decoded or type(entries) ~= 'table' then return nil end

  local installed = {}
  for _, entry in ipairs(entries) do
    if entry.installed then
      installed[#installed + 1] = {
        version = entry.version,
        path = entry.install_path,
      }
    end
  end

  -- `mise` reports the oldest version first.
  return vim.fn.reverse(installed)
end

function M.newest(tool, accept)
  for _, entry in ipairs(M.installed(tool) or {}) do
    if accept == nil or accept(entry) then return entry end
  end
end

return M
