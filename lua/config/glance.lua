-- ┌─────────────────────────────┐
-- │ Glance and link resolution  │
-- └─────────────────────────────┘
--
-- Required by name: 'after/ftplugin/markdown.lua' (`gf` on a link) and the
-- `<Leader>eg` mapping in 'plugin/20_keymaps.lua'.
--
-- "Glance" shows the file under the cursor in a floating window and nothing
-- else: no buffer in the list, no change of the current window. It is the same
-- float `vim.diagnostic.open_float()` uses (`:h vim.lsp.util.open_floating_preview()`),
-- so it behaves the same way: it closes on the first cursor move, and pressing
-- `<Leader>eg` again while it is open moves into it (`q` or `<C-w>c` closes it).
-- Example: cursor on `[Discovery](references/discovery.md)` or on a path in
-- any file, then `<Leader>eg`.

local M = {}

-- Lines read per file. A glance is a look, not a viewer: a bigger file is cut
-- here and the last line says so.
local max_lines = 60

-- Markdown `[label](target)` link covering the cursor, on label or path alike.
-- Returns the target without its `#anchor`, and the target as written.
-- `<...>` and a trailing title are handled; the cursor column is a byte column
-- in the source text, so it is right in the rendered (concealed) states too.
M.link = function()
  local line, col = vim.api.nvim_get_current_line(), vim.fn.col('.')
  local init = 1
  while true do
    local s, e, target = line:find('%b[]%(%s*([^)]-)%s*%)', init)
    if not s then return nil end
    if col >= s and col <= e then
      target = target:match('^<([^>]*)>') or target:match('^(%S+)')
      return target and target:gsub('#.*$', '') or nil, target
    end
    init = e + 1
  end
end

-- First existing candidate for `path`: as is (absolute, or relative to the
-- working directory), relative to the current file, relative to the repository.
M.resolve = function(path)
  path = vim.fs.normalize(path)
  local root = vim.fs.root(0, '.git')
  local base = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  local candidates = { path, vim.fs.joinpath(base, path) }
  if root then table.insert(candidates, vim.fs.joinpath(root, path)) end
  for _, c in ipairs(candidates) do
    if vim.uv.fs_stat(c) then return c end
  end
end

-- Show the file or directory under the cursor in a floating window.
M.open = function()
  local path, raw
  if vim.bo.filetype == 'markdown' then
    path, raw = M.link()
  end
  if not raw then path = vim.fn.expand('<cfile>') end
  if raw and raw:match('^%a[%w+.-]*://') then
    return vim.notify('Glance shows files, not URLs: ' .. raw, vim.log.levels.WARN)
  end
  if path == nil or path == '' then
    return vim.notify('Nothing to glance at under the cursor', vim.log.levels.WARN)
  end
  local file = M.resolve(path)
  if not file then
    return vim.notify('Glance target not found: ' .. path, vim.log.levels.WARN)
  end

  local lines, ft = {}, nil
  if vim.uv.fs_stat(file).type == 'directory' then
    for name, type in vim.fs.dir(file) do
      table.insert(lines, type == 'directory' and name .. '/' or name)
    end
  else
    local ok, read = pcall(vim.fn.readfile, file, '', max_lines + 1)
    if not ok or table.concat(read):find('%z') then
      return vim.notify(
        'Glance cannot show ' .. file .. ' (binary?)',
        vim.log.levels.WARN
      )
    end
    lines = read
    if #lines > max_lines then lines[max_lines + 1] = '…' end
    ft = vim.filetype.match({ filename = file })
  end
  if #lines == 0 then lines = { '(empty)' } end

  vim.lsp.util.open_floating_preview(lines, ft or '', {
    focus_id = 'glance',
    title = ' ' .. vim.fn.fnamemodify(file, ':~:.') .. ' ',
    max_height = 25,
    max_width = 100,
  })
end

return M
