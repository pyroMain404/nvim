-- ┌──────────────┐
-- │ Git workflow │
-- └──────────────┘
-- Mappings use this 'mini.diff' and 'mini.git' module. 'autocmds.lua' defines autocommands.
-- `buf_id` selects the repository (`nil`) or a buffer (`0`: current, otherwise its number).
-- `rev` accepts any revision that Git knows.

local core = require('config.git.core')
local diffref = require('config.git.diffref')
local blame = require('config.git.blame')
local log = require('config.git.log')

local M = {}

M.run = core.run
M.fail = core.fail
M.pick_commit = core.pick_commit
M.require_root = core.require_root

M.set_diff_ref = diffref.set
M.toggle_diff_ref = diffref.toggle
M.diff_ref_label = diffref.label
M.toggle_overlay = diffref.toggle_overlay
M.get_diff_ref = diffref.get

M.toggle_blame = blame.toggle

M.log = log.log
M.diff_unstaged = log.diff_unstaged
M.diff_staged = log.diff_staged
M.diff_commit = log.diff_commit
M.diff_commit_only = log.diff_commit_only

M.lazygit = function() require('config.git.lazygit').open() end

return M
