-- ┌────────┐
-- │ Glance │
-- └────────┘
--
-- Required by name from the `<Leader>eg` mapping in 'plugin/20_keymaps.lua'.
--
-- "Glance" shows the file under the cursor in a floating window and nothing
-- else: no buffer in the list, no change of the current window. It is the same
-- float `vim.diagnostic.open_float()` uses (`:h vim.lsp.util.open_floating_preview()`),
-- so it behaves the same way: it closes on the first cursor move, and pressing
-- `<Leader>eg` again while it is open moves into it (`q` or `<C-w>c` closes it).
-- The name is found the way `gf` finds it, through 'path' (`:h findfile()`), so
-- both agree on what a name means. When no file or directory matches, the `:h`
-- tag of the word is shown instead.
-- Example: cursor on 'extensions/x.ts' or on `vim.diagnostic.open_float`, then
-- `<Leader>eg`.

local M = {}

-- Lines read per file. A glance is a look, not a viewer: a bigger file is cut
-- here and the last line says so.
local max_lines = 60

-- The `:h` tag `tag` names, as lines starting at its definition, and the help
-- file they come from. Reads 'doc/tags' of every runtime directory, which is
-- what `:help` itself consults.
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
  local find = function(name)
    local found = name ~= '' and vim.fn.findfile(name) or ''
    if found == '' and name ~= '' then found = vim.fn.finddir(name) end
    return found ~= '' and found or nil
  end
  local path = vim.fn.expand('<cfile>')
  local file = find(path)
  -- Like `gf`, ask 'includeexpr' when `<cfile>` names nothing. `v:fname` is
  -- empty, enough for an expression that reads the cursor (a link, with spaces).
  if not file and vim.bo.includeexpr ~= '' then
    local ok, name = pcall(vim.fn.eval, vim.bo.includeexpr)
    if ok and type(name) == 'string' and name ~= '' then
      path, file = name, find(name)
    end
  end
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
    local name = path:gsub('%p+$', '')
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
        'Glance found no file or help tag: ' .. path,
        vim.log.levels.WARN
      )
    end
  end
  if #lines == 0 then lines = { '(empty)' } end

  -- Syntax `'markdown'` makes the float rewrite the text (`---` becomes a
  -- rule) and skip the ftplugin. Set the filetype in the float instead.
  local buf, win =
    vim.lsp.util.open_floating_preview(lines, ft ~= 'markdown' and ft or '', {
      focus_id = 'glance',
      title = ' ' .. title .. ' ',
      max_height = 25,
      max_width = 100,
    })
  if ft == 'markdown' then
    vim.api.nvim_win_call(win, function() vim.bo[buf].filetype = 'markdown' end)
  end
end

return M
