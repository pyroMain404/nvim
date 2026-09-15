## 2026-07-24

- Stop explicitly enabling filetype plugins and syntax support because they are enabled by default on all supported Neovim versions.

## 2026-06-23

- Start using 'mini.input'.

## 2026-06-01

- Move `Config.on_packchanged` definition before the first `vim.pack.add()` call to make it easier to define installation hooks for plugins outside of the basic MiniMax config.

## 2026-04-07

- Update `Config.on_packchanged` helper to pass plugin data to the callback. This makes it easier to use more universal callbacks in `vim.pack` hooks.

- Improve session (`<Leader>s` prefix) mappings:

    - Use `vim.ui.input()` when creating new session with `<Leader>sn`.

    - Add `<leader>sR` to restart Neovim while preserving current session. Uses `MiniSessions.restart()`, requires Neovim>=0.12.

## 2026-04-02

- Add a note in `nvim-0.11` config about Neovim 0.11 not being the latest stable release.

## 2026-03-31

- Remove the note from `nvim-0.12` config about unstable status of Neovim 0.12.

- Add new reference config `nvim-0.13` for Neovim>=0.13 (currently under development).

## 2026-03-27

- Add a `<Leader>ll` mapping for running codelens.

## 2026-02-17

- Update 'mini.files' setup to use `now_if_args` instead of `later`. Otherwise it doesn't override `netrw` as the default explorer when starting Neovim like `nvim .`.

## 2026-02-15

- Update 'nvim-treesitter/nvim-treesitter-textobjects' plugin to not explicitly use `main` branch as it is now the default.

- Add new reference configs:
    - `nvim-0.10` - for Neovim>=0.10
    - `nvim-0.12` - for Neovim>=0.12.

## 2026-02-10

- Update using global variable for config as just `Config` and not `_G.Config`. This is more concise and makes it more consistent with how `MiniXxx` variables are used.

## 2026-01-29

- Update 'mini.completion' setup to use `now_if_args` instead of `later`. Otherwise it doesn't set proper omnifunc for files opened during startup (because necessary `LspAttach` events are already triggered).

- Move setting up 'mini.nvim' modules that need `now_if_args` in a separate "Step one or two" section.

## 2026-01-13

- Improve 'stevearc/conform.nvim' setup:
    - Setup plugin to allow formatting from LSP server if no dedicated formatter is available. This provides more versatile behavior. Previously it was forced in `<Leader>lf` mapping.
    - Use plain `require('conform').format()` in `<Leader>lf` keymaps.

## 2026-01-08

- Improve keymaps for exploring quickfix list (make implementation shorter and more robust) and location list (add it as `<Leader>eQ` to compliment `<Leader>eq` for quickfix).

## 2026-01-03

- Improve 'mini.clue' setup:
    - Use array `mode` where possible for a more concise setup.
    - Use `gen_clues.square_brackets()` to show more built-in clues.
    - Use `s` as a trigger. Currently only for 'mini.surround' actions, but will be more useful in the future.

## 2025-12-20

- Start using 'mini.cmdline'.

## 2025-12-16

- Update 'nvim-treesitter/nvim-treesitter' plugin to not explicitly use `main` branch as it is now the default.

- Update 'mason-org/mason.nvim' example to use `now_if_args` instead of `later`. Otherwise LSP server installed via Mason will not yet be available if Neovim is started as `nvim -- path/to/file`.

## 2025-11-22

- Update `<Leader>fs` mapping to use `"workspace_symbol_live"` scope for `:Pick lsp` instead of `"workspace_symbol"`

## 2025-10-16

- Move `now_if_args` startup helper to 'init.lua' as `Config.now_if_args` to be directly usable from other config files.

- Enable 'mini.misc' behind `now_if_args` instead of `now`. Otherwise `setup_auto_root()` and `setup_restore_cursor()` don't work on initial file(s) if Neovim is started as `nvim -- path/to/file`.

## 2025-10-13

- Initial release.

# Fork changes

Entries of this fork, newest first. They are kept below upstream's log because
upstream always adds at the top of the file: keeping the two apart is what makes
a merge from 'minimax' conflict-free.

## 2026-09-15

