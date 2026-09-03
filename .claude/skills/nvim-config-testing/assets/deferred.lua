--- 2. A module loaded by `Config.later()` is there, and holds the configuration
--- it was given.
---
--- Deferred loading is what makes a wrong `setup()` invisible: the module is
--- fine at startup because it does not exist yet. This probe waits for it and
--- then reads the value that actually reached it, which is not always the one
--- written in the config file - a second `setup()` call, or an option renamed
--- upstream, both end here.
---
--- Parameters:
---   module   Lua module to inspect ('mini.git'), required
---   force    `require()` it instead of waiting, to tell "not loaded yet"
---            apart from "loading throws"
---   field    dotted path inside the module to read ('config.command.split')
---   expect   pattern the value at `field` must match
---   wait     grace period for `Config.later()`, in ms
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
