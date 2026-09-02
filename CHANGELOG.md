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

## 2026-09-02

- Move 'mini.diff', 'mini.git' and the Git integration built on them out of
  'plugin/30_mini.lua' and into 'plugin/31_git.lua'. Reading the repository had
  grown to a third of the file for two modules out of thirty three, and to
  almost every line by which that file differs from upstream: keeping it apart
  makes both files shorter to read and a merge from 'minimax' smaller.

- Write who last changed the current line at the end of that line, instead of
  reading it in the window of `:Git blame`: the annotation follows the cursor
  and disappears while the buffer has unsaved changes, as `git blame` counts the
  lines as they are on disk. `<Leader>gb` toggles it, and blaming the whole file
  at once stays `:vertical Git blame -- %:p`.

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
