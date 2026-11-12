-- ┌──────────────────────┐
-- │ C and C++ via clangd │
-- └──────────────────────┘
--
-- Install with `winget install LLVM.LLVM`. This file replaces only the complete `cmd` list.
-- A function here would remove the inherited `:LspClangdSwitchSourceHeader`.
-- 'compile_commands.json' or '.clangd' supplies `-std=`.
return {
  cmd = {
    'clangd',
    -- Index unopened files so references and rename include them.
    '--background-index',
    -- The project's '.clang-tidy' supplies the checks.
    '--clang-tidy',
    '--header-insertion=never',
  },
}
