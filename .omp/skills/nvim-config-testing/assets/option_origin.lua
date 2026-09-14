--- 3. Who set an option.
---
--- `:verbose set` is the only answer that names the responsible file, which is
--- what tells "my setting is wrong" apart from "my setting was overwritten by
--- a later one". Most surprises in this configuration are the second kind: an
--- ftplugin, a plugin, or a filetype autocommand that ran after.
---
--- Parameters:
---   options  options to interrogate, without the trailing `?`, required
---   scope    'local' (default), 'global' or 'all'
---   before   snippet that brings the session into the state to inspect
---   expect   table of option -> pattern the origin line must match, e.g.
---            @{ makeprg = 'compiler/cargo.vim' }
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  P.eval('before')

  local scope = P.param('scope', 'local')
  local command = scope == 'global' and 'setglobal'
    or (scope == 'all' and 'set' or 'setlocal')
  local expect = P.param('expect', {})

  for _, option in ipairs(P.list('options')) do
    local cmd = 'verbose ' .. command .. ' ' .. option .. '?'
    local ok, result = pcall(vim.api.nvim_exec2, cmd, { output = true })
    if not ok then
      P.fail('`:' .. cmd .. '` failed', result)
    else
      local output = vim.trim(result.output or '')
      P.expect(option, expect[option], output:gsub('\n%s*', ' | '))
    end
  end
end)
