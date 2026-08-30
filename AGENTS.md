# AGENTS.md

This repository is a personal fork of [MiniMax](https://github.com/nvim-mini/MiniMax) (remote `minimax`), the Neovim config generator built around ['mini.nvim'](https://github.com/nvim-mini/mini.nvim). Everything here — the config, its comments, its commits — follows the philosophy of 'mini.nvim'. When in doubt about anything not covered below, read how 'mini.nvim' itself does it (`README.md#general-principles`, `CONTRIBUTING.md`, `MAINTAINING.md` in its repository) and do the same.

Read this file before changing anything. It is short on purpose: it states the rules, not the reasons behind every line of config. The config files themselves are the documentation.

## Project vision

- This is **a config, not a distribution**. There are no automatic updates and no framework layer on top of Neovim. The config is owned and read by its user.
- Config files are **meant to be read**. Every file starts with a comment block explaining what it is for and how to navigate it. A change that makes a file harder to read is a bad change, even if the code is shorter.
- The balance to aim for is the same one 'mini.nvim' aims for: **feature-richness against simplicity of implementation and support**. Prefer the solution that handles the realistic cases and stays understandable a year from now.
- Prefer **built-in Neovim features first, MINI modules second, other plugins last**. A new plugin has to earn its place against a MINI module or a built-in.

## General principles

Adapted from `mini.nvim-general-principles` (`:h mini.nvim-general-principles`).

- **Independence**. Every MINI module is enabled separately with `require('mini.xxx').setup()`. Do not make one module's config depend on another's internals. External dependencies (`git`, `ripgrep`, LSP servers) are optional enhancements, never hard requirements for startup.
- **Setup**. `setup()` creates the global `MiniXxx` object and all intended side effects (mappings, autocommands, highlight groups). Pass **only the parts of `config` that differ from the default**; the rest is inferred. Never copy a whole default config table into this repo just to change one field.
- **Configuration on the fly**. Values in `MiniXxx.config` that affect runtime activity can be changed live (like `MiniSurround.config.n_lines`); values consumed once during `setup()` (like `mappings`) cannot. Change them where they are read, not where they look convenient.
- **Disabling**. To turn functionality off, use the module's own disabling mechanism (`vim.g.minixxx_disable`, `vim.b.minixxx_disable`) or a buffer-local config. Do not delete the `setup()` call and do not shadow the module's mappings.
- **Silencing**. Non-error feedback is silenced with `config.silent = true`, not by removing the feature that emits it.
- **Highlighting**. Link new highlight groups to a semantically close built-in group instead of hard-coding colors, so any color scheme keeps working. Hard-coded colors belong in 'colors/pyropurple.lua' only.
- **Stability**. Treat the config as released software: avoid churn, and make any change that changes muscle memory (a mapping, a default) a deliberate, documented one.
- **Not filetype and language specific**. Do not grow the shared config with per-language branches. Language specific behavior goes into `after/ftplugin/<filetype>.lua` and `after/lsp/<server>.lua`.

## Repository structure

```
setup.lua                 Generator script: copies a config into `stdpath('config')`
configs/README.md         What each config directory is and how it is laid out
configs/nvim-0.10 … 0.13  One reference config per supported Neovim version
CHANGELOG.md              User visible changes, newest first, dated
```

Inside a config directory (see `configs/README.md` for the full explanation):

```
init.lua                 First file executed; plugin manager and `Config` helpers
nvim-pack-lock.json      `vim.pack` lockfile — generated, never edited by hand
plugin/10_options.lua    Built-in Neovim behavior
plugin/20_keymaps.lua    Custom mappings, mostly under `<Leader>`
plugin/30_mini.lua       MINI configuration
plugin/40_plugins.lua    Plugins outside of MINI
snippets/                User defined snippets
after/ftplugin/          Per filetype behavior
after/lsp/               Language server configurations
after/snippets/          Snippet files that override plugin provided ones
colors/                  Color schemes belonging to this config
```

- Files in `plugin/` are sourced automatically in alphabetical order. This is deliberate: it avoids occupying the shared `lua/` namespace and needs no `require()` calls in `init.lua`. **Do not introduce a `lua/` directory** to modularize this config.
- The number prefixes reserve room for insertion. A genuinely new area of config gets its own `NN_name.lua` file with a number that places it correctly in the load order; it does not get appended to an unrelated file.
- `nvim-pack-lock.json` is maintained by `vim.pack`. It changes as a *result* of installing, updating, or removing plugins — never as an edit.

## Where a change goes

- **An option of Neovim itself** → `plugin/10_options.lua`.
- **A mapping** → `plugin/20_keymaps.lua`, under the existing `<Leader>` group that matches its meaning, with a `mini.clue` description.
- **A MINI module or its config** → `plugin/30_mini.lua`, in the same `now()`/`later()` step as comparable modules.
- **A non-MINI plugin** → `plugin/40_plugins.lua`, added through `vim.pack.add()`.
- **Behavior for one filetype or one language server** → `after/ftplugin/` or `after/lsp/`, never the shared files.

Which config directory to change: the one this machine actually runs (`:lua print(vim.fn.stdpath('config'))`). Propagate the change to another `configs/nvim-0.xx` directory only if it makes sense there *and* the syntax is supported by that Neovim version — a `vim.pack` change has no place in the `nvim-0.10` and `nvim-0.11` configs.

## Code style

- **Formatting is StyLua's job.** Run `stylua .` from the repository root before committing; `.stylua.toml` is the source of truth (2 space indent, single quotes preferred, `column_width = 85` here — narrower than upstream 'mini.nvim', because these files are read side by side).
- Startup order is expressed with the `Config` helpers defined in `init.lua`, not with ad-hoc timers:
    - `now(f)` — needed for the first screen draw.
    - `now_if_args(f)` — needed for the first draw only when Neovim is started with a file argument.
    - `later(f)` — everything else, deferred until after the first draw.

  Adding a module to the wrong step is a startup time regression; put it in `later()` unless it draws on the first screen.
- Keep the two step structure of `plugin/30_mini.lua` visible: section separators (`-- Step one ====...`) stay, new `setup()` calls go inside the right step.
- No leftovers: no commented-out experiments (except the ones that already exist as documented alternatives, like the color scheme lines), no debug prints, no `vim.notify` used as a log.

## Documentation comments

The comment style is part of the config, not decoration. Match the surrounding file.

- File headers and major sections use a box:

    ```lua
    -- ┌────────────────────┐
    -- │ MINI configuration │
    -- └────────────────────┘
    ```

- Every `setup()` call and every non-obvious mapping gets a short comment saying **what it is for**, an **example of use** in the notation the config already uses, and **where to read more** (`:h mini.xxx`, `:h option`, `:h tag`).
- Reference documentation through help tags (`:h vim.pack-lockfile`), not through URLs, so it can be read inside Neovim.
- Explain *why*, not *what*. `-- Set 'foldlevel' to 10` is noise; `-- 'foldlevel' has to exceed the deepest fold so that zm closes one level per press` is documentation.
- Use the notation conventions already stated in `init.lua`: `<Space>fh` for key sequences, 'path/to/file' for paths, `:h xxx` for help.

## Commit messages

Header follows the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) style used by 'mini.nvim'; the body follows the Problem/Solution style used by Vim. Both are mandatory here.

