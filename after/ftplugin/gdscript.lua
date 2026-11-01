-- ┌────────────────────┐
-- │ GDScript behaviour │
-- └────────────────────┘
--
-- Engine integration: `:make`, `:Run`, `:GodotDoc`, `:GodotReconnect`.

local ft = require('config.ft')

-- Read once: `:Run` may resolve after `:vertical new` made a nameless buffer current.
local root = vim.fs.root(0, { 'project.godot' })

if root ~= nil then
  -- NOTE: Godot prints file names relative to the project while Neovim resolves
  -- quickfix names against its own directory, hence the `make_root()` marker.
  ft.build('godot', { 'project.godot' })

  vim.bo.include = [[\v^\s*%(const\s+\w+\s*\=\s*)?%(pre)?load\(]]
end

-- NOTE: detached because a captured game draws on Neovim's own screen; it
-- therefore outlives `:qa`.
require('config.run').command(function(args)
  if root == nil then
    return nil, 'no project.godot above this file: there is no game to run'
  end
  return vim.list_extend({ 'godot', '--path', root }, args), nil, root
end, { detach = true })

-- TODO: running tests and exporting a build have no entry here; they belong in
-- the game's `mise.toml` tasks. First step: `godot --headless --export-release
-- <preset> <output>` after installing the pinned engine's export templates.

-- NOTE: `stable` is the newest engine, not the version pinned in 'mise.toml'.
vim.api.nvim_buf_create_user_command(0, 'GodotDoc', function()
  local word = vim.fn.expand('<cword>')
  vim.ui.open('https://docs.godotengine.org/en/stable/search.html?q=' .. word)
end, { desc = 'Godot documentation for the word under the cursor' })

vim.api.nvim_buf_create_user_command(
  0,
  'GodotReconnect',
  function() vim.cmd.edit() end,
  { desc = 'Reattach the language server after restarting Godot' }
)

if root ~= nil then
  local map = function(lhs, rhs, desc)
    vim.keymap.set('n', lhs, rhs, { buf = 0, desc = desc })
  end
  map('<Leader>og', '<Cmd>GodotDoc<CR>', 'Godot docs (word)')
  map('<Leader>oG', '<Cmd>GodotReconnect<CR>', 'Godot server reattach')
end

ft.undo('delcommand GodotDoc', 'delcommand GodotReconnect')
if root ~= nil then
  ft.undo(
    'setlocal include<',
    'silent! nunmap <buffer> <Leader>og',
    'silent! nunmap <buffer> <Leader>oG'
  )
end
