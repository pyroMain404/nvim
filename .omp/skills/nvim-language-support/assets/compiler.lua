-- ┌─────────────────┐
-- │ Compiler plugin │
-- └─────────────────┘
--
-- Skeleton for 'compiler/<tool>.lua'. Copy and rename after the build tool, not
-- after the language: a compiler plugin is about a command, and several filetypes
-- can select the same one.
--
-- Needed only when `vim.fn.getcompletion('', 'compiler')` shows that the runtime
-- has none for this tool — Neovim ships over 130 of them.
--
-- Activate it from 'after/ftplugin/<ft>.lua' with `vim.cmd('compiler <tool>')`,
-- after which `:make <subcommand>` runs the tool and fills the quickfix list.
-- See `:h write-compiler-plugin`, `:h :compiler`, `:h errorformat`.
--
-- Why here and not directly in the ftplugin: these two options describe a program,
-- so in this file they can be reused by other filetypes, undone with
-- `:compiler make` (`:h compiler-make`), and found by whoever asks where the
-- command came from. Set inside a ftplugin they are tied to one language and
-- invisible.
--
-- `CompilerSet` is a command that `:compiler` defines while sourcing this file and
-- deletes afterwards; it applies the options locally, or globally under `:compiler!`.
-- It has no Lua API, so `vim.cmd()` here is the only way, not a shortcut.

vim.g.current_compiler = 'mytool'

-- `$*` is where `:make` inserts its arguments, so that `:make test` and
-- `:make check` both work through a single definition.
vim.cmd([[CompilerSet makeprg=mytool\ $*]])

-- Read `:h errorformat` before writing this line: it is scanf-like, matched in
-- order, and a wrong pattern silently yields an empty quickfix list.
--
-- It also accepts a Vim regular expression, which is what makes it able to cope
-- with output nobody designed for it - colour escapes above all. Three escapes
-- decide whether such a pattern matches, and getting one wrong produces the
-- same silence as no pattern at all, so check them against a real line first:
-- - `%#` is the regex star; a bare `*` is a literal asterisk, and `%[` a
--   literal bracket (a bare `[` opens a character class);
-- - `%\%(` opens a NON capturing group. A capturing `%\(` competes with the
--   groups `errorformat` builds for `%f` and friends and hands back the wrong
--   text - and enough of them raise `E872: Too many '('`;
-- - `CompilerSet` is `:set`, which eats one backslash of every pair, so a
--   backslash meant for the pattern is written doubled - the reason
--   '$VIMRUNTIME/compiler/tsc.vim' writes `\\,` for a comma inside its format.
--
-- Writing the format in Lua and passing it to `vim.cmd()` is what keeps it
-- readable once these stack: build the repeated part once, name it, and
-- concatenate. `vim.fn.setqflist({}, ' ', { lines = ..., efm = ... })` is the
-- cheapest way to try one - it needs no build, no config, and no `:set`.
--
-- Three things are worth the effort, and they are what separates a useful compiler
-- plugin from one that only compiles:
-- - the file, line and column of each message, so that `]q` jumps to the spot;
-- - `%-G` patterns discarding progress noise, so the list holds only problems;
-- - the shape of a *failing test*, which turns `:make test` into navigation of the
--   failures instead of a wall of output.
vim.cmd([[CompilerSet errorformat=%f:%l:%c:\ %m]])
vim.cmd([[CompilerSet errorformat+=%-G%.%#Compiling%.%#]])
