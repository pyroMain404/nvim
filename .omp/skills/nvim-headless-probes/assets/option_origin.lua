--- 3. Identify the source of an option value.
---
--- Only `:verbose set` names the responsible file.
--- It distinguishes "my setting is wrong" from "my setting was overwritten by a later one".
--- An ftplugin, plugin, or filetype autocommand that runs later often causes the second condition
--- in this configuration.
---
--- Parameters:
---   options: Specify the required options without the final `?`.
---   scope: Use 'local' (default), 'global', or 'all'.
---   before: Run this snippet to create the session state to inspect.
---   expect: Map each option to a pattern for its source line, for example,
---           @{ makeprg = 'compiler/cargo.vim' }.
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
