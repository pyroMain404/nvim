-- ┌────────────────────────────────┐
-- │ Angular templates are not HTML │
-- └────────────────────────────────┘
--
-- Neovim already knows the `htmlangular` filetype and ships a ftplugin and a
-- syntax file for it, but it only reaches them by reading the file: the rule in
-- '$VIMRUNTIME/lua/vim/filetype/detect.lua' looks at the first 40 lines for
-- `@if`, `*ngIf`, `<ng-template>` and friends. The rule by *name* is in that
-- same function, commented out on purpose (vim/vim#13594), because a
-- '*.component.html' outside Angular means nothing.
--
-- The consequence is that a template made of bindings only — `{{ title }}` in a
-- `<div>` — stays `html`. And `html` is not a smaller `htmlangular`: it is the
-- wrong answer. The `angular` tree-sitter parser declares the `htmlangular`
-- filetype, so highlighting falls back to plain HTML, and `angularls` sees an
-- ordinary web page.
--
-- What the upstream rule lacks is the context, and the context is a file: this
-- adds the name rule back, restricted to a project that really is an Angular
-- one. See `:h ftdetect`, `:h vim.filetype.add()`, `:h ft-html-plugin`.

vim.filetype.add({
  pattern = {
    -- A function value is what makes the rule answer "it depends": returning
    -- `nil` leaves detection to continue as if this rule did not exist, so a
    -- '*.component.html' in any other kind of project keeps behaving as before.
    --
    -- `vim.fs.root()` walks up from the file and stops at the first marker, and
    -- these are the two 'nvim-lspconfig' uses to find the root of `angularls`
    -- (`:h vim.fs.root()`). Running it here costs one walk per template opened,
    -- which is the same order of work filetype detection already does.
    ['.*%.component%.html'] = function(path, _)
      if vim.fs.root(path, { 'angular.json', 'nx.json' }) ~= nil then
        return 'htmlangular'
      end
    end,
  },
})
