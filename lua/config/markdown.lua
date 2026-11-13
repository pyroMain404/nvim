-- ┌─────────────────────────┐
-- │ Markdown buffer modes   │
-- └─────────────────────────┘
-- This module manages source/live/reading states with render-markdown.nvim and buffer-local mini.*
-- settings.
-- 'after/ftplugin/markdown.lua' calls it.

local M = {}

local renderer_available = #vim.api.nvim_get_runtime_file(
  'lua/render-markdown/init.lua',
  false
) > 0

local function restore()
  local saved = vim.b.markdown_om_original
  vim.bo.readonly = saved.readonly
  vim.bo.modifiable = saved.modifiable
  -- `b:` variables store dictionary keys as strings, including window ids.
  for key, options in pairs(saved.windows) do
    local win = tonumber(key)
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].conceallevel = options.conceallevel
      vim.wo[win].concealcursor = options.concealcursor
    end
  end
end

-- HACK: render-markdown.nvim 9c235be exposes hidden lines only through its private extmark
-- namespace.
-- It does not identify which feature conceals them.
-- Reading requires `j`/`k` to skip concealed fence delimiters but visit every pipe-table source
-- row.
-- Delete this when the plugin offers a visible-line motion (render-markdown.nvim 9c235be,
-- locked 2026-11-11, not retested).
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

