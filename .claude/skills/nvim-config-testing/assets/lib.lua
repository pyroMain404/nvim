--- Shared library of the probes in this directory.
---
--- A probe is a Lua file injected into a real Neovim session with `-c 'luafile
--- <probe>'`, so it runs with the configuration actually loaded - the only way
--- to see what the user sees. It never hardcodes what it looks at: parameters
--- arrive as JSON in `$env:NVIM_PROBE` (set by 'run.ps1') or in `vim.g.probe`
--- when the probe is sourced by hand from an interactive session.
---
--- Results are `PASS` / `FAIL` / `INFO` lines and a final count. The exit code
--- is what a caller reads, and it has to be set explicitly: headless Neovim
--- exits 0 even when a `setup()` threw, so a probe that only prints is a probe
--- that can never fail a check.
local M = {}

M.params = {}

local raw = vim.env.NVIM_PROBE
if raw ~= nil and raw ~= '' then
  local ok, decoded = pcall(vim.json.decode, raw)
  if ok and type(decoded) == 'table' then M.params = decoded end
end
if type(vim.g.probe) == 'table' then
  M.params = vim.tbl_extend('force', M.params, vim.g.probe)
end

local results = {}

--- Read a parameter, falling back to `default` when it was not given.
function M.param(name, default)
  local value = M.params[name]
  if value == nil then return default end
  return value
end

--- Read a parameter as a list, accepting a single value for convenience.
function M.list(name, default)
  local value = M.param(name, default)
  if value == nil then return {} end
  if type(value) ~= 'table' then return { value } end
  return value
end

--- Read a parameter the probe cannot work without. Failing here, instead of
--- letting the probe throw later, is what tells a missing parameter apart from
--- a real defect in the configuration.
function M.need(name)
  local value = M.param(name)
  if value == nil or value == '' then
    M.fail(
      'missing parameter `' .. name .. '`',
      'pass -Params @{ ' .. name .. ' = ... }'
    )
    M.finish()
  end
  return value
end

--- Free-form observation. It carries no verdict, so it can never fail a run:
--- use it for what you want to read, `check()` for what you want to assert.
function M.info(text) table.insert(results, { kind = 'INFO', text = text }) end

--- Report a value in full, for the parts of a state no assertion can express.
function M.dump(label, value) M.info(label .. ' = ' .. vim.inspect(value)) end

--- A check that can fail. `evidence` is what makes the verdict re-readable
--- later without running anything again, so give the observed value, not
--- a restatement of the check.
function M.check(text, ok, evidence)
  local kind = ok and 'PASS' or 'FAIL'
  table.insert(results, { kind = kind, text = text, evidence = evidence })
  return ok
end

function M.fail(text, evidence) return M.check(text, false, evidence) end

--- Check a string against a Lua pattern given as a parameter. Returns true
--- when no pattern was asked for, so an optional expectation stays optional.
function M.expect(text, pattern, actual)
  if pattern == nil or pattern == '' then
    M.info(text .. ': ' .. tostring(actual))
    return true
  end
  local ok = actual ~= nil and tostring(actual):find(pattern) ~= nil
  return M.check(text .. ' matches `' .. pattern .. '`', ok, actual)
end

--- Compile and run a Lua snippet passed as a parameter. This is what keeps
--- a probe reusable: the setup that brings the session into the state worth
--- probing is data (`before = "vim.cmd('Git diff HEAD~3')"`), not one more
--- copy of the probe.
function M.eval(name)
  local src = M.param(name)
  if src == nil or src == '' then return nil end
  local chunk, err = load(src, '=' .. name)
  if chunk == nil then
    M.fail('parameter `' .. name .. '` does not compile', err)
    M.finish()
  end
  return chunk()
end

--- Send keys as if typed. Mode 'x' is what makes them run now instead of
--- being queued until the probe has already ended.
function M.keys(lhs)
  local codes = vim.api.nvim_replace_termcodes(lhs, true, false, true)
  vim.api.nvim_feedkeys(codes, 'x', false)
end

--- The tail of a path, which is what identifies a buffer in a report.
function M.short(name, segments)
  if name == nil or name == '' then return '[No Name]' end
  local parts = vim.split(name, '/')
  segments = segments or 2
  local first = math.max(1, #parts - segments + 1)
  return table.concat(vim.list_slice(parts, first, #parts), '/')
end

--- Print the report and exit with a code that means something.
function M.finish()
  local failed = 0
  for _, r in ipairs(results) do
    if r.kind == 'FAIL' then failed = failed + 1 end
  end
  if M.param('json', false) then
    io.stdout:write(vim.json.encode({ results = results, failed = failed }) .. '\n')
  else
    for _, r in ipairs(results) do
      io.stdout:write(r.kind .. ' ' .. r.text .. '\n')
      if r.evidence ~= nil then
        local evidence = tostring(r.evidence):gsub('\n', '\n      ')
        io.stdout:write('      ' .. evidence .. '\n')
      end
    end
    io.stdout:write(('--- %d lines, %d failed\n'):format(#results, failed))
  end
  vim.cmd(failed > 0 and 'cquit! 1' or 'qa!')
end

--- Run `body` once the configuration has finished loading, then report.
---
--- Everything set up through `Config.later()` runs on a timer after startup, so
--- a probe that looks immediately finds a configuration that does not exist
--- yet: no mappings, no autocommands, no plugins. `wait` is that grace period
--- in milliseconds - raise it when what you probe needs a plugin to be
--- downloaded or a language server to answer.
function M.run(body)
  vim.defer_fn(function()
    local ok, err = pcall(body)
    if not ok then M.fail('the probe itself threw', err) end
    M.finish()
  end, M.param('wait', 1500))
end

return M
