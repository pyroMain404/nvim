-- ┌─────────────┐
-- │ mise tools  │
-- └─────────────┘
--
-- Query the versions `mise` has installed for a tool. The two language-server
-- files that need this (`after/lsp/ts_ls.lua` and `after/lsp/jdtls.lua`) used
-- to each shell out to `mise ls <tool> --json`, decode the output and degrade
-- silently when `mise` was missing. That duplication is now one module.
--
-- The contract is only the query: callers keep their own warning strings and
-- their own idea of "newest" (Node by major, Java by Eclipse release), because
-- those messages are part of the language-server behavior this config exposes.

local M = {}

-- Return the installed versions of `tool` that `mise ls <tool> --json`
-- reports, newest first, as `{ version, path }`. Returns `nil` when `mise` is
-- missing, the query fails, or the output is not valid JSON.
--
-- NOTE: one process per call, with no cache. Each of its three callers asks
-- about a different tool (`node`, `npm:typescript`, `java`) from a file read
-- once per session, so a cache keyed by tool could never answer twice.
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

  -- `mise` reports oldest first; reverse so the newest release is at index 1.
  return vim.fn.reverse(installed)
end

return M
