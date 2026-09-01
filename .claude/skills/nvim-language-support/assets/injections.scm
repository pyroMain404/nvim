; extends
;
; Skeleton for 'after/queries/<lang>/injections.scm'. The same shape applies to
; 'highlights.scm', 'folds.scm' and 'textobjects.scm'.
;
; THE FIRST LINE IS THE FILE. `; extends` adds these patterns to the query that
; 'nvim-treesitter' already provides for this language (:h
; treesitter-query-modeline-extends). Without it this file REPLACES that query
; entirely, so every injection or highlight the plugin shipped disappears — with no
; error and no message. It is the single most common way to break a language that
; was working.
;
; Check first that the parser does not already cover the case: :InspectTree shows
; the tree, :Inspect the capture and highlight group under the cursor, and
; :EditQuery lets you write a query while watching what it matches.
;
; Injections make one language render inside another: SQL inside a query macro,
; regular expressions inside a string, markdown inside documentation comments. The
; capture names are fixed — @injection.content is the text to parse, and the
; language is named either statically with #set! or dynamically from a captured
; node (:h treesitter-language-injections).

; Static language: the macro always contains SQL.
((macro_invocation
   macro: (identifier) @_name
   (token_tree (string_literal) @injection.content))
 (#eq? @_name "query")
 (#set! injection.language "sql"))

; Dynamic language: a fenced block that names its own language.
; ((fenced_code_block
;    (info_string) @injection.language
;    (code_fence_content) @injection.content))
