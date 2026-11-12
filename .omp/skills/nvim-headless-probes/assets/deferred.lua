--- 2. Check that a module from `Config.later()` loads with the specified configuration.
---
--- Deferred loading can hide a wrong `setup()` at startup because the module does not yet exist.
--- This probe waits and reads the value that reached the module.
--- A second `setup()` call or an upstream option rename can change the value from the
--- configuration file.
---
--- Parameters:
---   module: Specify the required Lua module ('mini.git').
---   force: Use `require()` instead of waiting to distinguish "not loaded yet"
---          from "loading throws".
---   field: Read this dotted path in the module ('config.command.split').
---   expect: Specify the pattern that the value at `field` must match.
---   wait: Specify the grace period for `Config.later()`, in ms.
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  local name = P.need('module')

  local loaded = package.loaded[name] ~= nil
  P.check("'" .. name .. "' loaded by the configuration", loaded)

  local module = package.loaded[name]
  if not loaded and P.param('force', false) then
    local ok, required = pcall(require, name)
    P.check(
      "'" .. name .. "' can be required at all",
      ok,
      not ok and required or nil
    )
    module = ok and required or nil
  end
  if type(module) ~= 'table' then return end

  local field = P.param('field')
  if field == nil then return P.dump(name .. '.config', rawget(module, 'config')) end

  local value = module
  for _, key in ipairs(vim.split(field, '.', { plain = true })) do
    if type(value) ~= 'table' then break end
    value = value[key]
  end
  P.expect(name .. '.' .. field, P.param('expect'), vim.inspect(value))
end)
