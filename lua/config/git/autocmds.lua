-- ┌──────────────────┐
-- │ Git autocommands │
-- └──────────────────┘
-- 'plugin/50_features.lua' registers these autocommands at startup.
-- Callbacks load the other modules only when needed.

local M = {}

M.setup = function()
  Config.new_autocmd(
    'FileType',
    { 'git', 'diff' },
    function() require('config.git.patch').setup_buf() end,
    'Navigable Git output'
  )

  -- Blame can be active only after the toggle loads its module.
  local blame_events = { 'CursorMoved', 'CursorMovedI', 'BufEnter' }
  Config.new_autocmd(blame_events, nil, function()
    local blame = package.loaded['config.git.blame']
    if blame ~= nil then blame.track() end
  end, 'Blame current line')

  Config.new_autocmd(
    'User',
    'MiniGitCommandSplit',
    function(au_data) require('config.git.blame').align(au_data) end,
    'Align Git blame'
  )
end

return M
