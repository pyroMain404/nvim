-- ┌────────────────┐
-- │ Java behaviour │
-- └────────────────┘
--
-- Indentation, `:make` and `:Run` (`:h ft-java-plugin`).

vim.bo.shiftwidth = 4
vim.bo.softtabstop = 4

local ft = require('config.ft')

ft.ts_fold()

-- NOTE: a Surefire failure entry carries the first stack frame, inside JUnit;
-- the test frame is a few entries below (Neovim 0.12.4).
--
-- TODO: Gradle falls through to `javac` and leaves the quickfix list empty like
-- a green build. Needs 'compiler/gradle.lua'; first step: make `gradlew.bat
-- compileJava` fail on purpose and read the raw output (probably `--console=plain`).
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
