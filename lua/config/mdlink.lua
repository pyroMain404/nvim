-- ┌───────────────────────────┐
-- │ Markdown link for 'path'  │
-- └───────────────────────────┘
--
-- Required by name from 'after/ftplugin/markdown.lua', as its 'includeexpr'.
--
-- Everything that looks a name up through 'path' (`gf`, `gF`, `<C-w>f`, `[f`,
-- `:find`) takes the name from the text under the cursor and, when no file has
-- it, asks 'includeexpr' for another name (`:h 'includeexpr'`). In a
-- `[label](target)` link that name is wrong twice: on the label it is a word
-- of the label, and on the target it may carry a `#anchor`. The answer here is
-- the target of the link the cursor is in, without its anchor. The cursor
-- column is a byte column of the source text, so it is right in the rendered
-- (concealed) states of `<Leader>om` too.

local M = {}

-- Name for 'path' to look up: the target of the link covering the cursor, else
-- `fname` itself, in both cases without `#anchor`. `<...>` and a trailing title
-- are handled.
M.target = function(fname)
  local line, col = vim.api.nvim_get_current_line(), vim.fn.col('.')
  local init = 1
  while true do
    local s, e, target = line:find('%b[]%(%s*([^)]-)%s*%)', init)
    if not s then break end
    if col >= s and col <= e then
      target = target:match('^<([^>]*)>') or target:match('^(%S+)')
      if target then return (target:gsub('#.*$', '')) end
      break
    end
    init = e + 1
  end
  return (fname:gsub('#.*$', ''))
end

-- Move the cursor off the concealed `](target)` of the link it is in, so that
-- the reading state of `<Leader>om`, which keeps the cursor line concealed,
-- never parks it on text that is not drawn. Moving right lands after the link
-- (or on its label when the link ends the line), moving left on its label.
-- `prev` is the column the cursor came from.
M.skip_hidden = function(prev)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line, init = vim.api.nvim_get_current_line(), 1
  col = col + 1
  while true do
    local s, e = line:find('%b[]%(%s*[^)]-%s*%)', init)
    if not s then return end
    local close = s + #line:match('^%b[]', s) - 1
    if col >= close and col <= e then
      local to = (col >= prev and e < #line) and e + 1 or close - 1
      vim.api.nvim_win_set_cursor(0, { row, to - 1 })
      return
    end
    init = e + 1
  end
end

return M
