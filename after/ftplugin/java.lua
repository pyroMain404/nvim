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

local ft = require('config.ft')

-- Fold on classes and methods (`:h vim.treesitter.foldexpr()`).
ft.ts_fold()

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
-- - `javac` (`:h compiler-javac`, `:h errorformat-javac`) for a file that
--   belongs to no build at all, where `:make %` compiles just this one.
--
-- Only `:make` is affected by this list. The language server is not: it asks
-- its own importer, so a Gradle project gets its classpath and its compliance
-- level from jdtls whatever is decided here.
--
-- TODO: Gradle falls through to `javac`, which compiles the single file
-- instead of running the build - silently, because a file that compiles on its
-- own leaves the quickfix list empty, exactly like a build that succeeded. The
-- missing piece is only the `:make` half: the quickfix needs a
-- 'compiler/gradle.lua' written from scratch, and an `errorformat` that
-- matches nothing is indistinguishable from a green build.
-- Not now: there is no Gradle project on this machine to derive it from or
-- check it against. First step is to make one fail on purpose and read the raw
-- output - `gradlew compileJava` on a file with a type error - because the
-- format changes with the console mode ('rich', 'plain'), and `--console=plain`
-- is probably part of the answer. NOTE: on Windows the wrapper to call is
-- `gradlew.bat`; `jobstart()` runs a '.bat' from a list just fine, while the
-- extensionless POSIX `gradlew` next to it raises `E903: Process failed to
-- start` - and raises rather than returning -1.

-- `:make` and `:Run` follow the nearest 'pom.xml' ('ft.maven()' is shared with
-- 'after/ftplugin/xml.lua'); a loose file falls back to `javac`.
local found = vim.fs.find('pom.xml', {
  upward = true,
  path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
})[1]

if found then
  ft.maven(found)
else
  -- A file that belongs to no build: `:make %` compiles just this one and
  -- `:Run` runs it directly, which since Java 11 needs no compilation step.
  ft.build('javac')
  require('config.run').command(
    function(args)
      return vim.list_extend({ 'java', vim.api.nvim_buf_get_name(0) }, args)
    end
  )
end

ft.undo('setlocal shiftwidth< softtabstop<')