```
<type>(<scope>)[!]: <what is wrong, stated as the problem>

Problem:  The problem restated as full sentences, ending with a period.
          Mirrors the subject.
Solution: What the change does about it, closed by `(Gaetano Esposito)`.

Optional prose after the header. No bullet lists.

Signed-off-by: Gaetano Esposito <gaetanoesposito.exe@gmail.com>
```

- `<type>` is mandatory, one of: `ci`, `docs`, `feat`, `fix`, `refactor`, `style`, `test`. Use `fixup` for temporary commits meant to be squashed.
- `<scope>` is mandatory and names the affected area: `git`, `keymaps`, `options`, `mini`, `plugins`, `colorscheme`, … Use `ALL` for a rule enforced across the whole config.
- `!` before `:` marks a breaking change (a mapping that disappears, a default that flips).
- The subject **states the problem, not the fix**: not `fix typo in path handling`, but ``  `gf` inside a patch breaks when the repository path has a space``. Imperative present tense, under 72 characters, no capital first word, no trailing punctuation.
- Alignment in the body: two spaces after `Problem:`, one after `Solution:`, continuation lines indented to column 10.
- Refer to functions and fields without the module prefix where the scope already says it (`add()`, not `MiniSurround.add()`).
- Footers: `Resolve #xxx` / `Related to #yyy` first, then Git trailers. `Signed-off-by:` is always present.
- **One commit does one thing.** A change that does three things is three commits. If the working tree mixes topics, split it by topic — staging individual hunks if needed — instead of committing them together.

