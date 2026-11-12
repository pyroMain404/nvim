-- ┌────────────────────┐
-- │ GDScript behaviour │
-- └────────────────────┘
--
-- This file adds engine integration: `:make`, `:Run`, `:GodotDoc`, and `:GodotReconnect`.

local ft = require('config.ft')

-- Read the root once. `:Run` can resolve after `:vertical new` makes an unnamed buffer current.
local root = vim.fs.root(0, { 'project.godot' })

if root ~= nil then
  -- NOTE: Godot prints file names relative to the project.
  -- Neovim resolves quickfix names against its own directory, so use the `make_root()` marker.
  ft.build('godot', { 'project.godot' })

  vim.bo.include = [[\v^\s*%(const\s+\w+\s*\=\s*)?%(pre)?load\(]]
end

-- NOTE: Detach the game because a captured game draws on Neovim's screen.
-- The detached game continues after `:qa`.
require('config.run').command(function(args)
  if root == nil then
    return nil, 'no project.godot above this file: there is no game to run'
  end
  return vim.list_extend({ 'godot', '--path', root }, args), nil, root
end, { detach = true })

-- TODO: Add test and export tasks to the game's `mise.toml`; this file has no entries for them.
-- First, install export templates for the pinned engine.
-- Then, use `godot --headless --export-release <preset> <output>`.

-- NOTE: `stable` is the newest engine, not the version that 'mise.toml' pins.
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
