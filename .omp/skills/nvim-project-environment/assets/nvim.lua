-- ┌──────────────────────────┐
-- │ <project> under Neovim   │
-- └──────────────────────────┘
--
-- Copy this project-local '.nvim.lua' template into the project.
-- Keep only the applicable sections.
-- Make the result specific to the project, not a completed template.
--
-- The config enables `:h 'exrc'`, which loads this file after trust approval (`:h :trust`).
-- Exclude it through '.git/info/exclude' to keep it out of the repository
-- that teammates use with other editors.
--
-- Explain why this project differs in the header, so future readers know the reason.
-- The config itself explains the other settings.

-- Language server ============================================================

-- Set server environment values here when the config cannot know them.
-- Neovim reads `.nvim.lua` before language servers start, so exported values reach the server's `cmd`.
--
-- Check resources outside the repository before use and report missing resources.
-- Without them, a server can still run but give incorrect results.
-- Do not use `error()` here because it stops the rest of this file.
local agent = vim.fs.normalize('~/.local/share/java/lombok-1.18.36.jar')
if vim.uv.fs_stat(agent) ~= nil then
  vim.env.JDTLS_JVM_ARGS = '-javaagent:' .. agent
else
  vim.notify_once('agent is missing: ' .. agent, vim.log.levels.WARN)
end

-- Build ======================================================================

-- Use a `FileType` autocommand for options that the config's ftplugin also sets.
-- 'after/ftplugin/<ft>.lua' runs after this file and silently replaces plain assignments.
vim.api.nvim_create_autocmd('FileType', {
  pattern = '<filetype>',
  desc = '<what makes this project need it>',
  callback = function() vim.bo.makeprg = '<command>' end,
})

-- Running ===================================================================

-- `:Run`, from 'lua/config/run.lua', checks this resolver first.
-- It needs no autocommand because `:Run` calls it after Neovim reads this file.
-- A list defines the complete command, and `:Run` adds the call arguments to it.
require('config.project').set('run', { '<program>', '<argument>' })

-- Use a list or a function, not both.
-- Instead of a list, use a function when the command depends on the buffer.
-- For example, monorepo parts can need different commands, or some parts must not run.
-- Return the command, or `nil, nil` to use the language resolver.
-- require('config.project').set('run', function(args)
--   if vim.bo.filetype ~= '<filetype>' then return nil, nil end
--   return vim.list_extend({ '<program>', '<argument>' }, args)
-- end)

-- Each edit removes trust, and Neovim does not load an untrusted file.
-- Headless Neovim gives no prompt.
-- Approve trust after each edit, then check that the hash matches:
--
--   nvim --headless -u NONE .nvim.lua -c 'trust' -c 'qa!'
--   sha256sum .nvim.lua; cat "$env:LOCALAPPDATA\nvim-data\trust"
