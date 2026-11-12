-- ┌─────────────┐
-- │ C behaviour │
-- └─────────────┘
--
-- This file serves `c` and `cpp`; '$VIMRUNTIME/ftplugin/cpp.vim' loads it.

local ft = require('config.ft')

ft.ts_fold()

local build = vim.fs.find({ 'CMakeLists.txt', 'Makefile', 'makefile' }, {
  path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
  upward = true,
})[1]
local root = build and vim.fs.dirname(build) or nil

-- `:make` uses 'compiler/cmake.lua' for CMake and `gcc` for a plain makefile. See `:h :make`.
if build ~= nil then
  ft.build(vim.fs.basename(build) == 'CMakeLists.txt' and 'cmake' or 'gcc')
end

-- `gf`, `[I` and `:checkpath` use only project directories for an `#include`. See `:h 'path'`.
if root ~= nil then
  local dirs = {}
  for _, name in ipairs({ '', 'include', 'src', 'lib' }) do
    local dir = name == '' and root or vim.fs.joinpath(root, name)
    if vim.uv.fs_stat(dir) ~= nil then
      table.insert(dirs, (dir:gsub('[ ,]', '\\%0')))
    end
  end
  -- This line builds the value from the constant, not from the current 'path' value.
  -- See 'lua/config/path.lua'.
  vim.bo.path = require('config.path').with(dirs)
end

-- `:Run` follows the contract in 'lua/config/run.lua'.
-- NOTE: A project's `:Run` runs the program that the last `:make` built. It never builds first.
-- A build inside the resolver would freeze the editor without a quickfix list.
-- The terminal job compiles a file outside a project.
local function programs()
  local found = {}
  local collect = function(dir, depth)
    if dir == nil or vim.uv.fs_stat(dir) == nil then return end
    for name, kind in vim.fs.dir(dir, { depth = depth }) do
      -- 'CMakeFiles' contains executable files that CMake uses to check the compiler.
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
    return require('config.run').compiled(
      { vim.bo.filetype == 'cpp' and 'clang++' or 'clang' },
      args
    )
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
