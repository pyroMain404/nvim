-- ┌────────────────┐
-- │ Rust behaviour │
-- └────────────────┘
--
-- This file contains behavior specific to Rust buffers, added on top of what
-- '$VIMRUNTIME/ftplugin/rust.vim' already does: the official style
-- (`shiftwidth=4`, `textwidth=100`), `commentstring`, `gf` on a `use` through
-- `includeexpr` and `suffixesadd`, and `:compiler cargo` as soon as a
-- `Cargo.toml` is found while walking up. None of that is repeated here.
-- `:verbose setlocal makeprg? commentstring?` says who set what.
--
-- 'mini.pairs' auto-closes a single quote unless the character before it is a
-- letter or a backslash. That rule fits a language where `'` opens a string and
-- misfires in Rust, where the same character opens a lifetime: typing `&'`
-- gave `&''`, and the extra quote had to be removed by hand in every `&'a str`,
-- `<'a, T>` and `fn f<'a>()`.
--
-- `MiniPairs.unmap_buf()` is not the way to undo it. It reverts a mapping made
-- with `MiniPairs.map_buf()`, while this one comes from `setup()` and is
-- global; the module's own help says that such a mapping is undone for one
-- buffer by mapping the key to itself (`:h MiniPairs.unmap_buf()`), which is
-- what this line does. Double quotes keep pairing, and a character literal is
-- typed in full.
vim.keymap.set('i', "'", "'", { buf = 0, desc = 'Insert a plain quote' })

-- Running the project, under the contract of 'lua/config/run.lua'. No reading of
-- 'Cargo.toml' is needed here because cargo reads it: `default-run`, a single
-- `[[bin]]`, or nothing - in which case it refuses and lists the binaries it
-- could not choose between (measured on a six member workspace), which is the
-- loud failure the contract asks for. `:Run --bin <name>` then picks one, and
-- `:Run --release` or `:Run -- <args>` reach the profile and the program.
--
-- NOTE: the runtime already defines `:Crun` for this ('$VIMRUNTIME/autoload/
-- cargo.vim', which in Neovim opens `noautocmd new | terminal cargo run`), and
-- the duplication is deliberate: what is worth remembering is one name that
-- works in every language of this config, not one name per build tool. `:Crun`
-- keeps working for whoever types it.
require('config.run').command(
  function(args) return vim.list_extend({ 'cargo', 'run' }, args) end
)

-- Undo what this file sets when the filetype changes away from `rust`
-- (`:h b:undo_ftplugin`). `:Run` undoes itself, registered inside
-- 'lua/config/run.lua''s `M.command()`.
vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n'
  .. "silent! iunmap <buffer> '"
