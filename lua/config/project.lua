-- ┌───────────────────┐
-- │ Project contracts │
-- └───────────────────┘
--
-- What a project may declare for this config, from its '.nvim.lua' (`:h 'exrc'`, trusted with `:trust`).
--
-- A project calls `require('config.project').set(name, spec)`. Contracts:
--
--   `start`  the start screen, see 'lua/config/starter.lua':
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
--   `run`    what `:Run` executes, see 'lua/config/run.lua': a list, to which the arguments of the
--            call are appended, or `function(args)` returning a command, or `nil, nil` to leave it
--            to the language.
--
--     set('run', { 'npm', 'run', 'dev' })
--
-- NOTE: 'exrc' sources the files of every parent directory, nearest first; the first valid `set()` wins.
-- NOTE: read at startup (`start`) or when `:Run` is invoked (`run`); restart Neovim to apply a change.

local M = {}

-- Pure: `value, problems`; `value` is `nil` when the contract is unusable.
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

-- A non-empty list of strings, or a function; the contract of `:Run` ('lua/config/run.lua').
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

-- Closed set: `name -> parse(spec)`. A new contract is one function and one entry.
local contracts = { start = parse_start, run = parse_run }

-- `name -> { value, root }`, filled by `set()`.
local declared = {}

-- 'exrc' runs before 'mini.notify' takes `vim.notify` over: wait until startup is done to be seen.
local function warn(msg)
  vim.schedule(function() vim.notify(msg, vim.log.levels.WARN) end)
end

--- Declares contract `name` for the project whose '.nvim.lua' calls this.
-- NOTE: the declaring directory is that of the file calling `set()` itself, so a wrapper
-- helper in another file would name its own directory.
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
  local previous = declared[name]
  if not previous then
    declared[name] = { value = value, root = root }
  elseif previous.root == root then
    -- A nearer file shadowing a parent's is by design; the same file twice is a leftover.
    warn(
      ('%s: "%s" is already declared in this file, the first one wins'):format(
        where,
        name
      )
    )
  end
end

--- The project's value for contract `name` and the directory that declared it, or `nil`.
function M.contract(name)
  if contracts[name] == nil then
    vim.notify_once('Unknown project contract: ' .. name, vim.log.levels.WARN)
    return nil
  end
  local found = declared[name]
  if found then return found.value, found.root end
end

return M
