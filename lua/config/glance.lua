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
-- working directory), then relative to the directory of the current file and to
-- every directory above it. Walking up covers the repository root and the case
-- of a document that names a file of its plugin ('extensions/x.ts' written in
-- 'skills/x/SKILL.md'), where the root of the project is not the git root.
M.resolve = function(path)
  path = vim.fs.normalize(path)
  if vim.uv.fs_stat(path) then return path end
  local base = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  local dirs = { base }
  for parent in vim.fs.parents(base) do
    table.insert(dirs, parent)
  end
  for _, dir in ipairs(dirs) do
    local candidate = vim.fs.joinpath(dir, path)
    if vim.uv.fs_stat(candidate) then return candidate end
  end
end

-- Last resort: the `:h` tag that `tag` names, as lines starting at its
-- definition, and the help file they come from. Reads 'doc/tags' of every
-- runtime directory, which is what `:help` itself consults.
local help_tag = function(tag)
  for _, tags in ipairs(vim.api.nvim_get_runtime_file('doc/tags', true)) do
    for line in io.lines(tags) do
      local name, file = line:match('^([^\t]+)\t([^\t]+)\t')
      if name == tag then
        local doc = vim.fs.joinpath(vim.fs.dirname(tags), file)
        local all = vim.fn.readfile(doc)
        for i, text in ipairs(all) do
          if text:find('*' .. tag .. '*', 1, true) then
            return vim.list_slice(all, i, i + max_lines - 1), doc
          end
        end
      end
    end
  end
end

-- Show the file or directory under the cursor in a floating window; failing
-- that, the help for the word under the cursor.
M.open = function()
  local path, raw
  if vim.bo.filetype == 'markdown' then
    path, raw = M.link()
  end
  if not raw then path = vim.fn.expand('<cfile>') end
  if raw and raw:match('^%a[%w+.-]*://') then
    return vim.notify('Glance shows files, not URLs: ' .. raw, vim.log.levels.WARN)
  end

  local file = path and path ~= '' and M.resolve(path)
  local lines, ft, title = {}, nil, nil
  if file then
    title = vim.fn.fnamemodify(file, ':~:.')
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
  else
    local word = vim.fn.expand('<cword>')
    local name = (path or ''):gsub('%p+$', '')
    -- A function is tagged with its parentheses (`vim.diagnostic.open_float()`),
    -- an option with its quotes. Punctuation alone (`.`) is a tag too: skip it.
    for _, tag in ipairs({
      name,
      name .. '()',
      word,
      word .. '()',
      "'" .. word .. "'",
    }) do
      local found, doc = nil, nil
      if tag:find('%w') then
        found, doc = help_tag(tag)
      end
      if found then
        lines, ft, title =
          found, 'help', ':h ' .. tag .. ' (' .. vim.fs.basename(doc) .. ')'
        break
      end
    end
    if not title then
      return vim.notify(
        'Glance found no file or help tag: ' .. (path or ''),
        vim.log.levels.WARN
      )
    end
  end
  if #lines == 0 then lines = { '(empty)' } end

  vim.lsp.util.open_floating_preview(lines, ft or '', {
    focus_id = 'glance',
    title = ' ' .. title .. ' ',
    max_height = 25,
    max_width = 100,
  })
end

return M
