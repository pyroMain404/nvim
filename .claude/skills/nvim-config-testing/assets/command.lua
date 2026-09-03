--- 12. A user command exists, and running it does not throw.
---
--- A command defined by a plugin loaded with `Config.later()` is missing for
--- the first seconds of a session and present after: "unknown command" is
--- therefore not an answer until the deferred part has run. This probe waits,
--- says which command it found and where it came from, and optionally runs it.
---
--- Parameters:
---   name     command without the colon ('Git'), required
---   buffer   look for a buffer local command instead of a global one
---   run      arguments to run it with ('diff HEAD~1'); omit to only check
---   expect   pattern the definition must match
---   before   snippet run first
---   after    snippet run once the command has run, to report its effect
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  P.eval('before')

  local name = P.need('name')
  local commands = P.param('buffer', false) and vim.api.nvim_buf_get_commands(0, {})
    or vim.api.nvim_get_commands({})
  local command = commands[name]

  P.check('`:' .. name .. '` defined', command ~= nil)
  if command == nil then return end

  P.info(
    ('`:%s` nargs=%s bang=%s definition: %s'):format(
      name,
      command.nargs,
      tostring(command.bang),
      command.definition or '<Lua callback>'
    )
  )
  P.expect('definition', P.param('expect'), command.definition or '')

  local args = P.param('run')
  if args == nil then return end
  local line = vim.trim(name .. ' ' .. args)
  local ok, err = pcall(vim.cmd, line)
  P.check('`:' .. line .. '` ran without error', ok, not ok and err or nil)
  P.eval('after')
end)
