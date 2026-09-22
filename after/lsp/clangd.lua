-- ┌──────────────────────┐
-- │ C and C++ via clangd │
-- └──────────────────────┘
--
-- This file contains configuration of the C and C++ language server.
-- Source: https://clangd.llvm.org
-- Install: `winget install LLVM.LLVM`. Installing the whole LLVM release is
-- what keeps `clangd`, `clang++`, `clang-format` and `clang-tidy` at the same
-- version, the way `rustup` does for Rust: for a language whose server travels
-- with the compiler, that alignment is what keeps them agreeing.
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
--
-- Only `cmd` is set here, and that is the whole point of the file.
-- 'nvim-lspconfig' defines `on_attach`, `on_init` and `get_language_id` as
-- functions, and every 'lsp/clangd.lua' on 'runtimepath' is merged with
-- `vim.tbl_deep_extend('force')`, which merges tables but REPLACES functions.
-- The inherited `on_attach` is what creates `:LspClangdSwitchSourceHeader` -
-- the header/source jump, through the `textDocument/switchSourceHeader`
-- extension of clangd - and `:LspClangdShowSymbolInfo`. Writing one here
-- removes both, with no error and no message. Run `:=vim.lsp.config['clangd']`
-- to read what is inherited; buffer-local behavior belongs in an
-- `:h LspAttach` autocommand.
--
-- `cmd` is safe to write because the default is a table, and a list is replaced
-- whole rather than merged by index.
--
-- What is NOT here, on purpose: `root_markers`. The inherited list already has
-- 'compile_commands.json' ahead of '.git', which is the right order - the
-- compilation database is what clangd actually needs, and the repository root
-- is only the fallback.
--
-- And no `-std=` anywhere, which is the other deliberate absence. WHICH C++
-- STANDARD A BUFFER IS WRITTEN IN IS A PROPERTY OF THE PROJECT, and a shared
-- config that picked one would be wrong for every project that picked another:
-- the flag reaches the server per translation unit, out of the compilation
-- database, so a C++11 project and a C++23 project opened in the same session
-- each get their own. `-std=` in 'build/compile_commands.json' is what says so
-- - `:checkhealth config` prints the one in effect - and it is generated from
-- the `CMAKE_CXX_STANDARD` of the project, which is also what `:make` compiles
-- with. One statement, two consumers.
--
-- The two levers, for the case that stays outside a database - a loose file, or
-- a project that was never configured - where clangd assumes the newest
-- standard its clang knows, and so ACCEPTS code the build will reject:
-- - the project's own '.clangd' file (`CompileFlags: Add: [-std=c++17]`),
--   which clangd reads by itself and which every editor honors;
-- - `vim.lsp.config('clangd', { init_options = { fallbackFlags = { … } } })`
--   in the project's '.nvim.lua' (`:h 'exrc'`, skill
--   `nvim-project-environment`), when it is Neovim's business alone.
return {
  cmd = {
    'clangd',
    -- Index the whole project in the background, so that references and rename
    -- answer about files that were never opened. Without it clangd only knows
    -- the translation units of the open buffers.
    '--background-index',
    -- Run clang-tidy as part of the diagnostics. This is what makes a separate
    -- linter unnecessary for C++, the same role `clippy` plays for Rust in
    -- 'after/lsp/rust_analyzer.lua'. Which checks run belongs to the project's
    -- '.clang-tidy', not here.
    '--clang-tidy',
    -- Accepting a completion does not edit the top of the file. Inserting an
    -- include is a deliberate act, and a silent one lands in the diff.
    '--header-insertion=never',
  },
}