- Parse GDScript with tree-sitter. The parser is tier 3 in 'nvim-treesitter' -
  no declared maintainer - which is why the '$VIMRUNTIME/syntax/gdscript.vim'
  underneath is a fallback worth keeping rather than a leftover. The parsers of
  the rest of the ecosystem stay out until they are needed: `gdshader` (which
  covers both '.gdshader' and '.gdshaderinc') and `godot_resource` (the
  `gdresource` of '.tscn' and '.tres') both work today and are one line each.
- Parse C, C++, CMake and makefiles with tree-sitter: highlighting, structural
  folds and the textobjects of 'nvim-treesitter-textobjects' stop falling back
  to the legacy syntax files. The `cpp` parser requires `c`, which ships with
  Neovim but is named in the list anyway, because that list is also what the
  health check reads.
- Attach `clangd` to C and C++ buffers, with `--background-index` so that
  references and rename answer about files that were never opened,
  `--clang-tidy` so that no separate linter is needed, and
  `--header-insertion=never` so that accepting a completion does not edit the
  top of the file. Which C++ standard a buffer is checked against is read per
  translation unit from the project's compilation database, so a C++14 project
  and a C++20 project opened in the same session each get their own; nothing is
  written here. 'after/lsp/clangd.lua' holds `cmd` and nothing else, because the
  `on_attach` of 'nvim-lspconfig' is what defines
  `:LspClangdSwitchSourceHeader`, the header/source jump, and a function
  written there would replace it silently.
- Format C and C++ with `clang-format`, which comes with the same LLVM release
  as the server, so `<Leader>lf` and the command line agree by construction. It
  reads the project's '.clang-format', which the server would not; without that
  file it falls back to the LLVM style, at the two spaces this config already
  sets.
- Give a C++ buffer the four things the runtime leaves out. `:make` builds the
  project, through a 'compiler/cmake.lua' written here because the runtime
  ships no compiler plugin for CMake - it inherits the 'errorformat' of `gcc`,
  which already reads the diagnostics of clang, adds the two failures CMake
  reports about itself, and discards the progress lines of Ninja. A plain
  makefile takes `:compiler gcc` instead, whose default `make` is already the
  right command. Folds follow functions and classes instead of indentation.
  'path' gains the directories of the project, so `gf` on an `#include` reaches
  a header that is not a sibling of the file - and gains only those, because
  system include paths in a shared config are wrong by construction. And `:Run`
  starts what the build produced, looked for under 'build/' and at the root:
  with several programs it names them and refuses, with none it says to run
  `:make` first.
- Report the C++ toolchain in `:checkhealth config`: `clangd`, `clang++`,
  `clang-format` and `clang-tidy` - one LLVM release, hence one piece of advice
  for the four - plus `cmake`, `ninja` and the parsers. The check that matters
  most is the last: whether the project the reader came from has a compilation
  database at all, and which standard it names. Without one clangd does not
  fail, it guesses - it assumes `clang <file>` at the newest standard, reports
  errors on perfectly valid includes and accepts code the build rejects - and
  that is the most common failure of C++ in an editor, indistinguishable from a
  broken config while nobody names it.

## 2026-09-14

- Run the project from the editor with `:Run`, one command with one meaning in
  every language that has something to run: Java, Rust, TypeScript and Angular
  templates. `:make` answers a question that ends - does it compile, do the
  tests pass - and is synchronous; an application is a process that lives and
  writes until it is stopped, so the two do not share a command. The name is
  deliberately not the one each ecosystem uses (`:Crun`, an `:NpmStart`): what
  is worth remembering when opening an unfamiliar repository is a single key.

  With no argument the command is read off the project, never fixed: the goal
  its POM implies (`spring-boot:run` with the Spring Boot plugin, `exec:java`
  otherwise), `ant run`, `cargo run` - which cargo resolves from the manifest
  and which refuses loudly, listing the binaries, in a workspace - or the start
  script of a 'package.json' (`start`, then `dev`, then `serve`). Arguments
  replace that default: `:Run --bin server`, `:Run e2e`, `:Run test -DskipTests`.
  Outside any project, a lone '.java' file runs through `java` on itself.

  A project has the last word over all of it: `vim.g.run_command` in its
  '.nvim.lua' - a list, to which the arguments of the call are appended, or a
  function of those arguments that can also refuse, saying why. Unlike an option
  this needs no autocommand, because the command asks when it is invoked rather
  than when the ftplugin loads.

  The contract, the terminal split it opens and the order the two happen in live
  in 'lua/config/run.lua'; each 'after/ftplugin' only says which command answers
  for its language. Lua is the one that defines nothing, and not by omission:
  the program is the editor reading it, and `:source %` already runs it.

