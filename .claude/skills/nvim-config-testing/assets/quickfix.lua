--- 8. `:make` fills the quickfix list with something navigable.
---
--- An `'errorformat'` that matches nothing leaves an empty list and no error
--- message, which reads exactly like a build that succeeded. The check that
--- means something is therefore the opposite one: build something that is
--- broken on purpose, and require the entry to point at a real file and line.
---
--- Parameters:
---   make      command to run, default 'make'
---   makeprg   value to force before running, to test the format alone
---   errorformat  same, for the error format
---   before    snippet run before (to open a file that fails to compile)
---   min       minimum number of entries expected, default 1
---   valid     require an entry to have a line and a buffer whose file is on
---             disk, default true. The file has to exist: see `located` below
---   entry     which entry that has to be, default 1, or 'any'. A build tool
---             that opens its report with a banner ('[ERROR] COMPILATION
---             ERROR :' from Maven) puts a legitimately fileless entry first,
---             and demanding it of entry 1 fails on the message rather than on
---             the format
---   pattern   pattern the text of some entry must match
---   entries   how many entries to print, default 5
local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local P = dofile(here .. '/lib.lua')

P.run(function()
  P.eval('before')

  local makeprg = P.param('makeprg')
  if makeprg ~= nil then vim.bo.makeprg = makeprg end
  local errorformat = P.param('errorformat')
  if errorformat ~= nil then vim.bo.errorformat = errorformat end

  local origin = vim.api.nvim_exec2('verbose setlocal makeprg? errorformat?', {
    output = true,
  })
  P.info(vim.trim(origin.output or ''))

  local command = P.param('make', 'make')
  local ok, err = pcall(vim.cmd, command)
  P.check('`:' .. command .. '` ran', ok, not ok and err or nil)

  local list = vim.fn.getqflist()
  local min = P.param('min', 1)
  P.check(('at least %d entries'):format(min), #list >= min, #list)

  local which = P.param('entry', 1)
  if P.param('valid', true) and list[1] ~= nil then
    -- A buffer id and a line are not enough. An 'errorformat' whose `%f` is
    -- relative to something other than the current directory still produces an
    -- entry, and Vim resolves it against the cwd into a file that does not
    -- exist: `]q` opens an empty buffer with a plausible name, and the entry
    -- reports here with a perfectly good `bufnr`. Measured on a Godot project
    -- whose paths are relative to the project root, with `:make` run from a
    -- subdirectory. So the file has to be on disk for the entry to count.
    local located = function(e)
      if e == nil or e.bufnr == 0 or e.lnum <= 0 then return false end
      local name = vim.api.nvim_buf_get_name(e.bufnr)
      return name ~= '' and vim.uv.fs_stat(name) ~= nil
    end
    local found = nil
    for index, entry in ipairs(list) do
      if located(entry) and (which == 'any' or which == index) then
        found = entry
        break
      end
    end
    local shown = found or list[which ~= 'any' and which or 1] or list[1]
    P.check(
      ('entry %s points at a file and a line'):format(which),
      found ~= nil,
      vim.inspect({
        bufnr = shown.bufnr,
        -- The name is the evidence: a wrong `%f` shows up here and nowhere else
        name = shown.bufnr ~= 0 and vim.api.nvim_buf_get_name(shown.bufnr) or nil,
        lnum = shown.lnum,
        text = shown.text,
      })
    )
  end

  local pattern = P.param('pattern')
  if pattern ~= nil then
    local found = false
    for _, entry in ipairs(list) do
      found = found or (entry.text or ''):find(pattern) ~= nil
    end
    P.check('an entry matches `' .. pattern .. '`', found)
  end

  for index = 1, math.min(#list, P.param('entries', 5)) do
    local entry = list[index]
    P.info(('  %d:%d %s'):format(entry.lnum, entry.col, vim.trim(entry.text or '')))
  end
end)
