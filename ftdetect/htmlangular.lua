-- ┌────────────────────────────────┐
-- │ Angular templates are not HTML │
-- └────────────────────────────────┘
--
-- Upstream detects `htmlangular` only by content (first 40 lines); the name rule
-- is commented out in '$VIMRUNTIME/lua/vim/filetype/detect.lua' (vim/vim#13594).
-- A bindings-only template stays `html`, so add the name rule inside an Angular project.
vim.filetype.add({
  pattern = {
    -- Returning `nil` lets detection continue, so other projects are unaffected.
    -- Markers are those `angularls` uses for its root (`:h vim.fs.root()`).
    ['.*%.component%.html'] = function(path, _)
      if vim.fs.root(path, { 'angular.json', 'nx.json' }) ~= nil then
        return 'htmlangular'
      end
    end,
  },
})
