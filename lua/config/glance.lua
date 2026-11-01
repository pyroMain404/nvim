-- ┌────────┐
-- │ Glance │
-- └────────┘
--
-- Required by name from the `<Leader>eg` mapping in 'plugin/20_keymaps.lua'.
--
-- Shows the file under the cursor in the float `vim.diagnostic.open_float()`
-- uses (`:h vim.lsp.util.open_floating_preview()`): no buffer, no window change,
-- closes on cursor move; `<Leader>eg` again enters it. The name is resolved like
-- `gf` ('path'); failing that, the `:h` tag of the word is shown.

local M = {}

-- Lines read per file; the last line says when a bigger file was cut.
local max_lines = 60

-- The lines of the `:h` tag from its definition, and its help file ('doc/tags').
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

M.open = function()
  local find = function(name)
    local found = name ~= '' and vim.fn.findfile(name) or ''
    if found == '' and name ~= '' then found = vim.fn.finddir(name) end
    return found ~= '' and found or nil
  end
  local path = vim.fn.expand('<cfile>')
  local file = find(path)
  -- Like `gf`, fall back to 'includeexpr' (`v:fname` empty, fine for cursor-reading expressions).
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
  -- rule) and skip the ftplugin. Set the filetype in the float instead, and
  -- ask the ftplugin for the nonmodifiable `reading` state, not its default.
  local buf, win =
    vim.lsp.util.open_floating_preview(lines, ft ~= 'markdown' and ft or '', {
      focus_id = 'glance',
      title = ' ' .. title .. ' ',
      max_height = 25,
      max_width = 100,
    })
  if ft == 'markdown' then
    vim.b[buf].markdown_om_start = 'reading'
    vim.api.nvim_win_call(win, function() vim.bo[buf].filetype = 'markdown' end)
  end
end

return M