## 2026-09-10

- Read a commit in two ways instead of one, and say in the key which of the two
  is being asked. `<Leader>gp` / `<Leader>gP` show the patch of the picked
  commit alone (all/buffer) - what it changed against the commit before it,
  with nothing that happened afterwards in it - next to `<Leader>gs` /
  `<Leader>gS`, which keep showing everything changed *since* it. `<Leader>rp`
  opens the files of that same commit as a review, read against its parent, the
  way `<Leader>rs` opens the ones changed since the picked commit.

  The commit is named `<rev>^!` rather than `<rev>~..<rev>`, which is what makes
  the first commit of a repository readable too: it has no parent for the range
  to name, and Git refuses it as an unknown revision.

- Move the patch of a commit off `h` and onto the two keys that say what they
  do: `<Leader>gh` / `<Leader>gH` / `<Leader>rh` are now `<Leader>gs` /
  `<Leader>gS` / `<Leader>rs` ("since"), and `MiniGit.show_at_cursor()` moves
  from `<Leader>gs` to `<Leader>gi` ("info at cursor"). The uppercase key keeps
  meaning "this buffer only" everywhere in the group.

## 2026-09-09

- Skip `MiniMisc.setup_termbg_sync()` on Windows, where it could only ever
  fail. The synchronization begins by asking the terminal emulator for its
  background color with an OSC 11 query, and on Windows every emulator is
  reached through ConPTY, which answers the DA1 query itself and never relays
  that one. After a second of waiting the module warned that it had got no
  proper response - the first thing on screen in a session as short lived as
  the editor Git opens to reword a commit.

- Check a Java project against the class library it is really compiled with, and
  say so out loud when that is not possible. `jdtls` runs on the JDK that
  started it - 21 at least, it refuses to start on less - and compiled every
  project with that one too, so on a build targeting another release the
  compliance level read from 'pom.xml' was right and the class library was not:
  a method that release does not have was completed and accepted in the buffer,
  then rejected by the real build.

  Every JDK `mise` has installed is now declared to the server as an execution
  environment, derived from `mise ls java --json` rather than listed by hand -
  the list by hand had to be edited in two files at once, and forgetting it is
  silent. The server itself starts on the newest installed release through
  `MISE_JAVA_VERSION`, so the day it raises its minimum is an installation and
  not an edit, and `:checkhealth config` reads that minimum out of the launcher
  instead of restating it.

  What no list can cover is the JDK that is not installed at all. For that the
  config asks the server, once the project has been imported, which release it
  compiles against, and warns when no declared runtime answers for it. It also
  warns when nothing was imported: with a failed build import `jdtls` keeps
  answering from a bare JDK at its own release, which made that case
  indistinguishable from a healthy one.

- Reach the config through its real path from the `'c` bookmark of the file
  explorer, as `<Leader>ei` and the other `<Leader>e` mappings already do. It
  pointed at the junction Neovim starts from, where no root marker is reachable,
  so a file opened that way got a second `lua_ls` with no root at all - single
  file mode, in which it publishes no diagnostic.

- Format a file Git does not track yet with `<Leader>lf`, instead of answering
  "No changed lines to format". 'mini.diff' attaches to such a file as well, so
  the check for "no reference here" never fired: it looked at whether there was
  any data, where the state that matters is having a reference text. Everything
  in a file that new is changed, and the whole buffer is what gets formatted.

- Stop `lua-language-server` from reading the three reference configs. They
  define the same `Config` helpers as the one in use, so `gd` on one of them
  offered a choice between 'configs/nvim-0.12/init.lua' and
  'configs/nvim-0.13/init.lua', and the file in use carried six "Duplicate
  field" warnings it had done nothing to earn. A '.luarc.json' at the root of
  the repository now keeps them out of the workspace.

- Fold a file opened with `<CR>` from a hunk the way the same file folds when
  opened by hand. The fold options inherited from the patch were dropped after
  the file was loaded, and `<` reads the global value back, so the drop also
  undid what the ftplugin of that file had just set: a Lua buffer reached this
  way folded by indentation, while opening it normally folds it by tree-sitter.
  They are dropped before the file is loaded now, which leaves its own ftplugin
  the last word.

