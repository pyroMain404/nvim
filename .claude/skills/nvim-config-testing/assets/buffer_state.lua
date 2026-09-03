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
---            one of 'name', 'lines', 'cursor'
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

local function option(name)
  local ok, value = pcall(vim.api.nvim_get_option_value, name, { scope = 'local' })
  return ok and value or '<none>'
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
