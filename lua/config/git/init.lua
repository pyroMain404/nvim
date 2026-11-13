-- ┌──────────────┐
-- │ Git workflow │
-- └──────────────┘
-- This module builds on 'mini.diff' and 'mini.git'. Mappings call the functions below.
-- 'autocmds.lua' defines the autocommands.
-- `buf_id` is `nil` for the whole repository, `0` for the current buffer, or a buffer number.
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
