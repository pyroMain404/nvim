# AGENTS.md

This repository is a personal Neovim configuration, built around ['mini.nvim'](https://github.com/nvim-mini/mini.nvim). It started as a fork of [MiniMax](https://github.com/nvim-mini/MiniMax), the Neovim config generator MiniMax's author built around the same plugin — the structure, the `Config` helpers, and much of the documentation style below trace back to it. As of 2026-09-22 this repository is standalone: it carries no upstream remote, no reference configs for other Neovim versions, and no generator script. It is this config, kept and read by its one user. Everything here — the config, its comments, its commits — still follows the philosophy of 'mini.nvim'. When in doubt about anything not covered below, read how 'mini.nvim' itself does it (`README.md#general-principles`, `CONTRIBUTING.md`, `MAINTAINING.md` in its repository) and do the same.

Read this file before changing anything. It is short on purpose: it states the rules, not the reasons behind every line of config. The config files themselves are the documentation.

## Project vision

- This is **a config, not a distribution**. There are no automatic updates and no framework layer on top of Neovim. The config is owned and read by its user.
- Config files are **meant to be read**. Every file starts with a box title and at most three lines saying what it is for. A change that makes a file harder to read is a bad change, even if the code is shorter.
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
init.lua                 First file executed; the `Config` helpers (`new_autocmd`, `on_packchanged`, `now`, `later`, `now_if_args`)
nvim-pack-lock.json      `vim.pack` lockfile — generated, never edited by hand
plugin/10_options.lua    Built-in Neovim behavior
plugin/20_keymaps.lua    Custom mappings, mostly under `<Leader>`
plugin/30_mini.lua       MINI configuration
plugin/40_plugins.lua    Plugins outside of MINI
plugin/50_features.lua   Switches on the in-house modules that need `setup()` at startup
lua/config/toolchain.lua The one declaration of languages: parsers, servers, formatters, tools, versions
lua/config/git/          Git workflow on 'mini.diff' and 'mini.git' (core, diffref, blame, log, patch, lazygit, autocmds, init)
lua/config/format.lua    What a format pass touches
lua/config/review.lua    Files opened to be read as a set
lua/config/winbar.lua    Tree-sitter breadcrumb
lua/config/make.lua      Asynchronous `:Make`/`:LMake` and the outcome report
lua/config/lsp.lua       Client side LSP fixes
lua/config/markers.lua   Comment markers: hipatterns commands and word table
lua/config/markdown.lua  Markdown buffer behavior (attach/detach)
lua/config/obsidian.lua  'obsidian.nvim' setup
lua/config/ft.lua        ftplugin boilerplate: undo, tree-sitter folds, build, Maven
lua/config/run.lua       `:Run` resolver
lua/config/mise.lua      Shared `mise` query, with `newest()`; required by `after/lsp/` files
lua/config/health.lua    `:checkhealth config`; found by path, not required
lua/config/              Also `path`, `pick`, `glance` and `mdlink`: small shared helpers
snippets/                User defined snippets
compiler/                `:compiler` plugins for `:make`
ftdetect/                Filetype detection rules
after/ftplugin/          Per filetype behavior
after/lsp/               Language server configurations
after/queries/           Tree-sitter query overrides
after/snippets/          Snippet files that override plugin provided ones
CHANGELOG.md             User visible changes, newest first, dated
.omp/                    Skills and project-environment reference docs
docs/                    Frozen pre-implementation records
.stylua.toml             StyLua formatter configuration
.styluaignore            Files excluded from formatting
```

- **This repository root is `%LOCALAPPDATA%\nvim`** (cloned there directly, see `pyro-resources/modules/editors/install.ps1`), so editing any file here changes the running config immediately. There is no other copy to keep in sync.
- Files in `plugin/` are sourced automatically in alphabetical order and only wire: options, mappings, MINI, plugin declarations, and the `setup()` calls of `plugin/50_features.lua`. Behavior lives in `lua/config/<area>.lua` or `lua/config/<area>/`. A module that must exist from startup (autocommands, commands) exposes `setup()`, called from `plugin/50_features.lua` (the Git workflow: `config.git.autocmds`); every other module is required by name on first use.
- The number prefixes reserve room for insertion. A genuinely new area of config gets its own `NN_name.lua` file with a number that places it correctly in the load order; it does not get appended to an unrelated file.

### Generated files

One file in the config is output, not source. It is read to know the current state and regenerated to change it — never edited by hand:

- `nvim-pack-lock.json` is maintained by `vim.pack`. It changes as a *result* of installing, updating or removing plugins (`:h vim.pack-lockfile`).

## Where a change goes

- **An option of Neovim itself** → `plugin/10_options.lua`.
- **A mapping** → `plugin/20_keymaps.lua`, under the existing `<Leader>` group that matches its meaning, with a `mini.clue` description.
- **A MINI module or its config** → `plugin/30_mini.lua`, in the same step as comparable modules (see below). This holds for every module without exception, 'mini.diff' and 'mini.git' included: a `setup()` call belongs there and nowhere else, and no module moves out of that file for being long.
- **Behavior built on top of MINI modules, or shared helpers** → `lua/config/<area>.lua` or `lua/config/<area>/`. One rule: it gets a `setup()` (autocommands, commands) called from `plugin/50_features.lua` only when it must exist from startup; otherwise it is required by name on first use, from a mapping, an ftplugin, an `after/lsp/` file or the health check. `plugin/` files do not hold behavior. A new module is justified only when the code is an area of its own rather than the configuration of something that already exists.
- **A non-MINI plugin** → `plugin/40_plugins.lua`, added through `vim.pack.add()`.
- **Behavior for one filetype or one language server** → `after/ftplugin/` or `after/lsp/`, never the shared files.
- **A tree-sitter query override** → `after/queries/<lang>/<name>.scm`, starting with `; extends` unless you mean to replace everything.
- **A `:compiler` plugin** → `compiler/<tool>.lua`, picked by `:compiler <tool>` in an ftplugin.
- **A new filetype detection rule** → `ftdetect/<name>.lua`, only when Neovim does not already recognize the extension.
- **Boilerplate shared by ftplugins** (undo, tree-sitter folds, build, Maven) → `lua/config/ft.lua`, called from `after/ftplugin/`.
- **A new external program the config depends on** → installed through `mise`, and reported by the health check. See below.

## External dependencies

Language servers, formatters, linters and language runtimes are installed with [`mise`](https://mise.jdx.dev) (*mise-en-place*), which declares tools in a config file and installs them with a single `mise install`. This is the answer to "how do I get this working on a new machine", and it is what makes the setup reproducible instead of a sequence of commands nobody remembers.

- `mise` covers the role usually given to 'mason.nvim' — which stays out on purpose, because it installs programs usable almost only inside Neovim. It does **not** replace 'nvim-lspconfig': the two are orthogonal, `mise` provides the binary and 'nvim-lspconfig' knows how to talk to it (`cmd`, `filetypes`, `root_markers`).
- Tools needed everywhere (language servers, formatters) belong to `mise`'s **global** config; a project's runtime versions belong to the `mise.toml` **of that project**, which follows whoever clones it. When the registry does not know a name, a backend usually covers it (`aqua:`, `npm:`, `cargo:`, `go:`, `pipx:`).
- **A server that loads a library from the project belongs to both places at once.** `ngserver` is a shell around the `@angular/language-service` it finds in the project's 'node_modules', so its major has to be the project's rather than the newest. The global entry is what makes the server exist at all for a project that pins nothing; the pin in that project's own `mise.toml` is what makes it correct, because shims resolve by current directory and Neovim starts the server through a shim. A mismatch is invisible from inside Neovim - the client attaches and no diagnostic ever arrives - which is why `:checkhealth config` prints the major the project needs next to the command that installs it.
- **`mise` is not where every program comes from, only the ones this config assumes.** The dividing question is what breaks when the program is absent: a language server, a formatter, a linter, `ripgrep`, `lazygit` or the `tree-sitter` CLI breaks or slows *this configuration*, and belongs to `mise` so that it is declared and reproducible. `git` is an ordinary system utility that every other tool assumes: it comes from the system package manager, and the health check advises that one for it. Installing it through `mise` buys nothing and adds a version to keep.
- Where a language has its own official channel that keeps the server aligned with the compiler (`rustup component add` for Rust), prefer it: one place for dependencies is a good rule right up to the point where it makes the result worse.
- **Neovim inherits the environment of the shell that started it.** With shell activation, the active version is the one from the moment of launch — a session opened yesterday keeps yesterday's toolchain. `mise`'s shims avoid this once their directory is on the system `PATH` — but `mise` does not put it there on Windows, and until someone does, a tool installed through `mise` is invisible to a Neovim started from an icon or a launcher, which is the normal case here. Either way, the health check is what says which version is actually in use, and that is the first thing to suspect when a server behaves differently from the command line.
- This does not weaken **Independence**: a missing tool degrades a feature, it never stops startup. `mise` is how dependencies are declared and installed, not something the config requires in order to run.
- Every language or tool the config depends on is declared once in `lua/config/toolchain.lua`; the plugins and the health check read it. Add it there, and to the reference of the language that needs it.

## Code style

- **Formatting follows `.stylua.toml`.** [StyLua](https://github.com/JohnnyMorganz/StyLua) is installed, so formatting is applied with `stylua <path>` — not by eye. How to run the check so that its output means anything belongs to verification, and is therefore in the `nvim-config-testing` skill.
- Startup order is expressed with the `Config` helpers defined in `init.lua`, not with ad-hoc timers:
    - `now(f)` — needed for the first screen draw.
    - `now_if_args(f)` — needed for the first draw only when Neovim is started with a file argument.
    - `later(f)` — everything else, deferred until after the first draw.

  Adding a module to the wrong step is a startup time regression; put it in `later()` unless it draws on the first screen.
- Keep the section separators of `plugin/30_mini.lua` visible and put every new `setup()` call under the right one. There are three:
    - `-- Step one ===...` — enabled with `now()`: everything needed for the first draw.
    - `-- Step one or two ===...` — enabled with `now_if_args()`: needed for the first draw only when a file argument was given.
    - `-- Step two ===...` — enabled with `later()`: everything else.

  The other files use the same separator style for their own topics (`-- UI ===...`, `-- Editing ===...` in `10_options.lua`; `-- General mappings ===...`, `-- Leader mappings ===...` in `20_keymaps.lua`; `-- Tree-sitter ===...`, `-- Language servers ===...`, `-- Formatting ===...`, `-- Snippets ===...` in `40_plugins.lua`).
- No leftovers: no commented-out experiments (except the ones that already exist as documented alternatives, like the color scheme lines), no debug prints, no notification used as a log.

## Comment policy

The comment style is part of the config, not decoration. Match the surrounding file.

- File headers and major sections use a box, and a header is the box title plus at most three lines:

    ```lua
    -- ┌────────────────────┐
    -- │ MINI configuration │
    -- └────────────────────┘
    ```

- At most one purpose line plus a `:h` reference per `setup()` call or mapping group. Reference documentation through help tags (`:h vim.pack-lockfile`), not through URLs.
- Explain *why*, not *what*. No `Example usage:` lists, no tutorial prose, no commented-out code (the color scheme alternatives excepted), no ticket labels, no private project or machine names.
- Use the notation conventions already stated in `init.lua`: `<Space>fh` for key sequences, 'path/to/file' for paths, `:h xxx` for help.

### Keywords in comments

Four words are highlighted, and only those four: `plugin/30_mini.lua` configures 'mini.hipatterns' with `FIXME`, `HACK`, `TODO` and `NOTE`; `lua/config/markers.lua` holds the word table. Anything else is neither highlighted nor found by `:Pick hipatterns`. Write the word in uppercase, at the start of the comment, followed by a colon.

- **`HACK`** — code that exists only because something outside this repository is broken or missing; a HACK is **deleted** when upstream fixes it, not rewritten. Say what upstream does wrong and end with `(<name> <rev>, locked <date>, not retested)`: the revision in which the problem was last seen, which makes it retestable after the next `vim.pack.update()`.
- **`FIXME`** — something in this config is broken right now and is not worked around. A FIXME that gets worked around becomes a HACK; a HACK that stops being needed is deleted, never downgraded to a FIXME.
- **`TODO`** — work deferred on purpose, to be done here, with what, why not now and the first step. Anything that does not reach that bar is a wish and does not belong in the code.
- **`NOTE`** — no pending work: a constraint or non-obvious behavior, at most three lines, never to explain *what* the code does.

## Reporting problems

When config code detects something wrong — a missing executable, a buffer that is not a file, a command that failed — report it through one of these, and nothing else. The choice is between "the user needs to know now" and "the user will find out when they go looking".

- **`vim.notify(msg, vim.log.levels.WARN)` — the default.** This is what the config already uses (`plugin/20_keymaps.lua`). Because `mini.notify` is set up in `plugin/30_mini.lua`, `setup()` has already replaced `vim.notify` with its own implementation (`:h MiniNotify.make_notify()`), so the message shows in the upper right corner, fades on its own, and stays in the history reachable with `<Leader>en` (`MiniNotify.show_history()`).
    - `WARN` for something that degraded but did not stop: a fallback was taken, a feature is unavailable.
    - `ERROR` for the requested action failing outright — the mapping did nothing and the user must know why.
    - `INFO` (the default level) for confirmations worth seeing, like `Diff reference: <rev>` in `20_keymaps.lua`.
- **`vim.notify_once()`** for a condition that is detected repeatedly but is worth saying once per session — typically something found at startup, like an optional executable being absent. Same arguments as `vim.notify()` (`:h vim.notify_once()`).
- **`vim.health.*` inside a health check** for the state of the environment: what is installed, what version, what is missing. This is what `:checkhealth` is for, and it is the right place for problems the user is not blocked by right now. Use `vim.health.start()` once per section, then `ok()`, `info()`, `warn(msg, advice)`, `error(msg, advice)` — `warn` and `error` take an optional second argument with advice on how to fix it (`:h health-dev`).

  A check of this config's own assumptions needs a module returning `{ check = function() ... end }` under `lua/`; see below for how to write it.
- **`vim.deprecate()`** when a helper of this config is kept working but should stop being used (`:h vim.deprecate()`).
- **Never `error()` at config level.** A raised error during startup aborts the rest of the file and leaves a half-configured Neovim. Report and continue.

### Writing the health check

**One file — `lua/config/health.lua`, run as `:checkhealth config` — with one `health.start()` section per area. Not one `health.lua` per config directory.**

`:checkhealth` discovers any `lua/**/health.lua` (or `lua/**/health/init.lua`) on the 'runtimepath' and names the check after its path, so `lua/config/options/health.lua` would work and give `:checkhealth config.options`. It is still the wrong shape here, and Neovim's own runtime says so: across the six healthcheck modules it ships (`vim.deprecated`, `vim.health`, `vim.lsp`, `vim.pack`, `vim.provider`, `vim.treesitter` — `lua/vim/health.lua` itself is the reporting API, not a check) and the three provided by the plugins installed here, **every one is a single file per subsystem holding several sections** — `vim.lsp` has six sections in 279 lines, `vim.pack` three in 265, `vim.treesitter` three in 111, `vim.health` itself eight in 715, and `vim.provider` covers clipboard, Node.js, Perl, Python and Ruby in one 953-line file, the largest in the runtime. None of them splits by section.

Neovim in fact went the other way once. The `bad_files` list in `$VIMRUNTIME/lua/vim/health/health.lua` — files whose presence makes `:checkhealth` report a leftover installation — includes `lua/provider/node/health.lua`, `lua/provider/perl/health.lua`, `lua/provider/python/health.lua` and `lua/provider/ruby/health.lua`. The per-provider split existed and was merged back into the single `vim/provider/health.lua`.

The dividing line those files draw is **"is this a subsystem worth interrogating on its own?"**, not "is this a separate directory". `:checkhealth vim.lsp` is worth asking alone; `:checkhealth config.keymaps` answers a question nobody has. This config is one subsystem, so it gets one file, and size is not a reason to split it.

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

## The documentation system

Each document owns one kind of rule; cite the file and the heading, never a `§N` section number, because section numbers break silently when a document is reordered.

| Document | What it owns |
|---|---|
| `AGENTS.md` | Repository rules, where changes go, commit style, external dependencies, and this citation rule. |
| `.omp/skills/nvim-config-testing/SKILL.md` | What to verify, when, what to hand back to the user instead of simulating it, and the antipatterns already paid for. |
| `.omp/skills/nvim-headless-probes/SKILL.md` | The headless probes and the traps of the probe bench itself. |
| `.omp/skills/nvim-shell-traps/SKILL.md` | Traps of the Windows shell and tools met while verifying or editing the config. |
| `.omp/skills/nvim-runtime-traps/SKILL.md` | Neovim and plugin behaviours that make a check lie. |
| `.omp/skills/nvim-project-environment/SKILL.md` | Project-level overrides through `.nvim.lua` and the project registry. |
| `.omp/skills/nvim-language-support/SKILL.md` | The procedure for adding or extending support for a language: scope, contracts, implementation. |
| `.omp/skills/nvim-language-inventory/SKILL.md` | Phases 1-2 of that procedure: what the runtime and installed plugins already cover, and whether it is enough. |
| `.omp/skills/nvim-mise-toolchain/SKILL.md` | Phase 4 of that procedure: declaring and installing a language's programs with `mise`. |
| `.omp/skills/nvim-language-troubleshooting/SKILL.md` | Symptom to layer to command, for a language already configured that misbehaves. |
| `.omp/skills/nvim-language-support/references/capabilities.md` | The catalogue of axes a language can cover and the mechanisms behind each. |
| `.omp/skills/nvim-language-support/references/<lang>.md` | The per-language outcome of phases 1, 2 and 4-5, the daily cycle, and language-specific verification. |
| `.omp/skills/nvim-language-support/references/language-declaration.md` | The anatomy shared by every language declaration: what file declares what, the contract, what breaks when it is missing, and the skeleton in `assets/`. |
| `.omp/skills/nvim-language-support/assets/` | Skeletons for the files a new language repeats. |
| `.omp/skills/godot-project-setup/SKILL.md` | Godot-specific setup and the Neovim-Godot integration. |
| `docs/analisi_funzionale_<lang>.md` | Frozen pre-implementation records: the analysis that led to the implementation. They are never edited after the implementation commit; when they disagree with a reference, the reference wins. |

`docs/ENGINE_AUDIT.md` is appended during an audit and is not a rule owner: it records which findings were fixed, left or rejected, with the evidence that decided them.

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

Adapted from `MAINTAINING.md#typical-workflow-for-adding-change`, minus everything that only makes sense for a shared project. This config has a single author working directly on `minimax-config`: no feature branches, no pull requests, no review, and — since 2026-09-22 — no upstream to keep separate from.

1. Solve the problem, in the right file. Keep the change as local as the problem is.
2. Make sure it still reads well: comments updated, `:h` references still correct, file structure and separators intact, formatting per `.stylua.toml`.
3. If the change is worth being seen later (a notable or breaking feature or fix), add an entry to `CHANGELOG.md` — at the top of the file. See below.
4. Verify, following the `nvim-config-testing` skill. Do it once, at the end.
5. Commit on `minimax-config`, following the message rules above, and push to `origin`.
6. Never force-push.

### Changelog entries

`CHANGELOG.md` newest first, one `## YYYY-MM-DD` heading with one dash-prefixed sentence per change, blank line between entries. Before 2026-09-22 the file held two logs — MiniMax's own history above a `# Fork changes` heading, this fork's entries below it, kept apart so this fork's additions would never conflict with upstream's own top-of-file entries on merge. That split is now historical: this repository carries no upstream remote to merge from, so new entries go at the top like any ordinary changelog. The old two-part history below `# Fork changes` is left as it was written; it is not backfilled or reformatted.

## Verifying a change

There is no test suite in this repository. Verification is manual, deliberate, and described in **four skills that do not overlap**: `nvim-config-testing` holds the rules (what is worth checking, when to check it, what to hand back to the user instead of simulating it) and the antipatterns already paid for; `nvim-headless-probes` holds a parameterised probe for every common operation and the traps of the probe bench itself; `nvim-shell-traps` holds the Windows shell and tool traps; and `nvim-runtime-traps` holds the Neovim and plugin behaviours that make a check lie.

Nothing about *how* to verify is written here, or in any other document of this repository: a rule kept in two places diverges at the first update, and from then on neither copy can be trusted. Read these skills before the final pass, and record in the one that owns it whatever that pass taught you.

## Supported Neovim versions

This config targets the Neovim installed on this machine (currently 0.12). Upstream 'mini.nvim' supports the current stable, Nightly and the two previous stable releases; this config does not need to. A feature available only in a newer Neovim waits until that Neovim is installed here — it does not get wrapped in a `vim.fn.has()` branch.

## Non-goals

- Becoming a distribution: no auto-update mechanism, no plugin abstraction layer, no config of the config.
- A `lua/` module tree used to modularize startup behaviour through `plugin/` files: those only wire. Behavior lives in `lua/config/` modules, see the load-order rule above.
- Editing generated files by hand: `nvim-pack-lock.json`.
- Silencing warnings to make output look clean.
- **Filetype or language specific logic in the shared `plugin/` files, except one case.** Concretely, none of these belong in `plugin/`:
    - a branch on the current filetype (`if vim.bo.filetype == 'python' then ...`) to set options, mappings or autocommands — that is `after/ftplugin/python.lua`;
    - settings for one language server — that is `after/lsp/<server>.lua`, picked up by `vim.lsp.enable()`;
    - snippets for one language — that is `after/snippets/<lang>.json`.

  What *does* belong in `plugin/40_plugins.lua` is the language-agnostic machinery those files rely on: installing and configuring `nvim-treesitter`, `conform.nvim`, the servers passed to `vim.lsp.enable()`, all read from `lua/config/toolchain.lua`. The rule is about per-language *behaviour*, not about tools that happen to be aware of languages. The single admitted exception is a `BufReadCmd` for a URI scheme (`res://`, `jdt://`) that `gf` or an LSP response may create a buffer for: it must be registered before that buffer's `FileType` event, so it lives in a shared `plugin/` file, with the `res://` one in `plugin/40_plugins.lua` as the worked example.

## Checklist before finishing

- [ ] The change is in the right file, under the right separator and load step.
- [ ] Comments explain why, in the style of their neighbors, with `:h` references.
- [ ] `stylua --check` passes on the files touched (run from inside the repository; see the note about CRLF).
- [ ] Problems are reported through `vim.notify` / `vim.notify_once` / a health check — never `error()`.
- [ ] No generated file edited by hand.
- [ ] `CHANGELOG.md` updated if the change is worth being seen later, at the top of the file.
- [ ] Verification done in one pass, as the `nvim-config-testing` skill prescribes.
- [ ] One topic per commit; message has an allowed type, the Problem/Solution body, and `Signed-off-by`.
- [ ] Committed on `minimax-config` and pushed to `origin`.
