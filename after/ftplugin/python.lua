-- ┌──────────────────┐
-- │ Python behaviour │
-- └──────────────────┘
--
-- This file contains behavior specific to Python buffers, added on top of what
-- '$VIMRUNTIME/ftplugin/python.vim' already does: PEP 8 indent, `commentstring`,
-- `gf` on an `import` through `include`, `includeexpr` and `suffixesadd`,
-- `keywordprg=python3 -m pydoc`, and `:compiler pytest` for 'test_*.py' and
-- '*_test.py' when `pytest` is on PATH. None of that is repeated here.
-- `:verbose setlocal shiftwidth? includeexpr?` says who set what.
--
-- Running the script, under the contract of 'lua/config/run.lua'. A script
-- belongs to no project, so file and project coincide. The interpreter is
-- resolved at every call, so a venv created mid-session is picked up at once
-- (unlike the server, which fixes it at start). `:Run arg1 arg2` passes
-- arguments to the script; a project override (`vim.b.run_command`) still wins.
-- The working directory defaults to the file's directory, which is why the
-- third return value is omitted.
require('config.run').command(function(args)
  local file = vim.api.nvim_buf_get_name(0)
  local python = require('config.python').interpreter(file)
  if python == nil then
    return nil,
      "no Python interpreter: no '.venv' or 'venv' above this file and no `python` on PATH"
  end
  return vim.list_extend({ python, file }, args)
end)
