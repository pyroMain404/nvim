-- ┌────────────────┐
-- │ Java behaviour │
-- └────────────────┘
--
-- This file sets indentation and supports `:make` and `:Run` (`:h ft-java-plugin`).

vim.bo.shiftwidth = 4
vim.bo.softtabstop = 4

local ft = require('config.ft')

ft.ts_fold()

-- NOTE: A Surefire failure entry contains the first stack frame, inside JUnit (Neovim 0.12.4).
-- The test frame is a few entries below.
--
-- TODO: Add 'compiler/gradle.lua'; Gradle uses `javac` and leaves an empty quickfix list that
-- suggests a successful build.
-- First, make `gradlew.bat compileJava` fail deliberately.
-- Then, read the raw output, probably with `--console=plain`.
local found = vim.fs.find('pom.xml', {
  upward = true,
  path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
})[1]

if found then
  ft.maven(found)
else
  ft.build('javac')
  require('config.run').command(
    function(args)
      return vim.list_extend({ 'java', vim.api.nvim_buf_get_name(0) }, args)
    end
  )
end

ft.undo('setlocal shiftwidth< softtabstop<')
