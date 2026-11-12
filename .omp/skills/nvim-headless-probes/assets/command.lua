--- 12. Check that a user command exists and runs without an error.
---
--- A plugin that loads through `Config.later()` defines its commands after startup, not during
--- the first seconds.
--- Thus, "unknown command" does not prove failure before deferred loading finishes.
--- This probe waits, reports the command and its source, and can run it.
---
--- Parameters:
---   name: Specify the required command without the colon ('Git').
---   buffer: Look for a buffer-local command instead of a global command.
---   run: Specify command arguments ('diff HEAD~1'). Omit this parameter to check only.
---   expect: Specify the pattern that the definition must match.
---   before: Run this snippet first.
---   after: Run this snippet after the command to report its effect.
---          The probe skips this snippet when `run` is absent.
---          Put snippets that must always run in `before`.
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
