-- ┌─────────────┐
-- │  obsidian   │
-- └─────────────┘
-- This module sets up obsidian.nvim lazily for multiple vaults and provides the vault start menu.

local M = {}

-- A vault is the nearest ancestor directory named '.obsidian'.
-- NOTE: `MiniMisc.find_root()` cannot match directories and shares its cache with
-- `setup_auto_root()`.
-- Call `vim.fs.find()` directly.
local find_root = function(dir)
  local marker = vim.fs.find(
    { '.obsidian' },
    { path = dir, upward = true, type = 'directory' }
  )[1]
  return marker and vim.fs.dirname(marker) or nil
end

local find_vault_root = function(buf_id)
  local path = vim.api.nvim_buf_get_name(buf_id)
  return path ~= '' and find_root(vim.fs.dirname(path)) or nil
end

-- Merge per-vault settings from '.obsidian/nvim.json' over `setup()` settings.
-- NOTE: Read settings only on the first vault visit. Restart Neovim to apply changes.
local vault_overrides = function(root)
  local path = root .. '/.obsidian/nvim.json'
  if vim.fn.filereadable(path) == 0 then return nil end
  local ok, overrides = pcall(
    vim.json.decode,
    table.concat(vim.fn.readfile(path), '\n'),
    { luanil = { object = true, array = true } }
  )
  if ok and type(overrides) == 'table' then return overrides end
  vim.notify(path .. ' is not a JSON object', vim.log.levels.WARN)
end

-- HACK: obsidian.nvim 9af605a shows only `entry.text` when it exists.
-- For ambiguous links, `text` contains each note's first line, so all picker rows show frontmatter
-- `---`.
-- Show the path. For entries at file start, also show the first line after frontmatter.
-- Delete this when `make_display()` shows the path itself.
local patch_make_display = function()
  local first_body_line = function(path)
    local ok, lines = pcall(vim.fn.readfile, path, '', 200)
    if not ok then return nil end
    local from = 1
    if lines[1] == '---' then
      from = vim.fn.index(lines, '---', 1) + 2
      if from < 3 then return nil end
    end
    return vim
      .iter(lines)
      :skip(from - 1)
      :find(function(line) return line:find('%S') end)
  end
  local picker_util = require('obsidian.picker.util')
  local make_display = picker_util.make_display
  picker_util.make_display = function(entry)
    if type(entry) ~= 'table' or not entry.filename or not entry.text then
      return make_display(entry)
    end
    local shown = vim.deepcopy(entry)
    shown.text = nil
    if entry.lnum == 1 then
      shown.lnum, shown.col = nil, nil
      entry = { text = first_body_line(entry.filename) or entry.text }
    end
    return make_display(shown) .. '  ' .. entry.text
  end
end

local enter_note = function(note)
  -- `<Leader>j` opens the `:Obsidian` command picker, with selection commands in Visual mode.
  for mode, rhs in pairs({ n = '<Cmd>Obsidian<CR>', x = ':Obsidian<CR>' }) do
    vim.keymap.set(
      mode,
      '<Leader>j',
      rhs,
      { buf = note.bufnr, desc = 'Obsidian commands' }
    )
  end
  -- 'includeexpr' cannot follow headings or `[[#heading]]`.
  vim.keymap.set(
    'n',
    'gf',
    function()
      return require('obsidian.api').cursor_link()
          and '<Cmd>Obsidian follow_link<CR>'
        or 'gf'
    end,
    { buf = note.bufnr, expr = true, desc = 'Follow Obsidian link or file' }
  )
  -- Replace the plugin's `]o` / `[o`, which hide 'mini.bracketed' conflict markers in vault notes.
  for key, direction in pairs({ [']x'] = 'next', ['[x'] = 'prev' }) do
    vim.keymap.set(
      'n',
      key,
      function() require('obsidian.actions').nav_link(direction, true) end,
      { buf = note.bufnr, desc = 'Obsidian ' .. direction .. ' link' }
    )
  end
end

local obsidian_loaded = false
local obsidian_roots = {}
local plugin_spec

