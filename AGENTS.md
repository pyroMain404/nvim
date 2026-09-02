# AGENTS.md

This repository is a personal fork of [MiniMax](https://github.com/nvim-mini/MiniMax) (remote `minimax`), the Neovim config generator built around ['mini.nvim'](https://github.com/nvim-mini/mini.nvim). Everything here — the config, its comments, its commits — follows the philosophy of 'mini.nvim'. When in doubt about anything not covered below, read how 'mini.nvim' itself does it (`README.md#general-principles`, `CONTRIBUTING.md`, `MAINTAINING.md` in its repository) and do the same.

Read this file before changing anything. It is short on purpose: it states the rules, not the reasons behind every line of config. The config files themselves are the documentation.

## Project vision

- This is **a config, not a distribution**. There are no automatic updates and no framework layer on top of Neovim. The config is owned and read by its user.
- Config files are **meant to be read**. Every file starts with a comment block explaining what it is for and how to navigate it. A change that makes a file harder to read is a bad change, even if the code is shorter.
- The balance to aim for is the same one 'mini.nvim' aims for: **feature-richness against simplicity of implementation and support**. Prefer the solution that handles the realistic cases and stays understandable a year from now.
- **Configure, do not reimplement.** If a MINI module already does what is needed, use it and adjust its `config` to fit the use case — writing the same behavior from scratch on top of Neovim built-ins is the wrong answer, even when it is possible. The order of preference applies to *choosing what to depend on*, not to how much code to write:
    1. A Neovim built-in, when it already covers the need — do not install anything for it.
    2. A MINI module, configured for the use case.
    3. A plugin outside of MINI, only when neither of the above covers the need. It has to earn its place.

  "Already covers the need" is a judgement, not a fact about where the code lives. Part of what Neovim ships in its runtime is a snapshot of a Vimscript plugin written before LSP and tree-sitter existed, kept alive by the Vim project. Prefer the built-in while it works without friction and costs nothing to maintain. Look further when it is **dated** (read the `Last Change:` header of the runtime file — it is there to be read), when it **duplicates in Vimscript what LSP or tree-sitter do better**, or when the language's own ecosystem has a reference tool the runtime does not know about. Writing glue code to close the gap is the signal that the gap is real. Before installing anything, say what the plugin brings that levels 1 and 2 do not, and check that it does not **turn off what already works** — some plugins take ownership of a language server and refuse to coexist with its manual configuration, which makes the choice exclusive rather than additive.

## General principles

Adapted from `mini.nvim-general-principles` (`:h mini.nvim-general-principles`, also `README.md#general-principles` in the 'mini.nvim' repository).

- **Independence**. Every MINI module is enabled separately with `require('mini.xxx').setup()`. Do not make one module's config depend on another's internals. External dependencies (`git`, `ripgrep`, LSP servers) are optional enhancements, never hard requirements for startup.
- **Setup**. `setup()` creates the global `MiniXxx` object and all intended side effects (mappings, autocommands, highlight groups). Pass **only the parts of `config` that differ from the default**; the rest is inferred. Never copy a whole default config table into this repo just to change one field.
- **Where to change a config value**. Every module reads its settings from the global `MiniXxx.config` table, but it does so at two different moments, and that decides where a change belongs:
    - Settings the module reads **every time it acts** (like `MiniSurround.config.n_lines`) take effect as soon as the table is assigned. They can be changed live from the command line (`:lua MiniSurround.config.n_lines = 50`) or per buffer through `vim.b.minisurround_config`. Use this for experiments and for buffer-local behavior.
    - Settings the module reads **once, while `setup()` runs** (like `mappings`, which create the actual keymaps right there) do not react to a later assignment. Changing them means editing the table passed to `setup()` in `plugin/30_mini.lua` and restarting Neovim.

  A permanent change always ends up in `plugin/30_mini.lua` either way. The distinction matters when trying something out: for the first kind a live assignment is enough, for the second it will silently do nothing.
- **Disabling**. To turn functionality off, use the module's own disabling mechanism (`vim.g.minixxx_disable`, `vim.b.minixxx_disable`) or a buffer-local config. Do not delete the `setup()` call and do not shadow the module's mappings. See `:h mini.nvim-disabling-recipes`.
- **Silencing**. From `README.md#silencing` of 'mini.nvim' (same text in `:h mini.nvim-general-principles`): "Each module providing non-error feedback (like a reminder to press a key after some idle time in 'mini.ai', 'mini.jump2d', 'mini.surround') can be configured to not do that by setting `config.silent = true` (either inside `setup()` call or on the fly)." So: silence that feedback with `config.silent`, not by removing the feature that emits it. The setting exists only in modules that emit such feedback — check `:h MiniXxx.config` before assuming it is there.
- **Highlighting**. Link new highlight groups to a semantically close built-in group instead of hard-coding colors, so any color scheme keeps working.
- **Stability**. Treat the config as released software: avoid churn, and make any change that changes muscle memory (a mapping, a default) a deliberate, documented one.
- **Not filetype and language specific**. Do not grow the shared config with per-language branches. Language specific behavior goes into `after/ftplugin/<filetype>.lua` and `after/lsp/<server>.lua`. See ["Non-goals"](#non-goals) for what this rules out in practice.

## Repository structure

```
setup.lua                 Generator script: copies a config into `stdpath('config')`
configs/README.md         What each config directory is and how it is laid out
configs/nvim-0.12         The config this machine runs — the only one to modify
configs/nvim-0.10 … 0.13  Other reference configs, inherited from upstream
CHANGELOG.md              User visible changes, newest first, dated;
                          this fork's entries go in its bottom section
```

Inside `configs/nvim-0.12` (see `configs/README.md` for the full explanation):

```
init.lua                 First file executed; plugin manager and `Config` helpers
nvim-pack-lock.json      `vim.pack` lockfile — generated, never edited by hand
plugin/10_options.lua    Built-in Neovim behavior
plugin/20_keymaps.lua    Custom mappings, mostly under `<Leader>`
plugin/30_mini.lua       MINI configuration
plugin/31_git.lua        Git integration: 'mini.diff', 'mini.git', and what
                         is built on them
plugin/40_plugins.lua    Plugins outside of MINI
lua/config/health.lua    `:checkhealth config` — the only file under `lua/`
snippets/                User defined snippets
after/ftplugin/          Per filetype behavior
after/lsp/               Language server configurations
after/snippets/          Snippet files that override plugin provided ones
colors/purplehue.lua     Color scheme — generated, never edited by hand
```

- **Only `configs/nvim-0.12` is in use and only it gets modified.** It is what `%LOCALAPPDATA%\nvim` points at, so editing it changes the running config immediately. `nvim-0.10`, `nvim-0.11` and `nvim-0.13` are upstream leftovers: leave them alone, and do not try to keep a change in sync across them.
- Files in `plugin/` are sourced automatically in alphabetical order. This is deliberate: it avoids occupying the shared `lua/` namespace and needs no `require()` calls in `init.lua`. **Do not introduce a `lua/` directory** to modularize this config (one exception: [health checks](#reporting-problems)).
- The number prefixes reserve room for insertion. A genuinely new area of config gets its own `NN_name.lua` file with a number that places it correctly in the load order; it does not get appended to an unrelated file.

### Generated files

Two files in the config are output, not source. They are read to know the current state and regenerated to change it — never edited by hand:

- `nvim-pack-lock.json` is maintained by `vim.pack`. It changes as a *result* of installing, updating or removing plugins (`:h vim.pack-lockfile`).
- `colors/purplehue.lua` was written by 'mini.colors' (see its first line) from a palette produced by `MiniHues.make_palette()`. To change a color, regenerate the scheme from the palette — do not patch the 800 lines of `nvim_set_hl()` calls it contains.

## Where a change goes

- **An option of Neovim itself** → `plugin/10_options.lua`.
- **A mapping** → `plugin/20_keymaps.lua`, under the existing `<Leader>` group that matches its meaning, with a `mini.clue` description.
- **A MINI module or its config** → `plugin/30_mini.lua`, in the same step as comparable modules (see below). The one exception is Git: `plugin/31_git.lua` holds 'mini.diff', 'mini.git' and the integration built on them, because that area outgrew a module setup — two modules answering the same question plus the code making them work together. Nothing else moves out of `plugin/30_mini.lua` for being long.
- **A non-MINI plugin** → `plugin/40_plugins.lua`, added through `vim.pack.add()`.
- **Behavior for one filetype or one language server** → `after/ftplugin/` or `after/lsp/`, never the shared files.
- **A new external program the config depends on** → installed through `mise`, and reported by the health check. See below.

## External dependencies

Language servers, formatters, linters and language runtimes are installed with [`mise`](https://mise.jdx.dev) (*mise-en-place*), which declares tools in a config file and installs them with a single `mise install`. This is the answer to "how do I get this working on a new machine", and it is what makes the setup reproducible instead of a sequence of commands nobody remembers.

- `mise` covers the role usually given to 'mason.nvim' — which stays disabled on purpose (see the honorable mentions in `plugin/40_plugins.lua`), because it installs programs usable almost only inside Neovim. It does **not** replace 'nvim-lspconfig': the two are orthogonal, `mise` provides the binary and 'nvim-lspconfig' knows how to talk to it (`cmd`, `filetypes`, `root_markers`).
- Tools needed everywhere (language servers, formatters) belong to `mise`'s **global** config; a project's runtime versions belong to the `mise.toml` **of that project**, which follows whoever clones it. When the registry does not know a name, a backend usually covers it (`aqua:`, `npm:`, `cargo:`, `go:`, `pipx:`).
- Where a language has its own official channel that keeps the server aligned with the compiler (`rustup component add` for Rust), prefer it: one place for dependencies is a good rule right up to the point where it makes the result worse.
- **Neovim inherits the environment of the shell that started it.** With shell activation, the active version is the one from the moment of launch — a session opened yesterday keeps yesterday's toolchain. `mise`'s shims avoid this because they sit on `PATH` regardless of how Neovim was started. Either way, the health check is what says which version is actually in use, and that is the first thing to suspect when a server behaves differently from the command line.
- This does not weaken **Independence**: a missing tool degrades a feature, it never stops startup. `mise` is how dependencies are declared and installed, not something the config requires in order to run.
- Every dependency added lands in two places or it does not exist: the health check that verifies it, and the reference of the language that needs it.

## Code style

- **Formatting follows `.stylua.toml`.** [StyLua](https://github.com/JohnnyMorganz/StyLua) is installed, so formatting is checked with `stylua --check <path>` and applied with `stylua <path>` — not by eye. Run it from inside the repository, since StyLua looks for `.stylua.toml` walking up from the file it is formatting; a file checked from elsewhere is silently formatted with StyLua's own defaults (tabs, double quotes) and the diff is meaningless.

  Two settings exist so that a whole-config run is quiet and its output means something. `line_endings = "Windows"` matches the CRLF that `core.autocrlf` puts in the working tree — with the upstream `"Unix"` value StyLua rewrote every line of every file and the report was pure noise. `.styluaignore` excludes the generated color scheme, which is output and must not be reformatted.

  One known diff remains, in `plugin/30_mini.lua`, where StyLua wants to move a comment placed inside a string concatenation. That code comes from upstream and the change is cosmetic, so it is left alone: reformatting inherited code to silence the formatter buys nothing and costs a conflict.

  What the file mandates:
    - 2 space indent, spaces only.
    - Single quotes preferred (`quote_style = "AutoPreferSingle"`).
    - Maximum line width 85 — narrower than upstream 'mini.nvim' (120), because these files are read side by side.
    - Parentheses always on calls, even single-argument ones (`require('mini.ai')`, never `require 'mini.ai'`).
    - Simple statements collapsed onto one line (`if cond then return end`).
- Startup order is expressed with the `Config` helpers defined in `init.lua`, not with ad-hoc timers:
    - `now(f)` — needed for the first screen draw.
    - `now_if_args(f)` — needed for the first draw only when Neovim is started with a file argument.
    - `later(f)` — everything else, deferred until after the first draw.

  Adding a module to the wrong step is a startup time regression; put it in `later()` unless it draws on the first screen.
- Keep the section separators of `plugin/30_mini.lua` visible and put every new `setup()` call under the right one. There are three:
    - `-- Step one ===...` — enabled with `now()`: everything needed for the first draw.
    - `-- Step one or two ===...` — enabled with `now_if_args()`: needed for the first draw only when a file argument was given.
    - `-- Step two ===...` — enabled with `later()`: everything else.

  The other files use the same separator style for their own topics (`-- UI ===...`, `-- Editing ===...` in `10_options.lua`; `-- General mappings ===...`, `-- Leader mappings ===...` in `20_keymaps.lua`; `-- Tree-sitter ===...`, `-- Language servers ===...`, `-- Formatting ===...`, `-- Snippets ===...`, `-- Honorable mentions ===...` in `40_plugins.lua`).
- No leftovers: no commented-out experiments (except the ones that already exist as documented alternatives, like the color scheme lines), no debug prints, no notification used as a log.

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

### Keywords in comments

Four words are highlighted, and only those four: `plugin/30_mini.lua` configures 'mini.hipatterns' with `FIXME`, `HACK`, `TODO` and `NOTE`. Anything else (`XXX`, `WARN`, `PERF`) is neither highlighted nor found by `:Pick hipatterns`, so as a marker it does not exist. Write the word in uppercase, at the start of the comment, followed by a colon.

- **`HACK`** — code that exists only because something outside this repository is broken or missing. The test is what happens if upstream fixes it tomorrow: a HACK is **deleted**, not rewritten. Say what upstream does wrong, why the workaround sits where it does, and **the version in which the problem is still present** — that last part is what makes it retestable after the next `vim.pack.update()`, and without it a workaround becomes scar tissue nobody dares to remove.
- **`FIXME`** — something in this config is broken right now and is not worked around: whoever reads it has to know not to trust that piece. The difference from HACK is where the fault is, not how bad it is — HACK is broken elsewhere and compensated here, FIXME is broken here and left as is. A FIXME that gets worked around becomes a HACK; a HACK that stops being needed is deleted, never downgraded to a FIXME.
- **`TODO`** — work deferred on purpose, to be done here. It has to be startable: what, why not now, and the first step, so that whoever picks it up does not have to redo the analysis. Anything that does not reach that bar is a wish and does not belong in the code.
- **`NOTE`** — no pending work. A constraint, a non-obvious behavior of an API, a known limit: what a reader needs in order not to be surprised, or not to break the code with an innocuous looking edit. Never to explain *what* the code does.

Configuring a module, or composing several of them into a behavior none of them provides alone, is not a HACK however much glue it takes: that is the config doing its job. And plain documentation takes no keyword at all. The four words are an index, and an index that lists everything indexes nothing — the more so once the markers are collected into a list, which is the TODO standing in `plugin/30_mini.lua`.

## Reporting problems

When config code detects something wrong — a missing executable, a buffer that is not a file, a command that failed — report it through one of these, and nothing else. The choice is between "the user needs to know now" and "the user will find out when they go looking".

- **`vim.notify(msg, vim.log.levels.WARN)` — the default.** This is what the config already uses (`plugin/20_keymaps.lua`). Because `mini.notify` is set up in `plugin/30_mini.lua`, `setup()` has already replaced `vim.notify` with its own implementation (`:h MiniNotify.make_notify()`), so the message shows in the upper right corner, fades on its own, and stays in the history reachable with `<Leader>en` (`MiniNotify.show_history()`).
    - `WARN` for something that degraded but did not stop: a fallback was taken, a feature is unavailable.
    - `ERROR` for the requested action failing outright — the mapping did nothing and the user must know why.
    - `INFO` (the default level) for confirmations worth seeing, like `Diff reference: <rev>` in `20_keymaps.lua`.
- **`vim.notify_once()`** for a condition that is detected repeatedly but is worth saying once per session — typically something found at startup, like an optional executable being absent. Same arguments as `vim.notify()` (`:h vim.notify_once()`).
- **`vim.health.*` inside a health check** for the state of the environment: what is installed, what version, what is missing. This is what `:checkhealth` is for, and it is the right place for problems the user is not blocked by right now. Use `vim.health.start()` once per section, then `ok()`, `info()`, `warn(msg, advice)`, `error(msg, advice)` — `warn` and `error` take an optional second argument with advice on how to fix it (`:h health-dev`).

  A check of this config's own assumptions needs a module returning `{ check = function() ... end }` under `lua/`. This is the one admitted exception to the "no `lua/` directory" rule; see below for how to write it.
- **`vim.deprecate()`** when a helper of this config is kept working but should stop being used (`:h vim.deprecate()`).
- **Never `error()` at config level.** A raised error during startup aborts the rest of the file and leaves a half-configured Neovim. Report and continue.

### Writing the health check

**One file — `lua/config/health.lua`, run as `:checkhealth config` — with one `health.start()` section per area. Not one `health.lua` per config directory.**

`:checkhealth` discovers any `lua/**/health.lua` (or `lua/**/health/init.lua`) on the 'runtimepath' and names the check after its path, so `lua/config/options/health.lua` would work and give `:checkhealth config.options`. It is still the wrong shape here, and Neovim's own runtime says so: across the six healthcheck modules it ships (`vim.deprecated`, `vim.health`, `vim.lsp`, `vim.pack`, `vim.provider`, `vim.treesitter` — `lua/vim/health.lua` itself is the reporting API, not a check) and the three provided by the plugins installed here, **every one is a single file per subsystem holding several sections** — `vim.lsp` has six sections in 279 lines, `vim.pack` three in 265, `vim.treesitter` three in 111, `vim.health` itself eight in 715, and `vim.provider` covers clipboard, Node.js, Perl, Python and Ruby in one 953-line file, the largest in the runtime. None of them splits by section.

Neovim in fact went the other way once. The `bad_files` list in `$VIMRUNTIME/lua/vim/health/health.lua` — files whose presence makes `:checkhealth` report a leftover installation — includes `lua/provider/node/health.lua`, `lua/provider/perl/health.lua`, `lua/provider/python/health.lua` and `lua/provider/ruby/health.lua`. The per-provider split existed and was merged back into the single `vim/provider/health.lua`.

The dividing line those files draw is **"is this a subsystem worth interrogating on its own?"**, not "is this a separate directory". `:checkhealth vim.lsp` is worth asking alone; `:checkhealth config.keymaps` answers a question nobody has. This config is one subsystem, so it gets one file, and size is not a reason to split it — 953 lines were not.

Follow the shape those files share (`vim/health/health.lua` is the clearest example):

```lua
local M = {}
local health = vim.health

local function check_external_tools()
  health.start('config: external tools')
  -- ... health.ok() / health.warn(msg, advice) ...
end

function M.check()
  check_external_tools()
  -- ... one call per area, in the order they should be read ...
end

return M
```

- One local `check_*()` function per area, called in order from `M.check()`. That is the whole file structure.
- Open each with `health.start('<title>')`. Prefix the title with the namespace when it could be mistaken for another plugin's section — `vim.lsp` and `vim.pack` do this (`vim.lsp: Active Clients`, `vim.pack: lockfile`), `vim.provider` does not need to (`Ruby provider (optional)`).
- Always pass advice to `warn()` and `error()`: the second argument is a string or a list of strings saying how to fix it. The runtime checks almost never omit it.
- Return early from a check that does not apply, before calling `start()` — `check_tmux()` does nothing outside tmux, `check_terminal()` nothing without `infocmp`. An empty section is worse than an absent one.
- Close a section that found nothing wrong with an explicit `health.ok()`, so it is never silent. Start the message with a capital letter: the runtime is inconsistent here — `check_config()` writes `no issues found`, while `No deprecated functions detected`, `Up to date` and `Setup is correct` capitalise — and the capitalised form is both the majority and the one that reads as a sentence next to `warn()` and `error()` messages.

### Which warnings to fix

The goal is **not zero warnings**. Fix the warnings that are, or may become, real problems; leave harmless ones visible as information.

- Do not silence missing provider warnings (`vim.g.loaded_perl_provider = 0` and friends). Seeing that a provider is missing is the point.
- Prefer solutions that *report* over solutions that *hide*. A health check may degrade to a warning; it must never become a fatal error and must never drop the information.

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

- `<type>` is mandatory and is **one of exactly these seven**: `ci`, `docs`, `feat`, `fix`, `refactor`, `style`, `test`. The list is closed — 'mini.nvim' enforces it in `scripts/lintcommit.lua` (`allowed_commit_types`), which rejects anything else. **`chore` is not allowed**; what usually gets called `chore` belongs to `ci` (automation), `docs` (documentation), `style` (formatting and conventions) or `refactor` (changes users do not see). Use `fixup` for temporary commits meant to be squashed.
- `<scope>` is mandatory and names the affected area: `git`, `keymaps`, `options`, `mini`, `plugins`, `colorscheme`, … Use `ALL` for a rule enforced across the whole config.
- `!` before `:` marks a breaking change (a mapping that disappears, a default that flips).
- The subject **states the problem, not the fix**: not `fix typo in path handling`, but ``  `gf` inside a patch breaks when the repository path has a space``. Imperative present tense, under 72 characters, no capital first word, no trailing punctuation.
- Alignment in the body: two spaces after `Problem:`, one after `Solution:`, continuation lines indented to column 10.
- Refer to functions and fields without the module prefix where the scope already says it (`add()`, not `MiniSurround.add()`).
- Footers: `Resolve #xxx` / `Related to #yyy` first, then Git trailers. `Signed-off-by:` is always present.
- **One commit does one thing.** A change that does three things is three commits. If the working tree mixes topics, split it by topic — staging individual hunks if needed — instead of committing them together.

## Typical workflow for adding change

Adapted from `MAINTAINING.md#typical-workflow-for-adding-change`, minus everything that only makes sense for a shared project. This config has a single author working directly on `minimax-config`: no feature branches, no pull requests, no review.

1. Solve the problem, in `configs/nvim-0.12`. Keep the change as local as the problem is.
2. Make sure it still reads well: comments updated, `:h` references still correct, file structure and separators intact, formatting per `.stylua.toml`.
3. If the change is worth being seen later (a notable or breaking feature or fix), add an entry to `CHANGELOG.md` — in the **"Fork changes" section at the bottom of the file**, never at the top. See below.
4. Verify (see next section). Do it once, at the end.
5. Commit on `minimax-config`, following the message rules above, and push to `origin`.
6. Never force-push, and never push to the `minimax` remote — it is upstream, read only. A change worth sending upstream is a separate matter: MiniMax's pull request template rejects changes based on personal taste (enabling a new option, installing a new plugin), which is exactly what belongs in this fork, so keep the two apart.

### Changelog entries

`CHANGELOG.md` holds two logs that must not be interleaved:

- Everything above the `# Fork changes` heading is **upstream's**, newest first. It is not edited here.
- Everything below it belongs to **this fork**, newest first within its own section.

The split exists for one reason: upstream always adds its entries at the **top** of the file. An entry of this fork placed there touches the same lines as the next upstream release and turns every merge from `minimax` into a conflict over a file where conflicts carry no information. At the bottom, upstream never reaches, and the merge stays clean.

Follow the formatting of the entries already in the section: a `## YYYY-MM-DD` heading, then one dash-prefixed sentence per change, blank line between entries.

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

## Supported Neovim versions

This config targets the Neovim installed on this machine (currently 0.12), which is what `configs/nvim-0.12` is for. Upstream 'mini.nvim' supports the current stable, Nightly and the two previous stable releases; this fork does not need to. A feature available only in a newer Neovim waits until that Neovim is installed here — it does not get wrapped in a `vim.fn.has()` branch, and it does not justify touching the other `configs/` directories.

## Non-goals

- Becoming a distribution: no auto-update mechanism, no plugin abstraction layer, no config of the config.
- A `lua/` module tree for this config, except the single `lua/config/health.lua` for [health checks](#writing-the-health-check).
- Editing generated files by hand: `nvim-pack-lock.json`, `colors/purplehue.lua`.
- Keeping `configs/nvim-0.10`, `nvim-0.11` and `nvim-0.13` in sync with the config actually in use.
- Silencing warnings to make output look clean.
- **Filetype or language specific logic in the shared `plugin/` files.** Concretely, none of these belong in `plugin/`:
    - a branch on the current filetype (`if vim.bo.filetype == 'python' then ...`) to set options, mappings or autocommands — that is `after/ftplugin/python.lua`;
    - settings for one language server — that is `after/lsp/<server>.lua`, picked up by `vim.lsp.enable()`;
    - snippets for one language — that is `after/snippets/<lang>.json`.

  What *does* belong in `plugin/40_plugins.lua` is the language-agnostic machinery those files rely on: installing and configuring `nvim-treesitter`, `conform.nvim`, the list of servers passed to `vim.lsp.enable()`. The rule is about per-language *behavior*, not about tools that happen to be aware of languages.

## Checklist before finishing

- [ ] The change is in `configs/nvim-0.12`, in the right file, under the right separator and load step.
- [ ] Comments explain why, in the style of their neighbors, with `:h` references.
- [ ] `stylua --check` passes on the files touched (run from inside the repository; see the note about CRLF).
- [ ] Problems are reported through `vim.notify` / `vim.notify_once` / a health check — never `error()`.
- [ ] No generated file edited by hand.
- [ ] `CHANGELOG.md` updated if the change is worth being seen later, in the "Fork changes" section at the bottom.
- [ ] Verification done in one pass, with the traps above accounted for.
- [ ] One topic per commit; message has an allowed type, the Problem/Solution body, and `Signed-off-by`.
- [ ] Committed on `minimax-config` and pushed to `origin`, never to `minimax`.
