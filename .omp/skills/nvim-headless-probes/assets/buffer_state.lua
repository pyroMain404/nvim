--- 6. Check the buffer state after an action.
---
--- The layout probe checks window positions. This probe checks buffer contents, options,
--- filetype, and buffer-local state.
--- Opening a file "the right way" requires its filetype.
--- A scratch copy can look like a file but lack its filetype. Plugins that require a filetype
--- then fail.
---
--- Parameters:
---   before: Run this snippet to create the buffer to inspect.
---   keys: Send this list of keys in order before inspection.
---   options: Report these buffer or window options ('filetype', 'foldmethod').
---   vars: Report these `b:` variables ('diff_ref', 'minidiff_summary').
---
---   expect: Map each name to a pattern. A name identifies an option, a variable,
---           or 'name', 'lines', 'cursor'. Patterns match `tostring(actual)`.
---           Options first pass through `vim.inspect()`: empty 'buftype' matches
---           `^""$`, not `^$`. A `cursor` includes braces (`{ 1, 0 }`).
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

-- NOTE: Do not use `ok and value or '<none>'` here. A `false` option triggers the fallback.
-- The probe would report `<none>` ("not set") for a value it read.
local function option(name)
  local ok, value = pcall(vim.api.nvim_get_option_value, name, { scope = 'local' })
  if not ok then return '<none>' end
  return value
end

P.run(function()
  P.eval('before')
  for _, key in ipairs(P.list('keys')) do
    P.keys(key)
  end

  local expect = P.param('expect', {})
  local buf = vim.api.nvim_get_current_buf()

  P.expect('name', expect.name, vim.api.nvim_buf_get_name(buf))
  P.expect('cursor', expect.cursor, vim.inspect(vim.api.nvim_win_get_cursor(0)))
  P.expect('lines', expect.lines, vim.api.nvim_buf_line_count(buf))

  for _, name in ipairs(P.list('options', { 'filetype', 'buftype' })) do
    P.expect(name, expect[name], vim.inspect(option(name)))
  end
  for _, name in ipairs(P.list('vars')) do
    local ok, value = pcall(vim.api.nvim_buf_get_var, buf, name)
    P.expect('b:' .. name, expect[name], ok and vim.inspect(value) or '<unset>')
  end
end)