- Keep the fold settings of a Git patch, and the alignment of `<Leader>gb`,
  inside the windows they were meant for. Written with `vim.wo`, they moved the
  global value too, so one `:Git diff` left every window opened afterwards
  folding by `MiniGit.diff_foldexpr()` at 'foldlevel' 3, and one blame bound
  every later window to scroll with the others. It also took with it the
  restore in `show_at_cursor()`, which reads the global back: the file opened
  with `<CR>` from a hunk kept the fold settings of the patch instead of
  dropping them.

## 2026-09-08

- Keep the fold settings of a Java buffer and of an Angular template inside the
  buffer they were meant for. They were written with `vim.wo`, which for an
  option of sole window scope writes like `:set` and moves the global value
  too, so after the first Java file every window opened afterwards started with
  `foldmethod=expr` and the tree-sitter 'foldexpr' - on a buffer whose parser
  may not even be installed. `after/ftplugin/markdown.lua` was already right,
  going through `:setlocal`.

- Turn 'list' off where its indicators mark nothing worth marking: the quickfix
  and location list windows, which share the `qf` filetype and are what
  `<Leader>eq` and `<Leader>eQ` open, and the plain text buffers of a '*.txt'
  file. A quickfix entry is a line rendered from a position and a message, so
  'listchars' describes that rendering rather than the code it points at; prose
  has no tab-among-spaces to give away. Everywhere else 'list' stays on, as
  'plugin/10_options.lua' sets it. A '*.txt' file inside a 'doc/' directory is
  `help` and is not affected.

- Reference the commit `<Leader>rh` reviews, so that the files it opens are read
  against it. The revision picked from the Git log becomes the 'mini.diff'
  reference text as the review is opened, which is what pressing `<Leader>gr`
  and finding the same commit a second time did by hand: hunk navigation, the
  hunk textobject and the overlay then work on the change every file of the
  review received since then. `<Leader>rc` puts back the reference that was
  there before, unless it was changed by hand while the review was open - that
  is a decision about what to read against, and closing a tabpage does not undo
  it. A review named from the command line references its revision too, ranges
  such as `main...` excepted: they name a set of commits and not a state, so
  every file falls back to the Git index. `Config.review.unstaged()` and
  `Config.review.staged()` set no reference, the index being what they are read
  against already.

- Say why a patch is not shown in `<Leader>gd`, `<Leader>ga`, `<Leader>gh` and
  their buffer scoped counterparts, which now go through
  `Config.git.diff_unstaged(buf_id)`, `Config.git.diff_staged(buf_id)` and
  `Config.git.diff_commit(buf_id, rev)` instead of running `:Git diff`
  themselves. Two cases had no answer: on a working tree with nothing changed
  'mini.git' opens no window and says nothing, which reads as a mapping that
  does not work, and outside a repository it answers with the whole usage
  message of `git diff --no-index`, over two hundred lines of it. Both are now
  the single line the `<Leader>r` group already gave - `No change to show not
  staged`, `No change to show since abc1234 -- 41_git.lua`, `Not inside a Git
  repository` - and a Git which fails for any other reason is reported as it is,
  naming the command as it was run. What it costs is a second run of Git, with
  `--quiet` so that it stops at the first difference instead of formatting
  a patch nobody asked for yet.

- Add `<Leader>rd` and `<Leader>ra` to the review group, the two sets Git names
  without a revision: the files changed and not staged yet, and the ones already
  staged. They are the counterparts of `<Leader>gd` and `<Leader>ga`, which show
  the same two sets as a patch. Neither picks anything: both are read while the
  change is being written, and open right away.

- Rename `<Leader>rg` to `<Leader>rh`, so that the second key of a review is
  always the one its patch has in `<Leader>g`: `<Leader>rd` reads what
  `<Leader>gd` shows, `<Leader>ra` what `<Leader>ga` shows, and `<Leader>rh`
  what `<Leader>gh` shows - the files changed since a commit picked from the Git
  log. Reading a change as a patch and reading it in its files are then the same
  two keys with the first one changed. The rule the group was added with - the
  second key names the source - held only while Git was the single source of
  one review, and would have made three Git reviews share the key `g`; a source
  which is not Git still gets a key named after itself. `<Leader>rg` is gone
  rather than kept as an alias, an alias being the second thing to remember that
  the rename exists to remove.

