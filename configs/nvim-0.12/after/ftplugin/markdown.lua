-- ┌─────────────────────────┐
-- │ Markdown buffer config  │
-- └─────────────────────────┘
--
-- This file keeps Markdown-only behavior out of the shared plugin files.
-- `render-markdown.nvim` is the renderer; `<Leader>om` selects its
-- source -> live -> reading -> source cycle.

vim.wo[0][0].spell = true
vim.wo[0][0].wrap = true
vim.wo[0][0].foldmethod = 'expr'
vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'

-- Disable built-in `gO` mapping in favor of 'mini.basics'
vim.keymap.del('n', 'gO', { buf = 0 })

vim.b.minisurround_config = {
  custom_surroundings = {
    -- Markdown link. Common usage:
    -- `saiwL` + [type/paste link] + <CR> - add link
    -- `sdL` - delete link
    -- `srLL` + [type/paste link] + <CR> - replace link
    L = {
      input = { '%[().-()%]%(.-%)' },
      output = function()
        local link = require('mini.surround').user_input('Link: ')
        return { left = '[', right = '](' .. link .. ')' }
      end,
    },
  },
}

local original = vim.b.markdown_om_original
if not original then
  original = {
    modifiable = vim.bo.modifiable,
    readonly = vim.bo.readonly,
    windows = {},
  }
  for _, win in
    ipairs(vim.fn.getbufinfo(vim.api.nvim_get_current_buf())[1].windows or {})
  do
    original.windows[win] = {
      conceallevel = vim.wo[win][0].conceallevel,
      concealcursor = vim.wo[win][0].concealcursor,
    }
  end
  vim.b.markdown_om_original = original
end

vim.b.markdown_om = 'source'

local function restore()
  local saved = vim.b.markdown_om_original
  if not saved then
    vim.bo.readonly = false
    vim.bo.modifiable = true
    return
  end
  vim.bo.readonly = saved.readonly
  vim.bo.modifiable = saved.modifiable
  for win, options in pairs(saved.windows) do
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win][0].conceallevel = options.conceallevel
      vim.wo[win][0].concealcursor = options.concealcursor
    end
  end
end

local renderer_available = #vim.api.nvim_get_runtime_file(
  'lua/render-markdown/init.lua',
  false
) > 0
-- HACK: render-markdown.nvim 640a3ec6 exposes hidden lines only through its
-- private extmark namespace, without identifying which feature concealed them.
-- Reading needs `j`/`k` to skip concealed fence delimiters, but must visit every
-- pipe-table source row. Delete this when it offers a visible-line motion.
local function line_is_pipe_table(line)
  local ok, node = pcall(vim.treesitter.get_node, {
    bufnr = 0,
    pos = { line - 1, 0 },
  })
  if not ok or not node then return false end
  while node do
    if node:type() == 'pipe_table' then return true end
    node = node:parent()
  end
  return false
end

local renderer_namespace = renderer_available
  and require('render-markdown.core.ui').ns

local function line_is_hidden(line)
  if line_is_pipe_table(line) or not renderer_namespace then return false end
  local marks = vim.api.nvim_buf_get_extmarks(
    0,
    renderer_namespace,
    { line - 1, 0 },
    { line - 1, -1 },
    { details = true }
  )
  for _, mark in ipairs(marks) do
    if mark[4].conceal_lines ~= nil then return true end
  end
  return false
end

local function move_visible(direction)
  if vim.b.markdown_om ~= 'reading' then
    vim.cmd.normal({ args = { vim.v.count1 .. direction }, bang = true })
    return
  end

  local remaining = vim.v.count1
  while remaining > 0 do
    local before = vim.api.nvim_win_get_cursor(0)[1]
    vim.cmd.normal({ args = { direction }, bang = true })
    local current = vim.api.nvim_win_get_cursor(0)[1]
    if current == before then return end
    if not line_is_hidden(current) then remaining = remaining - 1 end
  end
end

vim.keymap.set(
  'n',
  'j',
  function() move_visible('j') end,
  { buffer = 0, desc = 'Next visible Markdown line' }
)
vim.keymap.set(
  'n',
  'k',
  function() move_visible('k') end,
  { buffer = 0, desc = 'Previous visible Markdown line' }
)

local function renderer_set(enabled) require('render-markdown').set_buf(enabled) end

-- HACK: render-markdown.nvim 640a3ec6 caches `anti_conceal` per buffer but has
-- no public per-buffer override. Reading alone must keep its extmarks on the
-- cursor line, so change that cache before the renderer refreshes. Delete this
-- when the plugin exposes a per-buffer anti-conceal API.
local function set_anti_conceal(enabled)
  require('render-markdown.state').get(vim.api.nvim_get_current_buf()).anti_conceal.enabled =
    enabled
end

local function set_state(state)
  vim.b.markdown_om = state
  set_anti_conceal(state ~= 'reading')
  if state == 'source' then
    renderer_set(false)
    restore()
    return
  end

  vim.bo.readonly = false
  vim.bo.modifiable = true
  renderer_set(true)
  if state == 'reading' then
    vim.bo.modifiable = false
    vim.bo.readonly = true
  end
end

vim.keymap.set('n', '<Leader>om', function()
  if not renderer_available then
    vim.notify(
      'render-markdown.nvim is unavailable; run :checkhealth config',
      vim.log.levels.ERROR
    )
    return
  end
  local next_state = ({ source = 'live', live = 'reading', reading = 'source' })[vim.b.markdown_om]
  set_state(next_state or 'source')
end, { buffer = 0, desc = 'Toggle Markdown source/live/reading' })

vim.b.markdown_om_cleanup = function()
  vim.b.markdown_om = 'source'
  if renderer_available then
    set_anti_conceal(true)
    renderer_set(false)
  end
  restore()
  vim.keymap.del('n', '<Leader>om', { buffer = 0 })
  vim.keymap.del('n', 'j', { buffer = 0 })
  vim.keymap.del('n', 'k', { buffer = 0 })
  vim.b.markdown_om = nil
  vim.b.markdown_om_original = nil
  vim.b.markdown_om_cleanup = nil
end

-- `b:undo_ftplugin` is run when the filetype changes (`:h b:undo_ftplugin`).
-- Cleanup explicitly restores the captured per-buffer/per-window options, so
-- reading mode cannot strand a buffer readonly or nonmodifiable.
vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n'
  .. table.concat({
    'setlocal spell< wrap< foldmethod< foldexpr<',
    'lua vim.b.markdown_om_cleanup()',
    'lua vim.b.minisurround_config = nil',
  }, ' | ')
