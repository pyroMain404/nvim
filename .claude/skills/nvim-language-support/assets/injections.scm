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
;
; The injected language needs its own parser installed, so it belongs in the
; `languages` table too. Without it the injection matches and renders nothing, in
; silence.
;
; Write the pattern against the tree, not from memory: :InspectTree shows it, and
; `node:sexpr()` prints the exact shape of one node. The example below took three
; corrections that no error message would have pointed at — a scoped call is a
; `scoped_identifier` and not an `identifier`, `string_literal` hands the quotes to
; the other parser while `string_content` does not, and without the `.` anchor a
; second string argument is parsed as SQL as well.

; Static language: the macro always contains SQL.
((macro_invocation
   macro: [
     (identifier) @_name
     (scoped_identifier name: (identifier) @_name)
   ]
   (token_tree
     .
     (string_literal (string_content) @injection.content)))
 (#eq? @_name "query")
 (#set! injection.language "sql"))

; Dynamic language: a fenced block that names its own language.
; ((fenced_code_block
;    (info_string) @injection.language
;    (code_fence_content) @injection.content))
