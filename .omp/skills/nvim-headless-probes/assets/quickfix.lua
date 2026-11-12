--- 8. Check that `:make` creates quickfix entries with usable file positions.
---
--- An `'errorformat'` that matches nothing gives an empty list without an error message.
--- This looks like a successful build. Build a known broken file instead.
--- Require an entry that identifies an existing file and line.
---
--- Parameters:
---   make: Specify the command to run. The default is 'make'.
---   makeprg: Set this value before running to test the format alone.
---   errorformat: Set this error format before running to test the format alone.
---   before: Run this snippet first to open a file that fails compilation.
---   min: Specify the minimum expected entry count. The default is 1.
---   valid: Require a line and a buffer with a file on disk. The default is true.
---          The file must exist; see `located` below.
---   entry: Select the entry to check. Use 1 (default) or 'any'.
---          A build banner ('[ERROR] COMPILATION ERROR :' from Maven) can create a valid first
---   entry without a file.
---          Requiring a file in entry 1 then rejects the message, not the format.
---   pattern: Specify the pattern that at least one entry's text must match.
---   entries: Specify how many entries to print. The default is 5.
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
    -- Require an existing file, not just a buffer id and line.
    -- An 'errorformat' with `%f` relative to another directory can still produce an entry with a
    -- valid `bufnr`.
    -- Vim resolves the path against the current directory, where the file might not exist.
    -- Then `]q` opens an empty buffer with a plausible name.
    -- This occurred with Godot paths relative to the project root when `:make` ran from a
    -- subdirectory.
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
        -- Report the name because only this field shows an incorrect `%f`.
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
