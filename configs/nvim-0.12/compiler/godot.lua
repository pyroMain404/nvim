-- ┌──────────────────────────────┐
-- │ Godot parse check → quickfix │
-- └──────────────────────────────┘
--
-- `:compiler godot` teaches `:make` to ask the engine whether the script in the
-- current buffer parses, and puts what it says in the quickfix list so that `]q`
-- and `[q` of 'mini.bracketed' walk the errors. Selected for a buffer in
-- 'after/ftplugin/gdscript.lua'. See `:h write-compiler-plugin`, `:h :compiler`,
-- `:h errorformat`.
--
-- NOTE: this answers a smaller question than every other compiler plugin here,
-- and the difference is worth knowing before trusting an empty list.
-- - It checks ONE FILE, the one in the buffer. `--check-only` without
--   `--script` answers `Couldn't detect whether to run the editor, the project
--   manager or a specific project`: "does this project build" is not a question
--   the engine answers from the command line, so there is no `cargo check` or
--   `ngc --noEmit` equivalent to drive here.
-- - It is a PARSE check, not a type check. A call to a method that does not
--   exist, on the right type, produces no output and exit code 0 (measured).
--   Semantic errors come from the language server alone, which means they come
--   only while the Godot editor is open on the project.
--
-- The other candidate was `godot --headless --path <root> --editor --quit`,
-- which does look at the whole project. It is not used: it names no file, and a
-- project that does not compile still exits 0 - so the one case `:make` exists
-- to catch is the one it cannot report. It also wraps every line it prints in
-- unconditional ANSI colour, the trap 'compiler/ngc.lua' already pays for.

vim.g.current_compiler = 'godot'

-- `--path .` and not the absolute project root: 'after/ftplugin/gdscript.lua'
-- runs `:make` from that root, because the file names below come out relative
-- to it and Neovim resolves quickfix names against ITS OWN directory. Writing
-- the root in here would fix the engine's half and leave the editor's half
-- broken, which reads as a quickfix list full of files that do not exist.
--
-- `%:p:S` is the absolute path of the buffer, escaped for the shell (`:h
-- filename-modifiers`): the engine accepts a Windows absolute path, a path
-- relative to the root and a `res://` one alike, and normalises all three to
-- `res://` on output. `$*` sits before `--script` so that `:make` arguments
-- reach the engine rather than the script.
vim.cmd(
  [[CompilerSet makeprg=godot\ --headless\ --path\ .\ --check-only\ $*\ --script\ %:p:S]]
)

-- One parse error, as the engine writes it:
--
--   SCRIPT ERROR: Parse Error: Unterminated string.
--      at: GDScript::reload (res://scripts/broken.gd:4)
--
-- so the file and the line are on the line AFTER the message: a multi-line
-- entry, opened with `%E` and closed with `%Z`. NOTE: the two spaces of
-- `SCRIPT ERROR: ` are written `\ ` because `CompilerSet` is a `:set`, which
-- eats an unescaped space and would silently truncate the format there - and a
-- truncated format leaves the quickfix list empty, which reads exactly like a
-- file that parses (`:h option-backslash`).
--
-- `res://` is matched literally, so `%f` receives the path relative to the
-- project root. There is no `%c`: the engine reports a file and a line and
-- nothing else, so the cursor lands in column 1.
vim.cmd([[CompilerSet errorformat=%ESCRIPT\ ERROR:\ %m]])
vim.cmd([[CompilerSet errorformat+=%Z%.%#(res://%f:%l)]])

-- Everything else is the version banner and the two `ERROR: Failed to load
-- script` lines, which repeat the same failure while pointing at a source file
-- of the engine itself. This item is reached only after `%Z` has closed the
-- entry, so it does not fall foul of `%-G` inside a pending multi-line message.
vim.cmd([[CompilerSet errorformat+=%-G%.%#]])
