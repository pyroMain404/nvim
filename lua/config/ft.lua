-- ┌───────────────────┐
-- │ ftplugin helpers  │
-- └───────────────────┘
--
-- Shared by 'after/ftplugin/*.lua' (`:h b:undo_ftplugin`); required by name.

local M = {}

-- Append commands to `b:undo_ftplugin`, after what the runtime ftplugin set.
function M.undo(...)
  vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
    .. '\n'
    .. table.concat({ ... }, ' | ')
end

-- NOTE: 'foldmethod' and 'foldexpr' belong to the window. `vim.wo.x` writes like
-- `:set` and moves the global value too; `vim.wo[0][0].x` writes like `:setlocal`
-- and keeps the value in this buffer and window (`:h vim.wo`).
function M.ts_fold()
  vim.wo[0][0].foldmethod = 'expr'
  vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  M.undo('setlocal foldmethod< foldexpr<')
end

-- `:compiler` has no Lua API, so `vim.cmd()` is the only way. `markers` makes
-- `:make` run from the project root (`make_root()` of 'lua/config/run.lua').
function M.build(compiler, markers)
  vim.cmd('compiler ' .. compiler)
  if markers ~= nil then require('config.run').make_root(markers) end
  M.undo('setlocal makeprg< errorformat<', 'unlet! b:current_compiler')
end

-- Maven for the buffer whose build file is `pom`: `:make` and `:Run`.
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
