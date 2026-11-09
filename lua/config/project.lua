-- ┌───────────────────┐
-- │ Project contracts │
-- └───────────────────┘
--
-- What a project may declare for this config, in its '.nvim-project.json'; found, trusted, validated and cached here.
--
-- One JSON object; each top-level key is a contract name. The only contract today is `start`:
--
--   {
--     "start": {
--       "strategy": "merge | substitute (default substitute)",
--       "header": "optional string; \n allowed",
--       "items": [
--         { "section": "Build", "name": "Run", "command": "Run" },
--         { "section": "Docs", "name": "Readme", "file": "README.md" }
--       ]
--     }
--   }
--
-- NOTE: read once per session; restart Neovim to apply a change.

local M = {}

-- Pure: `value, problems`; `value` is `nil` when the contract is unusable.
local function parse_start(section, root)
  if
    type(section) ~= 'table'
    or type(section.items) ~= 'table'
    or not vim.islist(section.items)
  then
    return nil, { '"start" needs an "items" array' }
  end
  local problems = {}
  local strategy = section.strategy
  if strategy == nil then
    strategy = 'substitute'
  elseif strategy ~= 'merge' and strategy ~= 'substitute' then
    return nil, { '"start.strategy" must be "merge" or "substitute"' }
  end
  local header = section.header
  if header ~= nil and type(header) ~= 'string' then
    table.insert(problems, '"start.header" must be a string')
    header = nil
  end
  local items = {}
  for i, item in ipairs(section.items) do
    local action
    if type(item) == 'table' then
      if type(item.command) == 'string' then
        action = item.command
      elseif type(item.file) == 'string' then
        action = 'edit ' .. vim.fn.fnameescape(vim.fs.joinpath(root, item.file))
      end
    end
    if
      type(item) == 'table'
      and type(item.name) == 'string'
      and action
      and action ~= ''
    then
      table.insert(items, {
        name = item.name,
        section = type(item.section) == 'string' and item.section or 'Project',
        action = action,
      })
    else
      table.insert(
        problems,
        ('start: item %d needs a "name" and a non-empty "command" or "file"'):format(
          i
        )
      )
    end
  end
  return { strategy = strategy, header = header, items = items }, problems
end

-- Closed set: `name -> parse(section, root)`. A new contract is one function and one entry.
local contracts = { start = parse_start }

-- `false` marks an unusable file, so nothing is re-prompted or re-reported.
local projects = {}

local function load(marker)
  -- Items run Ex commands: same trust database as '.nvim.lua' (`:h vim.secure.read()`).
  local contents = vim.secure.read(marker)
  if not contents then return false end
  local ok, spec =
    pcall(vim.json.decode, contents, { luanil = { object = true, array = true } })
  if not ok or type(spec) ~= 'table' then
    vim.notify(marker .. ' is not a JSON object', vim.log.levels.WARN)
    return false
  end
  for key in pairs(spec) do
    if not contracts[key] then
      vim.notify(
        ('%s: unknown contract "%s"'):format(marker, key),
        vim.log.levels.WARN
      )
    end
  end
  return { root = vim.fs.dirname(marker), spec = spec, parsed = {} }
end

--- The project's value for contract `name` and the project root, or `nil`.
function M.contract(name)
  if contracts[name] == nil then
    vim.notify_once('Unknown project contract: ' .. name, vim.log.levels.WARN)
    return nil
  end
  local marker = vim.fs.find(
    '.nvim-project.json',
    { path = vim.fn.getcwd(), upward = true, type = 'file' }
  )[1]
  if not marker then return nil end
  if projects[marker] == nil then projects[marker] = load(marker) end
  local project = projects[marker]
  if not project or project.spec[name] == nil then return nil end
  if project.parsed[name] == nil then
    local value, problems = contracts[name](project.spec[name], project.root)
    for _, problem in ipairs(problems) do
      vim.notify(('%s: %s'):format(marker, problem), vim.log.levels.WARN)
    end
    project.parsed[name] = value or false
  end
  return project.parsed[name] or nil, project.root
end

return M
