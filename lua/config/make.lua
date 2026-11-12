-- ┌─────────────────────┐
-- │ Async :Make, :LMake │
-- └─────────────────────┘
-- This module reports outcomes for synchronous `:make` and `:lmake`, which otherwise leave results
-- in their lists.
-- `:Make`/`:LMake` run without blocking. `setup()` in 'plugin/50_features.lua' enables this module.

local M = {}

-- Every `:compiler` plugin fills the same two lists, so one autocommand serves all languages.
-- NOTE: `v:shell_error` reports shell pipeline failure, not build failure.
-- A failed build can exit non-zero even when `errorformat` matches nothing.
-- Count `E` entries from `errorformat` to handle both failure forms.
local report_outcome = function(args)
  local list = args.match == 'lmake' and vim.fn.getloclist(0) or vim.fn.getqflist()
  local typed = function(t)
    return #vim.tbl_filter(
      function(item) return item.valid == 1 and item.type:upper() == t end,
      list
    )
  end
  local errors, warnings = typed('E'), typed('W')
  if errors > 0 then
    vim.notify(
      ('Build failed: %d error%s'):format(errors, errors == 1 and '' or 's'),
      vim.log.levels.ERROR
    )
  else
    local message = 'Build succeeded'
    if warnings > 0 then
      message = message
        .. (' (%d warning%s)'):format(warnings, warnings == 1 and '' or 's')
    end
    vim.notify(message, vim.log.levels.INFO)
  end
end

-- `expandcmd()` expands the forms that `:make` expands in 'makeprg', except `$*`.
-- Replace `$*` with arguments if present. Otherwise, append the arguments.
local build_cmd = function(args)
  local prg = vim.fn.expandcmd(vim.o.makeprg)
  local extra = table.concat(args, ' ')
  if prg:find('$*', 1, true) then
    prg = prg:gsub('%$%*', (extra:gsub('%%', '%%%%')))
  elseif extra ~= '' then
    prg = prg .. ' ' .. extra
  end
  return prg
end

-- Run through the configured shell, like `:make`. `vim.system()` takes an argv list and does not
-- use 'shell'.
M.shell_argv = function(cmd)
  local argv = { vim.o.shell }
  vim.list_extend(argv, vim.split(vim.o.shellcmdflag, ' ', { plain = true }))
  table.insert(argv, cmd)
  return argv
end

-- Run one job at a time. Warn and refuse a second job instead of stopping the first.
-- Stopping a build halfway can leave a partial object file.
local job = nil
local run = function(args, is_loc)
  if job ~= nil then
    return vim.notify(
      'A `:Make`/`:LMake` run is already in progress',
      vim.log.levels.WARN
    )
  end
  local cmd = build_cmd(args)
  vim.notify('Build started: ' .. cmd, vim.log.levels.INFO)
  job = vim.system(
    M.shell_argv(cmd),
    { cwd = vim.fn.getcwd(), text = true },
    function(out)
      job = nil
      vim.schedule(function()
        local lines = vim.split(
          (out.stdout or '') .. (out.stderr or ''),
          '\n',
          { trimempty = true }
        )
        local opts = { lines = lines, efm = vim.o.errorformat, title = 'Make' }
        if is_loc then
          vim.fn.setloclist(0, {}, ' ', opts)
        else
          vim.fn.setqflist({}, ' ', opts)
        end
        -- Trigger the report below exactly as `:make` does.
        vim.cmd(
          'doautocmd <nomodeline> QuickFixCmdPost ' .. (is_loc and 'lmake' or 'make')
        )
      end)
    end
  )
end

M.setup = function()
  Config.new_autocmd(
    'QuickFixCmdPost',
    { 'make', 'lmake' },
    report_outcome,
    'Report the outcome of :make/:lmake'
  )

  vim.api.nvim_create_user_command(
    'Make',
    function(cmdopts) run(cmdopts.fargs, false) end,
    { nargs = '*', desc = 'Async :make - same makeprg/errorformat, non-blocking' }
  )

  vim.api.nvim_create_user_command(
    'LMake',
    function(cmdopts) run(cmdopts.fargs, true) end,
    { nargs = '*', desc = 'Async :lmake - same makeprg/errorformat, non-blocking' }
  )
end

return M