- Add `Config.review.unstaged(pathspec)` and `Config.review.staged(pathspec)`
  next to `Config.review.git(rev, pathspec)`, which is what the two mappings
  call. They take the same pathspec argument, so a review can be narrowed to
  a part of the tree from the command line: `:lua Config.review.staged('*.md')`.
  What asks Git now takes the arguments which select the files rather than
  a revision, and the label the review is named by rather than deriving it: the
  three sources say `since abc1234`, `not staged` and `staged` in every message
  they print, and the error still names the command as Git was given it.

- Add `<Leader>r`, a review group of its own, and `<Leader>rg` as the Git way
  into it: the files changed since a commit picked from the Git log are loaded
  into the argument list of a new tabpage and opened as buffers, so a change is
  read next to the code that stayed and not only as a patch. `:next` /
  `:previous` walk it, `:argdo` runs over all of it, and the global argument
  list is left alone. It is a group rather than one more `<Leader>g` mapping
  because what its entries share is how the files are opened, not what named
  them: the second key names the source, and Git is only the first one.
  `<Leader>rc` ends the review, closing the tabpage and dropping the buffers it
  opened while leaving alone the ones that were already there - `:tabclose` does
  only the first half, and 'mini.tabline' shows every buffer left listed.

- Add `Config.review` in the new 'plugin/43_review.lua', which is what that
  group calls. `Config.review.open(paths, label)` takes any list of paths - the
  whole contract a source has to meet - and `Config.review.close()` undoes it,
  dropping the buffers the review opened and no others. `Config.review.git(rev,
  pathspec)` is the Git source: it skips the picker and takes any revision
  expression Git understands, so a branch against its merge base is
  `:lua Config.review.git('main...')` and a single commit is
  `:lua Config.review.git('abc1234~..abc1234')`. The second argument narrows the
  review to a Git pathspec - a directory, a glob, or a list of them, read from
  the root of the repository - which no mapping passes and the command line
  reaches: `:lua Config.review.git('main', 'configs/')`. `Config.git.root()`
  joins the Git API so that the two files agree on where a repository begins.

- Take the buffer to act on as a `buf_id` in `Config.git.log()`,
  `Config.git.diff_commit()` and `Config.git.toggle_diff_ref()`, in place of the
  `'buf'` scope string, and put it first as `:h nvim_buf_get_name()` and every
  other buffer function of Neovim does. `nil` is the whole repository, `0` the
  current buffer, and a number any other buffer - which the scope string could
  not name at all. `Config.git.set_diff_ref()` swaps its two arguments to match,
  and the buffer scoped log no longer passes `-- %:p`: it writes out the path of
  the buffer it was given.

- Pick the commit to review from the Git log in `<Leader>gh` / `<Leader>gH`,
  instead of counting commits back from `HEAD`. The patch now covers everything
  changed since the picked commit, and the list of `<Leader>gH` holds only the
  commits which touched the current file. `3<Leader>gh` is gone, as is the
  `[count]` of `<Leader>gr` / `<Leader>gR`: a revision is chosen by subject
  everywhere, and named by hash through the `rev` argument the two functions now
  take (`:lua Config.git.toggle_diff_ref(nil, 'HEAD~3')`).

- Rename `Config.git.diff_head()` to `Config.git.diff_commit()`, which is what
  it does now that the commit is picked rather than reached by distance.

- Name the enclosing function in the hunk headers of a Lua diff, through the
  built-in driver asked for in '.gitattributes'. Without it Git walks back to
  the first line starting in column 0 - the mapping which happens to sit above
  the change, truncated at 80 characters - and every patch of this config,
  `<Leader>gd` included, was headed by something unrelated to what it shows.

## 2026-09-06

- Advise pinning `ngserver` in the project it belongs to. The server loads the
  Angular language service from the project's 'node_modules', so its major is a
  property of the checkout and not of the machine: `:checkhealth config` now
  gives the `mise use` line to run in the project root, and treats the global
  install as the fallback for a project that pins nothing.

- Load `purplehue`, this config's own color scheme, instead of `catppuccin`. The
  scheme is generated into 'colors/purplehue.lua' and documented as the one this
  fork ships, but 'plugin/40_plugins.lua' asked for `catppuccin` by name while
  the plugin providing it stayed commented out - so Neovim quietly loaded the
  copy bundled in its own runtime. The visible cost was `ColorColumn`, drawn at
  a contrast of 1.07:1 against `Normal`, which made the 85 column ruler
  effectively invisible; under `purplehue` the same ruler sits at about 2.16:1.

