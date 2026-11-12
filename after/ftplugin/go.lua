-- ┌──────────────┐
-- │ Go behaviour │
-- └──────────────┘
--
-- This file adds folds, `:make`, and `:Run` to '$VIMRUNTIME/ftplugin/go.vim' (`:h ft-go-plugin`).

local ft = require('config.ft')

ft.ts_fold()

-- Tools print paths relative to the module, so `:make` runs from its root.
ft.build('go', { 'go.mod' })

-- `:Run` follows the contract in 'lua/config/run.lua'.
-- It uses `go run .` for a `main` package at the module root.
-- Otherwise, it uses the package under 'cmd/'.
-- A file outside a module runs itself. Arguments replace the default.
require('config.run').command(function(args)
  local root = vim.fs.root(0, 'go.mod')
  if #args > 0 then return vim.list_extend({ 'go', 'run' }, args), nil, root end
  if root == nil then return { 'go', 'run', vim.api.nvim_buf_get_name(0) } end
  if vim.fn.executable('go') ~= 1 then return nil, '`go` is not on PATH' end

  local listed = vim
    .system({ 'go', 'list', '-f', '{{.Name}}', '.' }, { cwd = root })
    :wait()
  if vim.trim(listed.stdout or '') == 'main' then
    return { 'go', 'run', '.' }, nil, root
  end

  local found = {}
  for name, kind in vim.fs.dir(vim.fs.joinpath(root, 'cmd')) do
    if kind == 'directory' then table.insert(found, './cmd/' .. name) end
  end
  if #found == 1 then return { 'go', 'run', found[1] }, nil, root end
  local reason = #found == 0
      and "no `main` package at the module root or under 'cmd/'"
    or 'several programs here, name one: ' .. table.concat(found, ', ')
  return nil, reason, root
end)
