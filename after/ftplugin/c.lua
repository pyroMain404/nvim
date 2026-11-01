-- ┌─────────────┐
-- │ C behaviour │
-- └─────────────┘
--
-- Serves `c` and `cpp` ('$VIMRUNTIME/ftplugin/cpp.vim' sources this file).

local ft = require('config.ft')

ft.ts_fold()

local build = vim.fs.find({ 'CMakeLists.txt', 'Makefile', 'makefile' }, {
  path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
  upward = true,
})[1]
local root = build and vim.fs.dirname(build) or nil

-- `:make` via 'compiler/cmake.lua' for CMake, `gcc` for a plain makefile. `:h :make`
if build ~= nil then
  ft.build(vim.fs.basename(build) == 'CMakeLists.txt' and 'cmake' or 'gcc')
end

-- `gf`, `[I` and `:checkpath` on an `#include`: project directories only. `:h 'path'`
if root ~= nil then
  local dirs = {}
  for _, name in ipairs({ '', 'include', 'src', 'lib' }) do
    local dir = name == '' and root or vim.fs.joinpath(root, name)
    if vim.uv.fs_stat(dir) ~= nil then
      table.insert(dirs, (dir:gsub('[ ,]', '\\%0')))
    end
  end
  -- Built from the constant, not from a live read of 'path' (see 'lua/config/path.lua').
  vim.bo.path = require('config.path').with(dirs)
end

-- `:Run` under the contract of 'lua/config/run.lua'.
-- NOTE: runs the program as the last `:make` left it and never builds first;
-- building inside the resolver would freeze the editor with no quickfix list.
local function programs()
  local found = {}
  local collect = function(dir, depth)
    if dir == nil or vim.uv.fs_stat(dir) == nil then return end
    for name, kind in vim.fs.dir(dir, { depth = depth }) do
      -- 'CMakeFiles' holds CMake's compiler probes, which are executables.
      if kind == 'file' and not name:find('CMakeFiles') then
        local path = vim.fs.joinpath(dir, name)
        if vim.fn.executable(path) == 1 then table.insert(found, path) end
      end
    end
  end
  collect(vim.fs.joinpath(root, 'build'), 3)
  collect(root, 1)
  return found
end

require('config.run').command(function(args)
  if root == nil then
    return nil, 'this file belongs to no project: nothing to run'
  end

  local found = programs()
  local names = {}
  for _, path in ipairs(found) do
    local name = vim.fn.fnamemodify(path, ':t:r')
    table.insert(names, name)
    if name == args[1] then
      return vim.list_extend({ path }, vim.list_slice(args, 2)), nil, root
    end
  end

  if #found == 1 then return vim.list_extend({ found[1] }, args), nil, root end
  if #found == 0 then
    return nil,
      ("nothing built under '%s' yet: run `:make` first"):format(root),
      root
  end
  return nil, 'several programs here, name one: ' .. table.concat(names, ', '), root
end)

if root ~= nil then ft.undo('setlocal path<') end
