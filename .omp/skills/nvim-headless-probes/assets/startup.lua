--- 1. Check that startup loads the configuration without unwanted messages.
---
--- Run this check after each change.
--- A file that fails during loading prevents all later registrations, so the visible symptom can
--- appear elsewhere.
---
--- Parameters:
---   modules: Specify Lua modules that must load after deferred configuration
---            ('mini.git', 'mini.diff', ...).
---   forbid: Specify patterns that must not occur in `:messages`.
---           The defaults match common error forms.
---   expect: Specify patterns that must occur in `:messages`.
---   allow: Specify patterns for known, accepted `v:errmsg` values.
---   wait: Specify the grace period for `Config.later()`, in ms.
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