## 2026-09-05

- Read a '*.component.html' inside an Angular project as an Angular template
  and not as a web page. Neovim recognises the `htmlangular` filetype only by
  reading the file for `@if` or `*ngIf`, so a template made of `{{ }}` bindings
  alone stayed `html` - with the wrong parser and the wrong server.

- Highlight Angular templates with tree-sitter, wherever they are written.
  The `angular` parser knows `{{ }}`, `*ngIf`, `(click)` and `[prop]`;
  `typescript`, `html`, `css`, `scss` and `json` cover the other files a
  component is made of. A template written inline in the `@Component`
  decorator is parsed too, through an injection into the backtick string,
  and so are inline `styles`.

- Attach `angularls` and `ts_ls` to Angular buffers. The first is the only
  one that type checks a template against its component class; the second
  is what makes a '.ts' file behave like TypeScript at all. `ngserver` has
  to be the same major as the project's Angular, and `:checkhealth config`
  now says which one that is.

- Make `:make` compile an Angular project and fill the quickfix list, in a
  TypeScript buffer and in a template alike, through the new `ngc` compiler
  plugin. `tsc`, the one Neovim ships, does not read templates and reports
  nothing for an error inside one; the Angular compiler reports it at its
  line and column in the '.html' file, and `]q` now jumps there.

- Format the files of an Angular project with `prettier` on `<Leader>lf`,
  which is what such a project already runs in CI and the only one that
  reads its '.prettierrc'. Without it the mapping fell back to whichever
  server answered first, and to its own rules.

- Report the Angular toolchain in `:checkhealth config`: Node, `ngserver`,
  `typescript-language-server`, `prettier`, the parsers, whether the
  project's 'node_modules' is there at all, and the Angular major the
  language server has to match.
- Parse Java with tree-sitter, and the 'pom.xml' of a Maven project with the
  `xml` parser: highlighting, folds and textobjects stop falling back to the
  legacy syntax files.

- Attach `jdtls` to Java buffers, with the settings whose default leaves them
  off: the build configuration reread without asking, the sources of a
  dependency downloaded so that `<Leader>ls` lands in real code instead of a
  decompiled stub, and the signature help 'mini.completion' shows while typing
  a call. The server is installed with `mise`; `:checkhealth config` has the
  command.

- Build and test Java from the editor: `:make` in a Java buffer now runs the
  build tool of the project - `maven` under a 'pom.xml', `ant` under a
  'build.xml', `javac` for a file that belongs to no build - so compilation
  errors arrive in the quickfix list with their file, line and column, and
  `]q` walks them. Java buffers also indent by four, as the language does, and
  fold by class and method.

- Report the Java toolchain in `:checkhealth config`: which JDK this session
  sees and from where, whether it is recent enough for the server, `javac`,
  `mvn`, the language server with the `mise` line that installs it, the Python
  its launcher needs, and whether the two parsers are installed.

- Show the full first line of a version in `:checkhealth config`. A program
  printing several CRLF lines left a carriage return in the middle of the
  report and broke the entry in two.

## 2026-09-04

- Attach `lua_ls` to Lua buffers: the server was configured in
  'after/lsp/lua_ls.lua' but never listed in `vim.lsp.enable()`, so every
  `<Leader>l` mapping either did nothing or reported that no server supports the
  method. Its settings now know about this config: Neovim's API and 'mini.nvim'
  in `workspace.library`, `Config` among the declared globals, and the module
  path Neovim itself uses to resolve a `require()`.

- Format Lua with `stylua` on `<Leader>lf`. It reads the '.stylua.toml' at the
  root, so the editor and the check required before a commit apply the same
  rules; the LSP fallback used neither.

- Report the Lua toolchain in `:checkhealth config`: the language server with
  its version, and whether the tree-sitter parser is installed.

## 2026-09-04

- Format only the lines that changed, in every language: `<Leader>lf` now runs
  the formatter over the hunks 'mini.diff' reports against its reference
  instead of over the whole buffer, so a one line fix stops arriving as a
  reformatted file. `<Leader>lF` formats everything when that is the intent,
  and a Visual `<Leader>lf` still formats the selection. The rule lives in
  'plugin/42_format.lua', behind `Config.format`.

