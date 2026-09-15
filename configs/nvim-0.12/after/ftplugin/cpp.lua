-- ┌───────────────┐
-- │ C++ behaviour │
-- └───────────────┘
--
-- This file contains behavior specific to C++ buffers, added on top of what
-- '$VIMRUNTIME/ftplugin/cpp.vim' already does - it sources 'c.vim' and
-- 'c.lua', so `commentstring`, `include`, `define` and `omnifunc` come from
-- there - plus `cindent` from '$VIMRUNTIME/indent/cpp.vim'. None of that is
-- repeated here. `:verbose setlocal commentstring? include?` says who set what.
--
-- The indentation is not set here either: `expandtab`, `tabstop=2` and
-- `shiftwidth=2` come from 'plugin/10_options.lua' and happen to match the LLVM
-- style that `clang-format` falls back to. A project that wants something else
-- says so in its own '.clang-format', which is the file both the formatter and
-- the server read.
--
-- NOTE: a '.h' file is `cpp` here and not `c`, whatever it contains:
-- `M.header()` of '$VIMRUNTIME/lua/vim/filetype/detect.lua' only looks for
-- Objective-C markers and then falls back to `cpp` unless `g:c_syntax_for_h` is
-- set. That global belongs to the '.nvim.lua' of a C-only project (`:h 'exrc'`,
-- skill `nvim-project-environment`), not to this shared config.

-- Fold on functions and classes instead of on indentation, now that the parser
-- is installed (`:h vim.treesitter.foldexpr()`), the same way
-- 'after/ftplugin/java.lua' does it. Nothing is folded on opening, because
-- 'foldlevel' is 10 in 'plugin/10_options.lua'. The second index is what keeps
-- both options inside this buffer: plain `vim.wo` writes like `:set` and moves
-- the global value as well, so every window opened after the first C++ file
-- would fold by this expression (`:h vim.wo`).
vim.wo[0][0].foldmethod = 'expr'
vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'

-- Which build drives `:make`, and where a built program is looked for. Walking
-- up costs a handful of `stat` calls per buffer, which is what
-- '$VIMRUNTIME/ftplugin/rust.vim' does for 'Cargo.toml'; nothing here reads a
-- file until `:make` or `:Run` is called.
local build = vim.fs.find({ 'CMakeLists.txt', 'Makefile', 'makefile' }, {
  path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
  upward = true,
})[1]
local root = build and vim.fs.dirname(build) or nil

-- Build through `:h :make`, so that errors land in the quickfix list and `]q` /
-- `[q` of 'mini.bracketed' walk them. Which compiler plugin answers depends on
-- how the project is built, the same way '$VIMRUNTIME/ftplugin/rust.vim' picks
-- between `cargo` and `rustc`:
-- - 'compiler/cmake.lua' of this config for a CMake project: it has to be
--   written here because the runtime ships no compiler plugin for CMake
--   (`:=vim.fn.getcompletion('', 'compiler')` lists `gcc` and `msvc`, not
--   `cmake`);
-- - `gcc` ('$VIMRUNTIME/compiler/gcc.vim') for a plain makefile. That one sets
--   'errorformat' and no 'makeprg', which is exactly right here: the default
--   `make` is already the command to run, and the format of GCC is also the
--   format of clang.
--
-- A file that belongs to no build at all gets neither, and `:make` then runs
-- plain `make` and says there is no makefile - which is the loud failure, not a
-- silence. Compiling one loose file is `:!clang++ %`, and a project of one file
-- is a 'CMakeLists.txt' away from being a project.
--
-- `:compiler` defines its options through a command it creates and deletes
-- while sourcing, so it has no Lua API and `vim.cmd()` is the only way here.
if build ~= nil then
  local compiler = vim.fs.basename(build) == 'CMakeLists.txt' and 'cmake' or 'gcc'
  vim.cmd('compiler ' .. compiler)
end