-- Install and set up the plugin on the first vault visit. Later vaults only register a workspace.
-- obsidian.nvim selects the active workspace in its own `FileType` autocmd.
local load_vault = function(spec, root)
  if obsidian_roots[root] then return end

  if not obsidian_loaded then
    -- HACK: obsidian.nvim cannot sync a `title` or first heading equal to the `id` during rename.
    -- This fork branch adds `frontmatter.sync_title`, `note.sync_heading`, and `note.sync_filename`
    -- to upstream main.
    -- Upstream includes its element rename through obsidian-nvim/obsidian.nvim#1009, merged into
    -- this branch at 9af605a (2026-11-09).
    -- Return to 'https://github.com/obsidian-nvim/obsidian.nvim' when upstream merges the sync
    -- options.
    vim.pack.add({ spec })
    if #vim.api.nvim_get_runtime_file('lua/obsidian/init.lua', false) == 0 then
      vim.notify_once(
        'obsidian.nvim is unavailable; run :checkhealth config',
        vim.log.levels.ERROR
      )
      return
    end
    -- Keep the plugin's `<CR>`, `]o`, `[o` maps off. It reads this flag once per note.
    vim.g.obsidian_default_keymap = false
    require('obsidian').setup({
      legacy_commands = false,
      -- See 'docs/Frontmatter.md' and 'docs/Note.md' of the plugin.
      frontmatter = { sync_title = true },
      note = { sync_heading = true, sync_filename = true },
      picker = { name = 'mini.pick' },
      templates = {
        substitutions = {
          -- This aliases 'tmpl_persona', which Obsidian's Templates cannot compute.
          first_word = function(ctx)
            local title = ctx.partial_note and ctx.partial_note:display_name()
            return title and title:match('%S+') or ''
          end,
        },
      },
      callbacks = { enter_note = enter_note },
      workspaces = {
        { name = root, path = root, overrides = vault_overrides(root) },
      },
    })
    patch_make_display()
    obsidian_loaded = true
  else
    table.insert(
      Obsidian.workspaces,
      require('obsidian.workspace').new({
        name = root,
        path = root,
        overrides = vault_overrides(root),
      })
    )
  end
  obsidian_roots[root] = true
end

local setup_obsidian = function(spec, ev)
  local root = find_vault_root(ev.buf)
  if root then load_vault(spec, root) end
end

-- No note buffer exists on the start screen to trigger the lazy load.
local command = function(root, subcommand)
  load_vault(plugin_spec, root)
  if not obsidian_loaded then return end -- load_vault() already reported why
  if Obsidian.workspace.name ~= root then require('obsidian.workspace').set(root) end
  vim.cmd('Obsidian ' .. subcommand)
end

---@param spec table vim.pack spec of obsidian.nvim
function M.setup(spec)
  plugin_spec = spec
  -- NOTE: Do not match '*.base'. obsidian.nvim attaches only to `FileType` markdown/quarto.
  Config.new_autocmd(
    { 'BufReadPre', 'BufNewFile' },
    { '*.md', '*.markdown', '*.qmd' },
    function(ev) setup_obsidian(spec, ev) end,
    'Setup obsidian.nvim for vault'
  )

  -- Startup buffers from `-c`/session/`--cmd` have already triggered `BufReadPre`.
  vim.schedule(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'markdown' then
        setup_obsidian(spec, { buf = buf })
      end
    end
  end)
end

-- Return the 'mini.starter' config for the cwd vault, or `nil` outside a vault for the default
-- screen.
function M.starter_config()
  local root = find_root(vim.fn.getcwd())
  if not root then return nil end

  -- Each item contains { section, name, `:Obsidian` subcommand }.
  local rows = {
    { 'Daily', 'Today', 'today' },
    { 'Daily', 'Yesterday', 'yesterday' },
    { 'Daily', 'Dailies', 'dailies' },
    { 'Notes', 'New note', 'new' },
    { 'Notes', 'Templated note', 'new_from_template' },
    { 'Notes', 'Unique note', 'unique_note' },
    { 'Find', 'Switch note', 'quick_switch' },
    { 'Find', 'Search', 'search' },
    { 'Find', 'Tags', 'tags' },
    { 'Find', 'Properties', 'properties' },
    { 'Find', 'Bookmarks', 'bookmarks' },
    { 'Vault', 'Commands', '' },
  }
  local items = vim.tbl_map(function(row)
    return {
      section = row[1],
      name = row[2],
      action = function() command(root, row[3]) end,
    }
  end, rows)
  table.insert(items, {
    section = 'Vault',
    name = 'Files',
    action = function() MiniFiles.open(root) end,
  })

  local starter = require('mini.starter')
  table.insert(items, starter.sections.recent_files(5, true, false))
  table.insert(items, starter.sections.builtin_actions())
  return {
    header = 'Obsidian vault: '
      .. vim.fs.basename(root)
      .. '\n'
      .. vim.fn.fnamemodify(root, ':~'),
    items = items,
  }
end

return M