- Open the config from its real path in every `<Leader>e` mapping. Through the
  junction that `:h stdpath()` reports, no root marker is reachable, so a second
  `lua_ls` was starting with no root - in single file mode, where it publishes
  no diagnostics at all.

- Set 'textwidth' to 85 in Lua buffers, the `column_width` of '.stylua.toml',
  so 'colorcolumn' draws the limit that `stylua --check` enforces and `gq`
  reflows comments to it.

## 2026-09-03

- Make the Git workflow a part of its own, 'plugin/41_git.lua', reachable
  through a single `Config.git` API: the revision toggles of `<Leader>gr` and
  `<Leader>gR`, the log of `<Leader>gl`, the `HEAD~N` patch of `<Leader>gh`,
  the blame of `<Leader>gb`, the 'lazygit' window of `<Leader>tl` and the
  upstream merge of `<Leader>ou`. They used to be locals of the file that
  happened to define them, split between 'plugin/31_git.lua' (now gone) and
  'plugin/20_keymaps.lua', where mappings now carry no logic at all.

- Configure 'mini.diff' and 'mini.git' in 'plugin/30_mini.lua' again, with
  every other MINI module. Their `setup()` had followed the Git integration
  out of that file, which made the one place to look for a module setup two.

- Open a file from a patch (`<CR>` or `gF`) below the file opened before it,
  instead of giving each of them a column of its own at the far right. Only
  the first one takes that column; the ones after it share it, one under the
  other, so that no file ends up too narrow for the code it shows.

- Read a file opened at some commit (`<CR>` or `gF` inside a patch) as the
  change that commit made to it: the state right before it becomes the
  'mini.diff' reference of that buffer alone, so `[h` / `]h`, `gh` and the
  overlay work there. Until now 'mini.diff' was not even enabled in those
  buffers - they hold a copy, not a file - and `]h` answered with an error.

- Put the cursor on the line asked for when a patch entry is opened with
  `<CR>` or `gF`. The window is moved and resized before it is ever drawn, so
  Neovim pulled the cursor back into the lines its height could show: the
  first file of a patch looked right and every file after it landed on the
  last visible line.

- Open the references a Rust code lens counts. 'nvim-lspconfig' tells
  rust-analyzer that the client implements `rust-analyzer.showReferences` and
  then registers only `runSingle`, so running an "N implementations" or
  "N references" lens answered that the server does not support the command.
  The locations the server already sent now go to the quickfix list, or
  straight to the place when there is only one.

## 2026-09-02

- Ask language servers for code lens and show them above the code they belong
  to. `<Leader>ll` existed but had nothing to run, because Neovim never
  requested any: the reference and run counts a server offers were simply not
  there. Enabled once for every server and every buffer, not per language.

- Highlight as SQL the query inside the `sqlx` macros, which the crate checks
  against the database while compiling and the editor showed as a grey string.
  It covers `query!`, `query_as!` and their file and unchecked variants,
  written either as `sqlx::query!` or bare, and it needs the `sql` parser,
  which is now installed for this alone.

- Format Rust with `rustfmt` on `<Leader>lf` instead of through the language
  server: same program, same version and same 'rustfmt.toml' as the command
  line and CI. It is the first entry of `formatters_by_ft`, which was empty.

- Stop 'mini.pairs' from closing a single quote in Rust buffers, where `'`
  opens a lifetime rather than a string: typing `&'` used to give `&''` and the
  extra quote had to be removed in every `&'a str` and `<'a, T>`. Double quotes
  keep pairing, and a character literal is typed in full.

- Add `:checkhealth config`, which answers what the config assumes about the
  machine it runs on: whether Git, ripgrep, lazygit, StyLua and the
  `tree-sitter` CLI are reachable and at which version, which Rust toolchain
  answers in this session, the versions of `rustc`, `cargo`, `rust-analyzer`
  and clippy, and whether the `rust` and `toml` parsers are installed rather
  than merely available. Every warning carries the command that fixes it.

- Enable tree-sitter for `rust` and `toml`: structural highlighting, folds by
  structure, and the textobjects of 'nvim-treesitter-textobjects' now work in
  Rust buffers and in `Cargo.toml`, which in a Rust project is read as often as
  the code. Building a parser needs the `tree-sitter` CLI, installed with
  `mise use -g tree-sitter@latest`; without it 'nvim-treesitter' reports that it
  cannot run `tree-sitter` and the parser stays missing.

