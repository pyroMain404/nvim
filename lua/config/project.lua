-- ┌───────────────────┐
-- │ Project contracts │
-- └───────────────────┘
--
-- A project declares settings in '.nvim.lua' (`:h 'exrc'`, trusted with `:trust`).
--
-- A project calls `require('config.project').set(name, spec)` to set these contracts.
--
--   `start` sets the start screen. See 'lua/config/starter.lua'.
--
--     set('start', {
--       strategy = 'merge', -- or 'substitute' (default)
--       header = 'optional string; \n allowed',
--       items = {
--         { section = 'Build', name = 'Run', action = 'Run' }, -- an Ex command or a Lua function
--         { name = 'Readme', action = function() vim.cmd.edit('README.md') end }, -- section defaults to 'Project'
--       },
--     })
--
--   `run` sets the command for `:Run`. See 'lua/config/run.lua'.
--   Use a list to which `:Run` adds its arguments, or `function(args)` that returns a command.
--   Return `nil, nil` to use the language default.
--
--     set('run', { 'npm', 'run', 'dev' })
--
--   `obsidian` sets obsidian.nvim options for the vault in the directory of this '.nvim.lua'.
--   See 'lua/config/obsidian.lua'. The table takes the workspace `overrides` of the plugin, so
--   any of its options is valid ('docs/' of the plugin). Functions are allowed.
--
--     set('obsidian', {
--       notes_subdir = 'notes',
--       new_notes_location = 'notes_subdir',
--       daily_notes = { folder = 'daily', template = 'daily.md' },
--       attachments = { folder = 'attachments' },
--       templates = {
--         folder = 'templates',
--         date_format = 'YYYY-MM-DD',
--         substitutions = { vault = function() return 'journal' end },
--       },
--     })
--
-- NOTE: 'exrc' sources files from every parent directory, nearest first; the first valid `set()`
-- wins.
-- NOTE: The config reads `start` at startup, `run` when `:Run` starts, and `obsidian` on the
-- first visit of the vault. Restart Neovim to apply a change.
-- NOTE: 'exrc' runs only the files above the startup directory. On the first visit of another
-- vault, `source()` runs the '.nvim.lua' of that vault.

local M = {}

-- Return `value, problems` without side effects. `value` is `nil` if the contract is unusable.
local function parse_start(spec)
  if
    type(spec) ~= 'table'
    or type(spec.items) ~= 'table'
    or not vim.islist(spec.items)
  then
    return nil, { '"start" needs an "items" list' }
  end
  local problems = {}
  local strategy = spec.strategy
  if strategy == nil then
    strategy = 'substitute'
  elseif strategy ~= 'merge' and strategy ~= 'substitute' then
    return nil, { '"start.strategy" must be "merge" or "substitute"' }
  end
  local header = spec.header
  if header ~= nil and type(header) ~= 'string' then
    table.insert(problems, '"start.header" must be a string')
    header = nil
  end
  local items = {}
  for i, item in ipairs(spec.items) do
    -- An empty string would render as an inactive placeholder in 'mini.starter'.
    local valid = type(item) == 'table'
      and type(item.name) == 'string'
      and (
        type(item.action) == 'function'
        or (type(item.action) == 'string' and item.action ~= '')
      )
    if valid then
      table.insert(items, {
        name = item.name,
        section = type(item.section) == 'string' and item.section or 'Project',
        action = item.action,
      })
    else
      table.insert(
        problems,
        ('start: item %d needs a "name" and an "action" (Ex command or function)'):format(
          i
        )
      )
    end
  end
  return { strategy = strategy, header = header, items = items }, problems
end

-- Accept a non-empty list of strings or a function for `:Run` ('lua/config/run.lua').
local function parse_run(spec)
  if type(spec) == 'function' then return spec, {} end
  if type(spec) == 'table' and vim.islist(spec) and #spec > 0 then
    for _, arg in ipairs(spec) do
      if type(arg) ~= 'string' then
        return nil, { '"run" list must hold only strings' }
      end
    end
    return spec, {}
  end
  return nil, { '"run" needs a non-empty list of strings or a function' }
end

-- Accept a table of obsidian.nvim options. obsidian.nvim validates the content when it loads.
local function parse_obsidian(spec)
  if type(spec) == 'table' and not vim.islist(spec) then return spec, {} end
  return nil, { '"obsidian" needs a table of obsidian.nvim options' }
end

-- This closed set maps `name -> parse(spec)`. Each new contract needs one function and one entry.
local contracts = { start = parse_start, run = parse_run, obsidian = parse_obsidian }

-- `set()` fills the `name -> root -> value` map. `first[name]` is the root of the first `set()`.
local declared, first = {}, {}

-- Each '.nvim.lua' that `source()` ran or skipped.
local sourced = {}

-- 'exrc' runs before 'mini.notify' takes over `vim.notify`. Wait until startup ends so the warning
-- appears.
local function warn(msg)
  vim.schedule(function() vim.notify(msg, vim.log.levels.WARN) end)
end

--- Declare contract `name` for the project whose '.nvim.lua' calls this function.
-- NOTE: `set()` uses the directory of its caller's file.
-- A wrapper helper in another file would declare that file's directory.
function M.set(name, spec)
  local source = debug.getinfo(2, 'S').source
  local file = source:sub(1, 1) == '@' and vim.fs.normalize(source:sub(2)) or nil
  local where = file or 'project'
  if contracts[name] == nil then
    warn(('%s: unknown contract "%s"'):format(where, tostring(name)))
    return
  end
  local value, problems = contracts[name](spec)
  for _, problem in ipairs(problems) do
    warn(('%s: %s'):format(where, problem))
  end
  if not value then return end
  local root = file and vim.fs.dirname(file) or vim.fn.getcwd()
  declared[name] = declared[name] or {}
  if declared[name][root] ~= nil then
    warn(
      ('%s: "%s" is already declared in this file, the first one wins'):format(
        where,
        name
      )
    )
    return
  end
  declared[name][root] = value
  first[name] = first[name] or root
end

--- Run '<root>/.nvim.lua' once if 'exrc' did not run it at startup. It asks for `:trust`.
function M.source(root)
  local file = root .. '/.nvim.lua'
  if sourced[file] then return end
  sourced[file] = true
  if vim.fs.relpath(root, Config.exrc_dir) or vim.fn.filereadable(file) == 0 then
    return
  end
  local code = vim.secure.read(file)
  if not code then return end
  local chunk, err = loadstring(code, '@' .. file)
  local ok = chunk ~= nil
  if ok then
    ok, err = pcall(chunk)
  end
  if not ok then vim.notify(file .. ': ' .. tostring(err), vim.log.levels.WARN) end
end

--- Return the value for contract `name` and its declaring directory, or `nil`.
--- Without `root`, return the first `set()`, which is the nearest '.nvim.lua'.
function M.contract(name, root)
  if contracts[name] == nil then
    vim.notify_once('Unknown project contract: ' .. name, vim.log.levels.WARN)
    return nil
  end
  root = root or first[name]
  local value = root and declared[name] and declared[name][root]
  if value ~= nil then return value, root end
end

return M
