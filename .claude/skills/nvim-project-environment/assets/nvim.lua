-- ┌──────────────────────────┐
-- │ <project> under Neovim   │
-- └──────────────────────────┘
--
-- Skeleton of a project local '.nvim.lua'. Copy it into the project, keep the
-- sections that apply, delete the rest - what is left has to read as a file
-- written for this project, not as a filled in template.
--
-- Sourced because `:h 'exrc'` is on in the config and this file has been
-- trusted (`:h :trust`). Keep it out of the repository with
-- '.git/info/exclude', so the checkout the rest of the team reads with other
-- editors does not see it.
--
-- The header is the part that matters: say **why this project is different**,
-- because that is the question asked a year from now. Everything else is
-- explained by the config itself.

-- Language server ============================================================

-- Environment a server reads, which the config cannot know. It is set here
-- because a `.nvim.lua` is read before any language server starts, so what it
-- exports reaches the `cmd` that launches one.
--
-- Anything outside the repository is checked before it is used and its absence
-- is reported: a server that starts without it keeps answering, and answers
-- wrong. Never `error()` here - it would abort the rest of the file.
local agent = vim.fs.normalize('~/.local/share/java/lombok-1.18.36.jar')
if vim.uv.fs_stat(agent) ~= nil then
  vim.env.JDTLS_JVM_ARGS = '-javaagent:' .. agent
else
  vim.notify_once('agent is missing: ' .. agent, vim.log.levels.WARN)
end

-- Build ======================================================================

-- An option the config's own ftplugin also sets has to be written from a
-- `FileType` autocommand, not assigned: 'after/ftplugin/<ft>.lua' runs after
-- this file, and a plain assignment is silently overwritten.
vim.api.nvim_create_autocmd('FileType', {
  pattern = '<filetype>',
  desc = '<what makes this project need it>',
  callback = function() vim.bo.makeprg = '<command>' end,
})

-- Running ===================================================================

-- `:Run` (the contract of 'lua/config/run.lua') asks here first, and unlike an
-- option this needs no autocommand: the resolver is consulted when the command
-- is invoked, which is always after this file has been read. A list is the whole
-- command, and the arguments of the call are appended to it.
vim.g.run_command = { '<program>', '<argument>' }

-- Or a function - one of the two, not both - when the command depends on the
-- buffer - a monorepo whose
-- parts are started differently - or when some of them are not meant to be
-- started at all. It answers like any resolver: the command, or `nil` and the
-- reason, which is shown rather than swallowed.
-- vim.g.run_command = function(args)
--   if vim.bo.filetype ~= '<filetype>' then
--     return nil, '<what this project actually runs>'
--   end
--   return vim.list_extend({ '<program>', '<argument>' }, args)
-- end

-- Editing this file voids its trust, and an untrusted file is not sourced at
-- all - with no question asked in headless. Authorise it again after every
-- edit, and check that the hash matches:
--
--   nvim --headless -u NONE .nvim.lua -c 'trust' -c 'qa!'
--   sha256sum .nvim.lua; cat "$env:LOCALAPPDATA\nvim-data\trust"
