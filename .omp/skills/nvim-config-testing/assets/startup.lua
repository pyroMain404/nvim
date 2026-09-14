--- 1. Clean startup: the configuration loads, and says nothing it should not.
---
--- This is the one check worth running after every change, because a file that
--- throws while loading takes with it everything registered after it, and the
--- symptom shows up somewhere else entirely.
---
--- Parameters:
---   modules  list of Lua modules that must be loaded once the deferred part
---            of the configuration has run ('mini.git', 'mini.diff', ...)
---   forbid   patterns that must not appear in `:messages`
---            (default: the shapes an error takes)
---   expect   patterns that must appear in `:messages`
---   allow    patterns of a `v:errmsg` that is known and accepted
---   wait     grace period for `Config.later()`, in ms
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  local messages = vim.api.nvim_exec2('messages', { output = true }).output or ''

  local forbid = P.list('forbid', { 'Error', 'E5108', 'E5113', 'stack traceback' })
  for _, pattern in ipairs(forbid) do
    local found = messages:find(pattern)
    P.check('`:messages` free of `' .. pattern .. '`', not found, found and messages)
  end

  for _, pattern in ipairs(P.list('expect')) do
    P.check(
      '`:messages` contains `' .. pattern .. '`',
      messages:find(pattern) ~= nil
    )
  end

  local errmsg = vim.v.errmsg
  for _, pattern in ipairs(P.list('allow')) do
    if errmsg:find(pattern) then errmsg = '' end
  end
  P.check('`v:errmsg` empty', errmsg == '', vim.v.errmsg)
  P.check('`Config` exists', type(_G.Config) == 'table', type(_G.Config))

  for _, module in ipairs(P.list('modules')) do
    P.check("'" .. module .. "' loaded", package.loaded[module] ~= nil)
  end

  P.info(
    ('%d runtime files sourced'):format(
      #vim.fn.split(vim.fn.execute('scriptnames'), '\n')
    )
  )
  if messages ~= '' then P.info('--- :messages\n' .. messages) end
end)
