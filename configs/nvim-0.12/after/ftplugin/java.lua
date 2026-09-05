-- ┌────────────────┐
-- │ Java behaviour │
-- └────────────────┘
--
-- This file contains behavior specific to Java buffers, added on top of what
-- '$VIMRUNTIME/ftplugin/java.vim' already does (`:h ft-java-plugin`):
-- `commentstring`, the `comments` that keep Javadoc going on `o` and `<CR>`,
-- `include` and `define` for `:checkpath` and `[I`, and the `includeexpr` plus
-- `suffixesadd=.java` that make `gf` on an `import` open the source file. None
-- of that is repeated here. `:verbose setlocal commentstring? includeexpr?`
-- says who set what.
--
-- What the runtime does not do, unlike its Rust counterpart, is choose a
-- compiler: without the lines below `:make` runs plain `make`, and a Java
-- project has no makefile to run.

-- Four spaces is the indentation every Java code base uses, and it is not only
-- a matter of looks: '$VIMRUNTIME/indent/java.vim' indents with `cindent`,
-- which reads 'shiftwidth' (`:h java-indenting`). The 2 of
-- 'plugin/10_options.lua' is this config's own convention for the Lua it is
-- written in, and it has no reason to reach Java.
vim.bo.shiftwidth = 4
vim.bo.softtabstop = 4

-- Fold on classes and methods instead of on indentation, now that the parser
-- is installed (`:h vim.treesitter.foldexpr()`). Nothing is folded on opening,
-- because 'foldlevel' is 10 in 'plugin/10_options.lua'.
vim.wo.foldmethod = 'expr'
vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'

-- Build and test through `:h :make`, so that errors and failing tests land in
-- the quickfix list and `]q` / `[q` of 'mini.bracketed' walk them. Which of
-- the runtime compiler plugins answers depends on how the project is built,
-- the same way '$VIMRUNTIME/ftplugin/rust.vim' picks between `cargo` and
-- `rustc`:
-- - `maven` (`:h :compiler`, '$VIMRUNTIME/compiler/maven.vim') reads the
--   `[ERROR] file:[line,col] message` of `javac` exactly, and also collects
--   the `<<< FAILURE!` blocks of Surefire, so `:make test` lists the failing
--   tests with their assertion message. NOTE: the entry of a failure carries
--   the *first* frame of the stack, which for an assertion is inside JUnit
--   and not in the test - the frame of the test is a few entries below, as
--   text. Discarding the framework frames with `%-G` does not fix it: `%-G`
--   ends the pending multi-line message, and the useful frame is then dropped
--   too. Verified against 'compiler/maven.vim' of Neovim 0.12.4;
-- - `ant` for the older builds driven by a 'build.xml';
-- - `javac` (`:h compiler-javac`, `:h errorformat-javac`) for a file that
--   belongs to no build at all, where `:make %` compiles just this one.
--
-- Walking up for the build file costs a handful of `stat` calls per buffer,
-- which is what the runtime does for `Cargo.toml`; nothing here reads a file.
local build_files = { ['pom.xml'] = 'maven', ['build.xml'] = 'ant' }
local found = vim.fs.find(vim.tbl_keys(build_files), {
  upward = true,
  path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
})[1]

-- `:compiler` defines its options through a command it creates and deletes
-- while sourcing, so it has no Lua API and `vim.cmd()` is the only way here.
local compiler = found and build_files[vim.fs.basename(found)] or 'javac'
vim.cmd('compiler ' .. compiler)