- Attach `rust-analyzer` to Rust buffers, configured in
  'after/lsp/rust_analyzer.lua'. It reports `clippy` lints while typing instead
  of only in CI, expands procedural macros so that the code inside
  `#[tokio::main]` stops being reported as errors, and leaves off the "Debug"
  code lens, which 'nvim-lspconfig' announces without a handler behind it.
  Install the server with `rustup component add rust-analyzer rust-src`; until
  then nothing changes. This is also the first entry in `vim.lsp.enable()`,
  which was empty.

- Group the Git state and functions of the config under `Config.git`:
  `Config.git.diff_ref`, `Config.git.set_diff_ref()`, `Config.git.blame` and
  `Config.git.toggle_blame()`. They used to sit next to the loading helpers in
  the global context, where nothing told them apart from the rest of it.

- Move 'mini.diff', 'mini.git' and the Git integration built on them out of
  'plugin/30_mini.lua' and into 'plugin/31_git.lua'. Reading the repository had
  grown to a third of the file for two modules out of thirty three, and to
  almost every line by which that file differs from upstream: keeping it apart
  makes both files shorter to read and a merge from 'minimax' smaller.

- Write who last changed the current line at the end of that line, instead of
  reading it in the window of `:Git blame`: the annotation follows the cursor
  and disappears while the buffer has unsaved changes, as `git blame` counts the
  lines as they are on disk. It starts off and `<Leader>gb` turns it on and off,
  while blaming the whole file at once stays `:vertical Git blame -- %:p`.

- Place what `<CR>` opens inside a Git patch by what it is: a commit goes full
  width below the log it was read from, while a file goes into a full height
  column at the far right, pushing the files opened before it to the left. Both
  used to open as a vertical split of the window they were read from, which left
  the log squeezed between them. The column holding the Git output is 85 columns
  wide, the width the config files themselves are written to, so that what is
  left of the screen goes to the file instead of to half a screen of blanks.

- Run `<CR>` and `gF` of a Git patch from the root of the repository, as the
  paths written in a patch are relative to it while 'mini.git' resolves them
  against the current directory. Below the root - where `setup_auto_root()`
  leaves it inside this config - opening an entry of a patch against the working
  tree failed with `E484: Can't open file`.

- Pass the absolute path (`-- %:p`) to the buffer scoped Git commands
  (`<Leader>gA`, `<Leader>gb`, `<Leader>gD`, `<Leader>gH`, `<Leader>gL`), which
  answered with an empty output whenever Neovim was started below the root of
  the repository: `:Git` runs from that root, while `%` expands relative to the
  current directory.

- Turn `<Leader>gr` and `<Leader>gR` into toggles of the 'mini.diff' reference
  text, the first for every buffer and the second for the current one only, so
  that the uppercase key narrows the scope as it does everywhere else. Restoring
  the Git index no longer has a mapping of its own: pressing the same key again
  does it. The reference in use is readable in `Config.diff_ref` and
  `vim.b.diff_ref`, and settable with `Config.set_diff_ref()`.

- Pick the referenced revision from the Git log when `<Leader>gr` / `<Leader>gR`
  are pressed without a `[count]`, so that a commit can be referenced by hash and
  not only by distance from `HEAD`. `1<Leader>gr` is the previous behavior.

- Fail with an error when applying a hunk (`gh`) while a revision is referenced,
  instead of silently staging it against the Git index.

- Add `<Leader>ou`, which fetches the `minimax` upstream remote, asks before
  merging it into the local branch and reports the outcome, so keeping the fork
  current no longer needs a shell session.

- Set `'smoothscroll'`, so that scrolling past a wrapped line moves by screen
  line instead of skipping all of its screen lines at once.

- Add `'nvim-pack-lock.json'` as the first root marker of `setup_auto_root()`, so
  that the working directory becomes the config in use rather than the whole
  fork, keeping the other `configs/` directories out of searches and pickers.

## 2026-08-31

- Add the `nvim-language-support` skill under '.claude/skills/': the procedure for
  adding support for a language, platform or format, with a catalogue of what
  Neovim can be made to do for a language and a reference for Rust.

- Adopt `mise` as the way external dependencies (language servers, formatters,
  linters, language runtimes) are declared and installed.
