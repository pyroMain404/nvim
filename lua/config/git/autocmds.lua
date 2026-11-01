-- ┌──────────────────┐
-- │ Git autocommands │
-- └──────────────────┘
--
-- Registered at startup from 'plugin/50_features.lua'. Nothing of the other
-- modules loads until a callback needs it.

local M = {}

M.setup = function()
  Config.new_autocmd(
    'FileType',
    { 'git', 'diff' },
    function() require('config.git.patch').setup_buf() end,
    'Navigable Git output'
  )

  -- Blame can only be on once its module was loaded by the toggle.
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
