--- 6. What a buffer became after an action.
---
--- The counterpart of the layout probe: not where the window is, but what is
--- inside it. Opening a file "the right way" also means the buffer got its
--- filetype, its options and its buffer local state - a scratch copy that looks
--- like a file but has no filetype attached still fails every plugin that keys
--- off one.
---
--- Parameters:
---   before   snippet that produces the buffer to inspect
---   keys     keys to send before inspecting, a list, in order
---   options  buffer or window options to report ('filetype', 'foldmethod')
---   vars     `b:` variables to report ('diff_ref', 'minidiff_summary')
---   expect   table of name -> pattern; the name is an option, a variable, or
---            one of 'name', 'lines', 'cursor'. NOTE: the pattern is matched
---            against `tostring(actual)`, and an option goes through
---            `vim.inspect()` before that: an empty 'buftype' is `^""$` and not
---            `^$`, while a `cursor` carries its braces (`{ 1, 0 }`)
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

-- NOTE: the `ok and value or '<none>'` idiom cannot be used here. A boolean
-- option that is genuinely `false` makes `ok and value` false, so the fallback
-- wins and the probe reports `<none>` - "not set" - for a value it did read.
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