## Typical workflow for adding change

Adapted from `MAINTAINING.md#typical-workflow-for-adding-change`.

1. Solve the problem. Keep the change as local as the problem is.
2. Make sure it still reads well: comments updated, `:h` references still correct, file structure intact.
3. Run `stylua .` from the repository root.
4. If the change is worth being seen by the user of this config (a notable or breaking feature or fix), add an entry to `CHANGELOG.md`, following the formatting of the entries above it.
5. Verify (see next section). Do it once, at the end.
6. Commit on a dedicated branch, following the message rules above. Push the branch to `origin`.
7. Never push to `master`, never force-push, never push to the `minimax` remote — it is upstream, read only.

Changes worth sending upstream to MiniMax are a separate matter: its pull request template rejects changes based on personal taste (enabling a new option, installing a new plugin). Personal taste is exactly what belongs in this fork, so keep the two apart.

## Verifying a change

There is no test suite in this repository. Verification is manual and deliberate.

- **Do not run headless checks while working.** Concentrate every check into a single pass at the end of the task.
- **Prefer giving the exact steps to run by hand** over reproducing an interactive behavior headlessly. UI, LSP and deferred plugins do not reproduce faithfully outside a real session.
- The final pass covers both a clean startup and targeted checks for the files actually touched, including modules loaded through `later()` (force the load) and `:checkhealth` for the modules that changed.

Known traps of headless checks on this config — account for them both when writing the command and when reading its output:

| Trap | Remedy |
|---|---|
| `nvim --headless -l script.lua` **does not load `init.lua`**: no plugins, no autocommands, so waiting on any event times out | do not use `-l` to check the config; open the file as an argument and inject code with `-c "luafile ..."` |
| Code inside `Config.later()` runs on a timer after startup, so an immediate `+qa` quits before it ever ran | force the load (`require()` the module, or assert inside `vim.defer_fn`) before quitting |
| Exit code is 0 even when a `setup()` throws | grep stderr for `Failed to run` and Lua stack traces; in Lua checks exit with `vim.cmd('cquit! 1')` |
| Asynchronous `TSUpdate` output lies ("up-to-date" with no parser installed) | use the synchronous variant and check for `.so`/`.dll` in `stdpath('data')/site/parser/` |
| Deep test paths exceed MAX_PATH on Windows | false failures (failed git checkouts, ENOENT on luac cache); test under a short path |

## Warnings

The goal is **not zero warnings**. Fix the warnings that are, or may become, real problems; leave harmless ones visible as information.

- Do not silence missing provider warnings (`vim.g.loaded_perl_provider = 0` and friends). Seeing that a provider is missing is the point.
- Prefer solutions that *report* (`health.warn`) over solutions that *hide*. A health check may degrade to a warning; it must never become a fatal error and must never drop the information.

## Supported Neovim versions

Follow 'mini.nvim': the current stable release, Nightly, and the two previous stable releases. `configs/` holds one directory per supported version; `setup.lua` picks the highest one the running Neovim satisfies. A feature available only in a newer version goes into that version's config directory, not behind a `vim.fn.has()` branch in an older one.

## Non-goals

- Becoming a distribution: no auto-update mechanism, no plugin abstraction layer, no config of the config.
- A `lua/` module tree for this config.
- Editing `nvim-pack-lock.json` by hand.
- Filetype or language specific logic in the shared `plugin/` files.
- Silencing warnings to make output look clean.

## Checklist before finishing

- [ ] The change lives in the right file, in the right load step.
- [ ] Comments explain why, in the style of their neighbors, with `:h` references.
- [ ] `stylua .` run from the repository root.
- [ ] `CHANGELOG.md` updated if the change is user visible.
- [ ] Verification done in one pass, with the traps above accounted for.
- [ ] One topic per commit; message has the conventional header, the Problem/Solution body, and `Signed-off-by`.
- [ ] Pushed to a branch on `origin`, never to `master` and never to `minimax`.
