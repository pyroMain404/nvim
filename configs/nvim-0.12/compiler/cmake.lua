-- ┌──────────────────────────┐
-- │ CMake build → quickfix   │
-- └──────────────────────────┘
--
-- `:compiler cmake` teaches `:make` to build a CMake project and put what the
-- compiler says in the quickfix list, so that `]q` and `[q` of
-- 'mini.bracketed' walk the errors. Selected for a buffer in
-- 'after/ftplugin/cpp.lua'. See `:h write-compiler-plugin`, `:h :compiler`,
-- `:h errorformat`.
--
-- It has to be written because the runtime has no compiler plugin for CMake:
-- `:=vim.fn.getcompletion('', 'compiler')` lists 135 of them, `gcc`, `msvc` and
-- `make` among those that touch C++, and no `cmake`, `clang` or `ninja`.

-- The 'errorformat' is not written here, it is INHERITED from the runtime, and
-- that is the whole reason this file is short. `cmake --build` prints whatever
-- the compiler prints, and the diagnostics of clang have the form of GCC's:
--
--   C:/path/main.cpp:4:7: error: cannot initialize a variable of type 'int'
--
-- which '$VIMRUNTIME/compiler/gcc.vim' already reads, drive letter included.
-- Copying its twenty-three lines here would be a copy that goes stale, and an
-- 'errorformat' written from memory leaves the quickfix list empty - which
-- reads exactly like a build that passed (the lesson 'compiler/ngc.lua' paid
-- for with the colour codes of `ngc`).
--
-- NOTE: gcc.vim opens with `if exists("current_compiler") | finish`, so it has
-- to be sourced BEFORE this file claims the name - `:compiler` unlets that
-- variable before sourcing the file it was given (`:h :compiler`), which is
-- what leaves the way open. Sourcing it also runs its `CompilerSet` lines
-- through the command `:compiler` defined for this file, so they apply locally
-- exactly like the ones below.
vim.cmd('runtime compiler/gcc.vim')

-- What gcc.vim does NOT read is what CMake says about itself, and those are the
-- two failures that would otherwise be silent, because the compiler never runs
-- and prints nothing (measured, both on stderr):
--
--   CMake Error at CMakeLists.txt:3:
--     Parse error.  Function missing ending ")".  End of file reached.
--   Error: C:/path/build is not a directory
--
-- The first is navigable, so it is worth an entry: `%E` opens a multi-line
-- message, `%C` collects the indented lines under it, and the `%-G` below ends
-- the pending message when the next unmatched line arrives (`:h errorformat`,
-- the same behavior 'after/ftplugin/java.lua' documents for Surefire). Two
-- opening entries because CMake names the command when there is one -
-- `CMakeLists.txt:2 (project):` - and only the line when there is not.
--
-- The second has no file and no line, so `%+G` keeps it as a general message:
-- the point is only that the list is not empty, because an empty quickfix
-- reads as a build that passed and this one is a build that never started (a
-- 'build/' that was never configured).
vim.cmd([[CompilerSet errorformat+=%ECMake\ Error\ at\ %f:%l\ %m]])
vim.cmd([[CompilerSet errorformat+=%ECMake\ Error\ at\ %f:%l:]])
vim.cmd([[CompilerSet errorformat+=%C\ \ %m]])
vim.cmd([[CompilerSet errorformat+=%+GError:%.%#]])

-- Everything else in the output matches none of those entries: the `[1/2]
-- Building CXX object` progress lines of Ninja, its `FAILED:` line, the whole
-- compiler command line it echoes, the excerpt of the offending source under
-- each diagnostic, and `2 errors generated.`. Kept, they would fill the list
-- with entries that jump nowhere.
--
-- gcc.vim offers `g:compiler_gcc_ignore_unmatched_lines` for this, and it is
-- not used on purpose: that variable is global and stays set, so it would also
-- change what a later `:compiler gcc` does - the branch
-- 'after/ftplugin/cpp.lua' takes for a plain makefile. Appending the entry
-- here keeps the decision inside this compiler plugin, the way
-- 'compiler/ngc.lua' already does it.
vim.cmd([[CompilerSet errorformat+=%-G%.%#]])

vim.g.current_compiler = 'cmake'

-- `--build build` builds the directory configured once with
-- `cmake -S . -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`, and it is
-- relative to the working directory: `MiniMisc.setup_auto_root()` in
-- 'plugin/30_mini.lua' puts that on the root of the repository, which is where
-- the 'CMakeLists.txt' of a single project checkout sits. A project that
-- configures somewhere else, or that drives a preset, says so in its own
-- '.nvim.lua' by setting 'makeprg' (`:h 'exrc'`, skill
-- `nvim-project-environment`) - not here, because this file is shared.
--
-- `$*` is where `:make` inserts its arguments, so `:make --target test` and
-- `:make --clean-first` stay possible.
--
-- A build directory that was never configured is a loud failure, not a silent
-- one: `cmake --build build` answers `Error: <path>/build is not a directory`,
-- which the `%+G` entry above keeps in the list.
vim.cmd([[CompilerSet makeprg=cmake\ --build\ build\ $*]])
