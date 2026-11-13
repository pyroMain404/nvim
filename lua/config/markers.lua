-- ┌──────────────────────┐
-- │ FIXME/HACK/TODO/NOTE │
-- └──────────────────────┘
-- This module defines the four marker words and their case variants once.
-- The 'mini.hipatterns' highlighters in 'plugin/30_mini.lua' read `words`.
-- `setup()` creates the commands for `<Leader>ft` and `<Leader>fT`.

local M = {}

M.words = {
  fixme = { 'FIXME', 'Fixme', 'fixme' },
  hack = { 'HACK', 'Hack', 'hack' },
  todo = { 'TODO', 'Todo', 'todo' },
  note = { 'NOTE', 'Note', 'note' },
}

local order = { 'fixme', 'hack', 'todo', 'note' }
local label =
  table.concat(vim.tbl_map(function(k) return M.words[k][1] end, order), '/')

local variants = function()
  local all = {}
  for _, key in ipairs(order) do
    vim.list_extend(all, M.words[key])
  end
  return all
end

-- This function does not use `MiniHipatterns.get_matches()`.
-- That function reads extmarks that a debounced timer sets, so its results can be stale or empty
-- right after a buffer change.
-- A synchronous scan of the same words returns an immediate result.
-- Unlike the picker, a location list persists and supports navigation with `]q`/`[q`.
local buffer_markers = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local words = variants()
  local items = {}
  for lnum, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    for _, word in ipairs(words) do
      local col = line:find(word, 1, true)
      if col ~= nil then
        table.insert(
          items,
          { bufnr = bufnr, lnum = lnum, col = col, text = vim.trim(line) }
        )
        break
      end
    end
  end
  if #items == 0 then
    return vim.notify(
      'No ' .. label .. ' markers in this buffer',
      vim.log.levels.INFO
    )
  end
  vim.fn.setloclist(0, {}, ' ', { items = items, title = 'Hipatterns (buffer)' })
  vim.cmd('lopen')
end

-- NOTE: Call `rg` directly through `vim.system()`.
-- Shell quoting of the `\b(...)` alternation caused "Can't open errorfile".
-- 'grepformat' parses its `--vimgrep` output as `:grep` does.
local project_markers = function()
  if vim.fn.executable('rg') == 0 then
    return vim.notify(
      '`rg` not found on PATH: required for :HipatternsGrep',
      vim.log.levels.ERROR
    )
  end
  local pattern = '\\b(' .. table.concat(variants(), '|') .. ')\\b'
  vim.system(
    { 'rg', '--vimgrep', '-uu', pattern },
    { text = true, cwd = vim.fn.getcwd() },
    function(out)
      vim.schedule(function()
        local lines = vim.split(out.stdout or '', '\n', { trimempty = true })
        local opts =
          { lines = lines, efm = vim.o.grepformat, title = 'Hipatterns (project)' }
        vim.fn.setqflist({}, ' ', opts)
        if #vim.fn.getqflist() > 0 then
          vim.cmd('copen')
        else
          vim.notify(
            'No ' .. label .. ' markers found in the project',
            vim.log.levels.INFO
          )
        end
      end)
    end
  )
end

M.setup = function()
  vim.api.nvim_create_user_command('HipatternsLoc', buffer_markers, {
    desc = 'FIXME/HACK/TODO/NOTE markers of the current buffer, in the location list',
  })
  vim.api.nvim_create_user_command('HipatternsGrep', project_markers, {
    desc = 'FIXME/HACK/TODO/NOTE markers of the whole project, in the quickfix list',
  })
end

return M
