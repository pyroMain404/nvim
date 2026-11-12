-- ┌────────────────────────────────┐
-- │ Angular templates are not HTML │
-- └────────────────────────────────┘
--
-- Upstream detects `htmlangular` only from content in the first 40 lines.
-- '$VIMRUNTIME/lua/vim/filetype/detect.lua' disables the name rule with a comment (vim/vim#13594).
-- Add the name rule inside an Angular project because a bindings-only template stays `html`.
vim.filetype.add({
  pattern = {
    -- Return `nil` to continue detection without affecting other projects.
    -- Use the same root markers as `angularls` (`:h vim.fs.root()`).
    ['.*%.component%.html'] = function(path, _)
      if vim.fs.root(path, { 'angular.json', 'nx.json' }) ~= nil then
        return 'htmlangular'
      end
    end,
  },
})
