-- ┌────────────────────────────────┐
-- │ Angular templates are not HTML │
-- └────────────────────────────────┘
--
-- Upstream detects `htmlangular` only from content in the first 40 lines.
-- '$VIMRUNTIME/lua/vim/filetype/detect.lua' disables the name rule with a comment (vim/vim#13594).
-- Add the name rule inside an Angular project because a bindings-only template stays `html`.
vim.filetype.add({
  pattern = {
    -- The function returns `nil` outside an Angular project,
    -- so detection continues and other projects are unaffected.
    -- The root markers are the markers that `angularls` uses (`:h vim.fs.root()`).
    ['.*%.component%.html'] = function(path, _)
      if vim.fs.root(path, { 'angular.json', 'nx.json' }) ~= nil then
        return 'htmlangular'
      end
    end,
  },
})
