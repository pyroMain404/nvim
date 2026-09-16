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
-- because 'foldlevel' is 10 in 'plugin/10_options.lua'. The second index is
-- what keeps the two inside this buffer: plain `vim.wo` writes like `:set` and
-- moves the global value as well, so every window opened after the first Java
-- file would fold by this expression (`:h vim.wo`).
vim.wo[0][0].foldmethod = 'expr'
vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'

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
-- Only `:make` is affected by this list. The language server is not: it asks
-- its own importer, so a Gradle project gets its classpath and its compliance
-- level from jdtls whatever is decided here.
--
-- TODO: Gradle falls through to `javac`, which compiles the single file
-- instead of running the build - silently, because a file that compiles on its
-- own leaves the quickfix list empty, exactly like a build that succeeded. The
-- missing piece is only the `:make` half: an entry in `builds` below with a
-- `run` and no `compiler` already gives a Gradle project its `:Run`, while the
-- quickfix needs a 'compiler/gradle.lua' written from scratch, and an
-- `errorformat` that matches nothing is indistinguishable from a green build.
-- Not now: there is no Gradle project on this machine to derive it from or
-- check it against. First step is to make one fail on purpose and read the raw
-- output - `gradlew compileJava` on a file with a type error - because the
-- format changes with the console mode ('rich', 'plain'), and `--console=plain`
-- is probably part of the answer. NOTE: on Windows the wrapper to call is
-- `gradlew.bat`; `jobstart()` runs a '.bat' from a list just fine, while the
-- extensionless POSIX `gradlew` next to it raises `E903: Process failed to
-- start` - and raises rather than returning -1.
--
-- Walking up for the build file costs a handful of `stat` calls per buffer,
-- which is what the runtime does for `Cargo.toml`; nothing here reads a file
-- until `:Run` is called.
--
-- One table, two answers, and they are not the same answer: which compiler
-- plugin `:make` uses, and which command runs the project. Holding them in a
-- single field is what made a third build tool expensive, because the two do
-- not always both exist - Gradle has a `run` task and no compiler plugin in
-- the runtime, and `:compiler gradle` is not a no-op but `E666: Compiler not
-- supported`, raised while this ftplugin loads, on every Java file of that
-- project. So here `compiler` may be absent and only `run` is required.
--
-- Every `run` takes the same two arguments, the build file included where it
-- is not read: two of them with different arities is what turns a correct call
-- into a `redundant-parameter` warning from the server.
-- The `run` half of each build tool - the Maven goal, the Ant task - is
-- shared with 'after/ftplugin/xml.lua' through 'lua/config/run.lua''s
-- `java_builds`: that file registers `:Run` on a `pom.xml`/`build.xml`
-- buffer opened directly, which this ftplugin never loads for (Neovim
-- detects those as `xml`, not `java`). Only `compiler`, which selects what
-- `:make` parses, stays here: it is Java-specific and has no meaning on a
-- plain XML buffer.
local builds = {
  ['pom.xml'] = vim.tbl_extend(
    'force',
    { compiler = 'maven' },
    require('config.run').java_builds['pom.xml']
  ),
  ['build.xml'] = vim.tbl_extend(
    'force',
    { compiler = 'ant' },
    require('config.run').java_builds['build.xml']
  ),
}

-- A file that belongs to no build at all: `javac` (`:h compiler-javac`) so
-- that `:make %` compiles just this one, and `java` on the file itself to run
-- it, which since Java 11 needs no compilation step first.
local loose = {
  compiler = 'javac',
  run = function(args, _)
    return vim.list_extend({ 'java', vim.api.nvim_buf_get_name(0) }, args)
  end,
}

-- Explicit order, not `vim.tbl_keys(builds)`: `vim.fs.find()` tests names in
-- list order (`:h vim.fs.find()`), and a table's key order is unspecified, so
-- a checkout holding both a `pom.xml` and a leftover `build.xml` would pick
-- between them by hash order instead of by precedence.
local found = vim.fs.find({ 'pom.xml', 'build.xml' }, {
  upward = true,
  path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
})[1]
local build = found and builds[vim.fs.basename(found)] or loose
local root = found and vim.fs.dirname(found) or nil

-- `:compiler` defines its options through a command it creates and deletes
-- while sourcing, so it has no Lua API and `vim.cmd()` is the only way here.
if build.compiler then vim.cmd('compiler ' .. build.compiler) end

-- `mvn`/`ant` print paths relative to the project, while Neovim resolves
-- quickfix `%f` entries against its own directory - kept at the repository
-- root by 'setup_auto_root()' in 'plugin/30_mini.lua', not necessarily the
-- POM's or the build file's own directory in a multi-module checkout. Same
-- remedy the GDScript ftplugin needed first, shared through
-- 'lua/config/run.lua''s `make_root()`. A loose file (no build found) has
-- nothing to root against.
if found ~= nil then require('config.run').make_root({ 'pom.xml', 'build.xml' }) end

-- Running the application is not what `:make` does, and the two are worth
-- keeping apart. `:make` asks a question that ends - does it compile, do the
-- tests pass - fills the quickfix list and returns; running is a process that
-- lives, writes until it is stopped, and produces nothing to navigate. Handing
-- it to `:make`, which is synchronous, would freeze the editor for exactly as
-- long as the application is useful.
--
-- The command, its name and its shape are the contract of 'lua/config/run.lua',
-- kept by every filetype that has something to run. What belongs to Java is
-- only the resolver: which build tool answers, and which goal it is given.
--
-- Anything more specific than the default of `run` above - a Spring profile, a
-- main class, JVM arguments - belongs to the project and not to the language,
-- so it is passed as arguments here or it lives in the project's '.nvim.lua'
-- (`:h 'exrc'`).
require('config.run').command(
  function(args) return build.run(args, found), nil, root end
)

-- Undo what this file sets when the filetype changes away from `java`
-- (`:h b:undo_ftplugin`). `:Run` undoes itself, registered inside
-- 'lua/config/run.lua''s `M.command()`.
vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n'
  .. table.concat({
    'setlocal shiftwidth< softtabstop< foldmethod< foldexpr<',
    'setlocal makeprg< errorformat<',
    'unlet! b:current_compiler',
  }, ' | ')
