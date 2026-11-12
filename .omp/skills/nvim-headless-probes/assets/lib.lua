--- This library supplies shared probe functions for this directory.
---
--- Each probe runs in a real Neovim session through `-c 'luafile <probe>'` with the user's
--- configuration loaded.
--- Parameters arrive as JSON in `$env:NVIM_PROBE`, which 'run.ps1' sets, or through `vim.g.probe`
--- during manual sourcing.
--- The probe does not hardcode the values to inspect.
---
--- Results contain `PASS` / `FAIL` / `INFO` lines and a final count.
--- The caller reads an explicit exit code. Headless Neovim exits 0 even if `setup()` fails.
--- Printing alone cannot make a check fail.
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

--- Read a parameter. Use `default` if the parameter is absent.
function M.param(name, default)
  local value = M.params[name]
  if value == nil then return default end
  return value
end

--- Read a parameter as a list. Accept a single value too.
function M.list(name, default)
  local value = M.param(name, default)
  if value == nil then return {} end
  if type(value) ~= 'table' then return { value } end
  return value
end

--- Read a required parameter.
--- Report missing parameters here to distinguish them from configuration defects that would cause
--- later errors.
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

--- Record an observation without a verdict. This cannot fail a run.
--- Use `check()` for assertions.
function M.info(text) table.insert(results, { kind = 'INFO', text = text }) end

--- Report the complete value when an assertion cannot describe the state.
function M.dump(label, value) M.info(label .. ' = ' .. vim.inspect(value)) end

--- Record a check that can fail. Include the observed value in `evidence`, not a repeat of the
--- check.
--- This lets readers review the verdict without another run.
function M.check(text, ok, evidence)
  local kind = ok and 'PASS' or 'FAIL'
  table.insert(results, { kind = kind, text = text, evidence = evidence })
  return ok
end

function M.fail(text, evidence) return M.check(text, false, evidence) end

--- Check a string against a Lua pattern from a parameter.
--- Return true if no pattern was requested, so expectations remain optional.
function M.expect(text, pattern, actual)
  if pattern == nil or pattern == '' then
    M.info(text .. ': ' .. tostring(actual))
    return true
  end
  local ok = actual ~= nil and tostring(actual):find(pattern) ~= nil
  return M.check(text .. ' matches `' .. pattern .. '`', ok, actual)
end

--- Position the cursor from a `find` search or explicit `row`/`col` parameters.
--- This shared "locate one spot in the buffer" contract replaces identical code in
--- 'treesitter.lua' and 'highlight.lua'.
--- Return the cursor position (1-based row, 0-based col).
--- If `find` has no match, report the failed `check()` and return `nil`.
--- The caller then only needs to check for `nil` and return.
function M.locate()
  local find = M.param('find')
  if find ~= nil then
    vim.fn.cursor(1, 1)
    local line = vim.fn.search(find, 'W')
    M.check('`' .. find .. '` found in the buffer', line > 0, line)
    if line == 0 then return nil end
  else
    vim.api.nvim_win_set_cursor(0, { M.param('row', 1), M.param('col', 0) })
  end
  return vim.api.nvim_win_get_cursor(0)
end

--- Check rendered lines against the optional `expect` and `absent` patterns.
---
--- Report only the line that determines each verdict.
--- A matching line gives the necessary evidence without a large, hard-to-read list.
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

--- Compile and run a Lua snippet from a parameter.
--- Setup stays in data (`before = "vim.cmd('Git diff HEAD~3')"`), so callers can reuse the probe
--- without copying it.
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

--- Send keys as if typed. Mode 'x' runs them immediately instead of queuing them until after the
--- probe ends.
function M.keys(lhs)
  local codes = vim.api.nvim_replace_termcodes(lhs, true, false, true)
  vim.api.nvim_feedkeys(codes, 'x', false)
end

--- Return the path suffix that identifies a buffer in a report.
function M.short(name)
  if name == nil or name == '' then return '[No Name]' end
  return name:match('[^/]*/?[^/]+$')
end

--- Wait for a language server to attach to the buffer and finish loading.
---
--- Use separate waits because attachment and loading failures differ.
--- A client that never attaches suggests an absent executable or a server that is not enabled.
--- An indexing server returns a "loading" message instead of the answer, which can look like a
--- configuration failure.
--- `:h vim.lsp.status()` gives the current progress message and is empty when no work runs.
---
--- An empty status does not prove completion.
--- Servers create successive progress tokens; `lua_ls` uses one per scope.
--- Short empty gaps occur between tokens. Wait for `quiet` milliseconds of continuous silence
--- instead of the first gap.
---
--- Return `ok, ms, note`. Report `ms` to distinguish "slow" from "stuck", which a fixed wait
--- cannot do.
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

--- Wait for buffer diagnostics to stop changing.
---
--- `DiagnosticChanged` occurs on each publication. A server can publish an empty list before the
--- complete list.
--- Waiting only for the event can give incomplete results. Wait for silence after it instead.
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

--- This sentinel ends a completed probe through an error.
--- In a one-shot run, `finish()` quits before anything catches it.
--- In a reused session, `run()` catches it without reporting a probe error.
M.ABORT = '<probe finished>'

--- Print the report and exit with a meaningful code.
---
--- For `session = true`, store the report in `g:probe_result` and the failure count in
--- `g:probe_failed` instead.
--- The driver reads both through the RPC socket. Keep the instance alive for the next probe.
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

--- Run `body` after configuration loading, then report.
---
--- `Config.later()` uses a timer after startup. An immediate probe can find no mappings,
--- autocommands, or plugins.
--- `wait` gives the grace period in milliseconds.
--- Increase it when the probe requires a plugin download or a language server reply.
function M.run(body)
  local report = function()
    local ok, err = pcall(body)
    if not ok then M.fail('the probe itself threw', err) end
    local done, err2 = pcall(M.finish)
    -- `finish()` uses `error()` to end a probe inside a session.
    -- Keep other reporting failures visible.
    if not done and err2 ~= M.ABORT then error(err2, 0) end
  end
  -- A reused session has already finished loading. Only a new instance needs the grace period.
  if M.param('session', false) then return report() end
  vim.defer_fn(report, M.param('wait', 1500))
end

return M
