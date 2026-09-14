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

--- Check a list of rendered lines against the `expect` and `absent` patterns.
---
--- Both are optional, and both report the line that decided the verdict rather
--- than the whole list: an evidence block of forty lines is one nobody reads,
--- and the one line that matched is the whole answer.
function M.match(label, lines)
  local expect = M.param('expect')
  if expect then
    local hit
    for _, line in ipairs(lines) do
      if tostring(line):find(expect) then
        hit = line
        break
      end
    end
    M.check(
      ('a %s matches `%s`'):format(label, expect),
      hit ~= nil,
      hit or ('%d line(s), none matching'):format(#lines)
    )
  end
  local absent = M.param('absent')
  if absent then
    local hit
    for _, line in ipairs(lines) do
      if tostring(line):find(absent) then
        hit = line
        break
      end
    end
    M.check(
      ('no %s matches `%s`'):format(label, absent),
      hit == nil,
      hit or ('%d line(s) checked'):format(#lines)
    )
  end
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

--- Wait until an autocommand fires, instead of waiting a fixed time.
---
--- A fixed `vim.wait` is a guess in both directions: too short and the probe
--- reports a state that was still being built, too long and every run pays for
--- the worst case. An event says exactly when the thing happened, so this is
--- the form to reach for whenever Neovim emits one (`:h events`).
---
--- Returns whether it fired, and how many milliseconds it took.
function M.wait_event(event, opts)
  opts = opts or {}
  local fired = false
  local id = vim.api.nvim_create_autocmd(event, {
    pattern = opts.pattern,
    buffer = opts.buffer,
    once = true,
    callback = function() fired = true end,
  })
  local t0 = vim.uv.now()
  vim.wait(opts.timeout or 30000, function() return fired end, 50)
  pcall(vim.api.nvim_del_autocmd, id)
  return fired, vim.uv.now() - t0
end

--- Wait until a language server is attached to the buffer AND done loading.
---
--- Two waits, because they fail differently: a client that never attaches is
--- a missing executable or a server not enabled, while a client that attached
--- but is still indexing answers requests with its own "loading" message
--- instead of the answer - which reads exactly like a wrong configuration.
--- `:h vim.lsp.status()` is the readiness signal: it holds the current progress
--- message and is empty when nothing is running.
---
--- Empty is not the same as done, which is the trap this function exists to
--- close. A server opens several progress tokens in a row (`lua_ls` uses one
--- per scope it loads), and between two of them the status is empty for a
--- moment that looks exactly like the end. So this waits for `quiet`
--- milliseconds of continuous silence, not for the first gap.
---
--- Returns `ok, ms, note`. Report `ms`: it is the evidence that separates
--- "slow" from "stuck", and it is what a fixed wait can never tell you.
function M.wait_lsp(opts)
  opts = opts or {}
  local buf = opts.bufnr or 0
  local timeout = opts.timeout or 60000
  local quiet = opts.quiet or 1000
  local t0 = vim.uv.now()
  local attached = vim.wait(
    timeout,
    function() return #vim.lsp.get_clients({ bufnr = buf }) > 0 end,
    50
  )
  if not attached then return false, vim.uv.now() - t0, 'no client attached' end

  local last_busy, seen = vim.uv.now(), false
  local idle = vim.wait(timeout, function()
    if vim.lsp.status() ~= '' then
      last_busy, seen = vim.uv.now(), true
      return false
    end
    return (vim.uv.now() - last_busy) > quiet
  end, 100)
  local note = seen and (idle and 'workspace loaded' or 'still loading')
    or 'attached, no progress reported'
  return idle, vim.uv.now() - t0, note
end

--- Wait until diagnostics for the buffer settle.
---
--- `DiagnosticChanged` fires on every publish, and a server publishes more than
--- once (an empty list first, then the real one). Waiting for the event alone
--- therefore reads a half-filled state; this waits for the quiet after it.
function M.wait_diagnostics(opts)
  opts = opts or {}
  local buf = opts.bufnr or 0
  local timeout = opts.timeout or 30000
  local last = vim.uv.now()
  local id = vim.api.nvim_create_autocmd('DiagnosticChanged', {
    buffer = buf == 0 and vim.api.nvim_get_current_buf() or buf,
    callback = function() last = vim.uv.now() end,
  })
  local t0, quiet = vim.uv.now(), opts.quiet or 700
  vim.wait(
    timeout,
    function() return last > t0 and (vim.uv.now() - last) > quiet end,
    50
  )
  pcall(vim.api.nvim_del_autocmd, id)
  return vim.diagnostic.get(buf), vim.uv.now() - t0
end

--- Sentinel thrown to unwind out of a probe that is finished. In a one-shot
--- run `finish()` quits and nothing sees it; inside a reused session there is
--- nothing to quit, so `run()` catches this instead of reporting it as a throw.
M.ABORT = '<probe finished>'

--- Print the report and exit with a code that means something.
---
--- Inside a session (`session = true`) neither happens: the report is left in
--- `g:probe_result` and the count of failures in `g:probe_failed`, for the
--- driver to read over the RPC socket, and the instance stays alive for the
--- probe after this one.
function M.finish()
  local failed = 0
  for _, r in ipairs(results) do
    if r.kind == 'FAIL' then failed = failed + 1 end
  end
  local lines = {}
  if M.param('json', false) then
    table.insert(lines, vim.json.encode({ results = results, failed = failed }))
  else
    for _, r in ipairs(results) do
      table.insert(lines, r.kind .. ' ' .. r.text)
      if r.evidence ~= nil then
        table.insert(lines, '      ' .. tostring(r.evidence):gsub('\n', '\n      '))
      end
    end
    table.insert(lines, ('--- %d lines, %d failed'):format(#results, failed))
  end
  local text = table.concat(lines, '\n')

  if M.param('session', false) then
    vim.g.probe_result = text
    vim.g.probe_failed = failed
    results = {}
    error(M.ABORT, 0)
  end

  io.stdout:write(text .. '\n')
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
  local report = function()
    local ok, err = pcall(body)
    if not ok then M.fail('the probe itself threw', err) end
    local done, err2 = pcall(M.finish)
    -- `finish()` unwinds through `error()` inside a session; anything else is
    -- a real failure of the reporting itself, which has to stay visible.
    if not done and err2 ~= M.ABORT then error(err2, 0) end
  end
  -- A reused session finished loading long before this probe was sourced, so
  -- the grace period only makes sense for a fresh instance.
  if M.param('session', false) then return report() end
  vim.defer_fn(report, M.param('wait', 1500))
end

return M
