-- ┌─────────────────────┐
-- │ Async :Make, :LMake │
-- └─────────────────────┘
--
-- `:make` and `:lmake` run synchronously and leave the result to the list; here
-- they get a report of the outcome, and `:Make`/`:LMake` run them without
-- blocking. Switched on by `setup()` from 'plugin/50_features.lua'.

local M = {}

-- Language agnostic: every `:compiler` plugin fills the same two lists, so one
-- autocommand answers for all of them.
-- NOTE: `v:shell_error` is not relied on: it says whether the shell pipeline
-- failed, not whether the build did, and an `errorformat` that matches nothing
-- on a real failure still exits non-zero. Counting the `E` entries recognized
-- by `errorformat` covers both failure shapes.
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

-- `expandcmd()` expands the forms `:make` expands in 'makeprg'; `$*` is not one
-- of them, so it is replaced by hand if present and appended otherwise.
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

-- Run through the configured shell like `:make` does: `vim.system()` takes an
-- argv list and never goes through 'shell'.
M.shell_argv = function(cmd)
  local argv = { vim.o.shell }
  vim.list_extend(argv, vim.split(vim.o.shellcmdflag, ' ', { plain = true }))
  table.insert(argv, cmd)
  return argv
end

-- One run at a time: a second one warns and refuses instead of killing the first,
-- as a build killed halfway may leave a partial object file.
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
        -- Fires the report below exactly as `:make` itself would.
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