-- `gf` on an `#include`, and with it `[I` and `:checkpath` (`:h 'path'`). The
-- runtime sets 'include' and 'define', so what is missing is only where to
-- look: the global 'path' is `.,,`, the directory of the file and the working
-- directory, which resolves a quoted include of a sibling header and nothing
-- else.
--
-- Only directories OF THE PROJECT are added. System include paths do not
-- belong to a shared config - they differ per toolchain, per target and per
-- machine, and a wrong one sends `gf` to another version of the same header -
-- and for those the answer is `gd` of the server, which knows the flags of the
-- translation unit. `<Leader>lf`-style semantics beat a path list every time.
if root ~= nil then
  local dirs = {}
  for _, name in ipairs({ '', 'include', 'src', 'lib' }) do
    local dir = name == '' and root or vim.fs.joinpath(root, name)
    if vim.uv.fs_stat(dir) ~= nil then
      -- A space or a comma inside a directory ends the entry when 'path' is
      -- read, whatever wrote the value, so both are escaped ('C:/Program
      -- Files/...' is the common case here). `:h 'path'`
      table.insert(dirs, (dir:gsub('[ ,]', '\\%0')))
    end
  end
  -- NOTE: `vim.o.path` and not `vim.bo.path`. 'path' is global-local, and the
  -- buffer-local value of a buffer that never set it is the EMPTY STRING, not
  -- the global one in effect (measured: the probe reported a 'path' starting
  -- with a comma, so `.` and the working directory - the two entries that
  -- resolve an include of a sibling header - had just been dropped). Reading
  -- the global and writing the buffer-local one is what `:setlocal path+=`
  -- does (`:h vim.bo`, `:h vim.o`).
  vim.bo.path = vim.o.path .. ',' .. table.concat(dirs, ',')
end

-- Running the project, under the contract of 'lua/config/run.lua'. What a C++
-- project runs is a file it produced, so the default is READ by looking for it
-- rather than by asking a build tool - there is no `cargo run` here, and
-- `cmake --build` only builds.
--
-- NOTE: this runs the program as the last `:make` left it, and does not build
-- first. That is the division of labour of the two contracts: `:make` is the
-- synchronous question that ends and fills the quickfix list, `:Run` starts
-- something that lives. Building inside the resolver would freeze the editor
-- for the length of a build with no quickfix list to show for it, and a build
-- is one `:make` away.
local function programs()
  local found = {}
  local collect = function(dir, depth)
    if dir == nil or vim.uv.fs_stat(dir) == nil then return end
    for name, kind in vim.fs.dir(dir, { depth = depth }) do
      -- 'CMakeFiles' holds the compiler probes CMake builds while configuring
      -- ('CompilerIdCXX', 'cmTC_*'), which are executables and are not the
      -- project
      if kind == 'file' and not name:find('CMakeFiles') then
        local path = vim.fs.joinpath(dir, name)
        -- The only portable question "is this a program": on Windows it is
        -- PATHEXT, so an '.exe' answers and an '.obj' or a '.lib' does not
        if vim.fn.executable(path) == 1 then table.insert(found, path) end
      end
    end
  end
  -- The CMake build directory first, then the root itself for a makefile that
  -- writes its output next to the sources. Depth 1 on the root is what keeps
  -- the two from reporting the same file twice.
  collect(vim.fs.joinpath(root, 'build'), 3)
  collect(root, 1)
  return found
end

require('config.run').command(function(args)
  if root == nil then
    return nil, 'this file belongs to no project: nothing to run'
  end

  local found = programs()
  -- The first argument selects a program when it names one, so that a project
  -- with several says which; everything else reaches the program itself
  local names = {}
  for _, path in ipairs(found) do
    local name = vim.fn.fnamemodify(path, ':t:r')
    table.insert(names, name)
    if name == args[1] then
      return vim.list_extend({ path }, vim.list_slice(args, 2))
    end
  end

  if #found == 1 then return vim.list_extend({ found[1] }, args) end
  if #found == 0 then
    return nil, ("nothing built under '%s' yet: run `:make` first"):format(root)
  end
  return nil, 'several programs here, name one: ' .. table.concat(names, ', ')
end)