local function line_is_hidden(line)
  if line_is_pipe_table(line) or not renderer_available then return false end
  local marks = vim.api.nvim_buf_get_extmarks(
    0,
    require('render-markdown.core.ui').ns,
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
  local motion = 'g' .. direction
  if vim.b.markdown_om ~= 'reading' then
    vim.cmd.normal({ args = { vim.v.count1 .. motion }, bang = true })
    return
  end

  local remaining = vim.v.count1
  while remaining > 0 do
    local before = vim.api.nvim_win_get_cursor(0)
    vim.cmd.normal({ args = { motion }, bang = true })
    local current = vim.api.nvim_win_get_cursor(0)
    if vim.deep_equal(current, before) then return end
    -- `gj` counts concealed text cells, so long concealed lines have rows that the renderer never
    -- draws.
    -- On these rows, `skip_hidden()` moves the cursor back, and `j` cannot leave the line.
    -- Move to the next line instead.
    if direction == 'j' and current[1] == before[1] then
      require('config.mdlink').skip_hidden(before[2] + 1)
      if vim.api.nvim_win_get_cursor(0)[2] < current[2] then
        vim.api.nvim_win_set_cursor(0, before)
        vim.cmd.normal({ args = { 'j' }, bang = true })
      end
      current = vim.api.nvim_win_get_cursor(0)
      if vim.deep_equal(current, before) then return end
    end
    if not line_is_hidden(current[1]) then remaining = remaining - 1 end
  end
end

local function renderer_set(enabled) require('render-markdown').set_buf(enabled) end

-- HACK: render-markdown.nvim 9c235be caches `anti_conceal` per buffer without a public per-buffer
-- override.
-- Only reading must keep extmarks on the cursor line. Change the cache before the renderer
-- refreshes.
-- Delete this when the plugin exposes a per-buffer anti-conceal API (render-markdown.nvim 9c235be,
-- locked 2026-11-11, not retested).
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

local function guard()
  if renderer_available then return true end
  vim.notify(
    'render-markdown.nvim is unavailable; run :checkhealth config',
    vim.log.levels.ERROR
  )
end

-- Neovim includes concealed link destinations when sizing wrapped lines
-- (`:h nvim_win_text_height()`).
-- Thus, a link that fits after concealment still leaves empty rows. No option changes this
-- behavior.
-- We cannot shorten the source text. Show the float without 'wrap' and fit it to its lines.
local function unwrap_if_concealed(buf, win)
  local width = vim.api.nvim_win_get_width(win) - vim.fn.getwininfo(win)[1].textoff
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local shown = line:gsub('(%b[]%()[^)]*(%))', '%1%2')
    if
      vim.fn.strdisplaywidth(line) > width
      and vim.fn.strdisplaywidth(shown) <= width
    then
      vim.wo[win][0].wrap = false
      local height = vim.api.nvim_win_text_height(win, {}).all
      vim.api.nvim_win_set_height(
        win,
        math.min(height, vim.api.nvim_win_get_height(win))
      )
      return
    end
  end
end

-- Attach to buffer `buf` in `live` state, or `reading` for a float such as the LSP hover from `K`.
-- `b:markdown_om_start` overrides both defaults.
function M.attach(buf)
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
  vim.api.nvim_buf_call(buf, function()
    vim.b.minisurround_config = {
      custom_surroundings = {
        L = {
          input = { '%[().-()%]%(.-%)' },
          output = function()
            local link = require('mini.surround').user_input('Link: ')
            return { left = '[', right = '](' .. link .. ')' }
          end,
        },
      },
    }

    -- NOTE: This pattern has no syntax awareness, so it also matches `^word` at code-fence line
    -- ends.
    -- The `§` also appears in `source` and code. Only the first `#` of a link appears.
    vim.b.minihipatterns_config = {
      highlighters = {
        block_id = {
          pattern = { '^()%^[%w%-]+()%s*$', '%s()%^[%w%-]+()%s*$' },
          group = 'Comment',
        },
        section_sign = {
          pattern = '%[%[[^%]|#]-()#()',
          group = '',
          extmark_opts = {
            virt_text = { { '§', 'RenderMarkdownWikiLink' } },
            virt_text_pos = 'overlay',
            hl_mode = 'combine',
          },
        },
      },
    }

    -- Prose uses unpaired `(`, `[`, `"` and `*` as often as paired characters.
    vim.b.minipairs_disable = true

    local original = vim.b.markdown_om_original
    if not original then
      original = {
        modifiable = vim.bo.modifiable,
        readonly = vim.bo.readonly,
        windows = {},
      }
      for _, win in ipairs(vim.fn.getbufinfo(buf)[1].windows or {}) do
        -- The code uses string keys. A table keyed by window id would become a sparse list.
        original.windows[tostring(win)] = {
          conceallevel = vim.wo[win][0].conceallevel,
          concealcursor = vim.wo[win][0].concealcursor,
        }
      end
      vim.b.markdown_om_original = original
    end

    vim.b.markdown_om = 'source'

    vim.keymap.set(
      'n',
      'j',
      function() move_visible('j') end,
      { buf = buf, desc = 'Next visible Markdown line' }
    )
    vim.keymap.set(
      'n',
      'k',
      function() move_visible('k') end,
      { buf = buf, desc = 'Previous visible Markdown line' }
    )

    -- Reading also conceals the cursor line. Move the cursor off concealed text.
    local cursor_group =
      vim.api.nvim_create_augroup('MarkdownReadingCursor', { clear = false })
    vim.api.nvim_clear_autocmds({ group = cursor_group, buffer = buf })
    local prev_col = 0
    vim.api.nvim_create_autocmd('CursorMoved', {
      group = cursor_group,
      buffer = buf,
      callback = function()
        if vim.b.markdown_om == 'reading' then
          require('config.mdlink').skip_hidden(prev_col)
        end
        prev_col = vim.fn.col('.')
      end,
    })

    -- NOTE: render-markdown attaches in its `FileType` autocmd after the ftplugin.
    -- Schedule `set_buf()` because it ignores unattached buffers.
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then return end
      vim.api.nvim_buf_call(buf, function()
        local win = vim.fn.win_findbuf(buf)[1]
        local floating = win and vim.api.nvim_win_get_config(win).relative ~= ''
        if floating then
          vim.wo[win][0].spell = false
          unwrap_if_concealed(buf, win)
        end
        if renderer_available then
          set_state(vim.b.markdown_om_start or (floating and 'reading' or 'live'))
        end
      end)
    end)

    vim.keymap.set('n', '<Leader>om', function()
      if guard() then
        set_state(vim.b.markdown_om == 'live' and 'source' or 'live')
      end
    end, { buf = buf, desc = 'Toggle Markdown source/live' })

    vim.keymap.set('n', '<Leader>oM', function()
      if guard() then
        set_state(vim.b.markdown_om == 'reading' and 'live' or 'reading')
      end
    end, { buf = buf, desc = 'Toggle Markdown reading' })
  end)
end

-- Undo `attach` for the current buffer from `b:undo_ftplugin`.
function M.detach()
  if renderer_available and vim.b.markdown_om then
    set_anti_conceal(true)
    renderer_set(false)
  end
  if vim.b.markdown_om_original then restore() end
  for _, lhs in ipairs({ '<Leader>om', '<Leader>oM', 'j', 'k' }) do
    pcall(vim.keymap.del, 'n', lhs, { buf = 0 })
  end
  pcall(vim.api.nvim_clear_autocmds, { group = 'MarkdownReadingCursor', buffer = 0 })
  vim.b.minihipatterns_config = nil
  vim.b.minipairs_disable = nil
  vim.b.markdown_om = nil
  vim.b.markdown_om_original = nil
end

return M
