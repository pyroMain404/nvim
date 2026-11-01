-- ┌───────────────────┐
-- │ ftplugin helpers  │
-- └───────────────────┘
--
-- Shared by 'after/ftplugin/*.lua' (`:h b:undo_ftplugin`); required by name.

local M = {}

function M.undo(...)
  vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
    .. '\n'
    .. table.concat({ ... }, ' | ')
end

-- NOTE: fold options belong to the window: `vim.wo.x` also moves the global value,
-- `vim.wo[0][0].x` writes like `:setlocal` (`:h vim.wo`).
function M.ts_fold()
  vim.wo[0][0].foldmethod = 'expr'
  vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  M.undo('setlocal foldmethod< foldexpr<')
end

-- `markers` makes `:make` run from the project root (`make_root()` in 'run.lua').
function M.build(compiler, markers)
  vim.cmd('compiler ' .. compiler)
  if markers ~= nil then require('config.run').make_root(markers) end
  M.undo('setlocal makeprg< errorformat<', 'unlet! b:current_compiler')
end

function M.maven(pom)
  local run = require('config.run')
  M.build('maven', { 'pom.xml' })
  run.command(
    function(args)
      return run.java_builds['pom.xml'].run(args, pom), nil, vim.fs.dirname(pom)
    end
  )
end

return M
