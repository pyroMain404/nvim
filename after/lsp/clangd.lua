-- ┌──────────────────────┐
-- │ C and C++ via clangd │
-- └──────────────────────┘
--
-- Install: `winget install LLVM.LLVM`. Only `cmd` (a list, replaced whole):
-- a function here would drop the inherited `:LspClangdSwitchSourceHeader`.
-- No `-std=`: it comes from 'compile_commands.json' or '.clangd'.
return {
  cmd = {
    'clangd',
    -- Index unopened files so references and rename see them.
    '--background-index',
    -- Checks come from the project's '.clang-tidy'.
    '--clang-tidy',
    '--header-insertion=never',
  },
}
