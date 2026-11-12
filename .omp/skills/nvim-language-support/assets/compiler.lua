-- ┌─────────────────┐
-- │ Compiler plugin │
-- └─────────────────┘
--
-- Use this template for 'compiler/<tool>.lua'.
-- Copy this file. Rename the copy after the build tool, not the language.
-- A compiler plugin defines a command that several filetypes can select.
--
-- Add this file only if `vim.fn.getcompletion('', 'compiler')` shows no runtime compiler for this tool.
-- Neovim supplies more than 130 compiler plugins.
--
-- Activate it from 'after/ftplugin/<ft>.lua' with `vim.cmd('compiler <tool>')`.
-- Then, `:make <subcommand>` runs the tool and fills the quickfix list.
-- See `:h write-compiler-plugin`, `:h :compiler`, `:h errorformat`.
--
-- These two options describe a program, not a language.
-- A compiler plugin lets other filetypes reuse them and shows where the command comes from.
-- Use `:compiler make` to undo them (`:h compiler-make`).
-- Options inside a ftplugin apply to only one language and do not appear as a compiler plugin.
--
-- `:compiler` defines `CompilerSet` while it loads this file, then deletes the command.
-- `CompilerSet` sets local options, or global options under `:compiler!`.
-- It has no Lua API, so use `vim.cmd()`.

vim.g.current_compiler = 'mytool'

-- `:make` inserts its arguments at `$*`.
-- Thus, `:make test` and `:make check` use the same definition.
vim.cmd([[CompilerSet makeprg=mytool\ $*]])

-- Read `:h errorformat` before you write this line.
-- It uses scanf-like patterns and tests them in order.
-- An incorrect pattern can produce an empty quickfix list without an error.
--
-- `errorformat` also accepts Vim regular expressions for output such as colour escapes.
-- Test these three escape rules against a real output line to prevent silent failures:
-- - `%#` is the regex star (zero or more of the preceding item); a bare `*` matches a literal asterisk.
-- - `%[` matches a literal bracket; a bare `[` starts a character class.
-- - `%\%(` starts a non-capturing group.
--
-- A capturing `%\(` conflicts with the groups that `errorformat` creates for `%f` and similar fields.
-- Such groups return incorrect text, and too many cause `E872: Too many '('`.
-- `CompilerSet` uses `:set`, which removes one backslash from each pair.
-- Double each backslash that the pattern must receive.
-- Thus, '$VIMRUNTIME/compiler/tsc.vim' uses `\\,` for a comma inside its format.
--
-- Build repeated format parts once in Lua.
-- Name them.
-- Join them before calling `vim.cmd()` to keep escapes readable.
-- Use `vim.fn.setqflist({}, ' ', { lines = ..., efm = ... })` to test a format.
-- This needs no build, config, or `:set`.
--
-- Include these three features for a useful compiler plugin:
-- - Record each message's file, line, and column so `]q` jumps to the problem.
-- - Use `%-G` patterns to remove progress messages and keep only problems.
-- - Match failing test output so `:make test` lets the user move directly to failures.
vim.cmd([[CompilerSet errorformat=%f:%l:%c:\ %m]])
vim.cmd([[CompilerSet errorformat+=%-G%.%#Compiling%.%#]])
