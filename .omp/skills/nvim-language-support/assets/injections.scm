; extends
;
; Use this template for 'after/queries/<lang>/injections.scm'.
; Use the same structure for 'highlights.scm', 'folds.scm' and 'textobjects.scm'.
;
; Keep `; extends` on the first line (:h treesitter-query-modeline-extends).
; It adds these patterns to the language query from 'nvim-treesitter'.
; Without it, this file replaces that query and removes all its injections or highlights
; without an error or message.
; This missing line commonly breaks language support that worked before.
;
; First, check if the parser already supports the case.
; Use :InspectTree to see the tree.
; Use :Inspect to see the capture and highlight group under the cursor.
; Use :EditQuery to write a query and see its matches.
;
; Injections render one language inside another, such as SQL in a query macro,
; regular expressions in strings,
; or markdown in documentation comments.
; The fixed capture name @injection.content selects the text to parse.
; Set the language with #set!, or get it dynamically from a captured node
; (:h treesitter-language-injections).
;
; Add the injected language to the `languages` table because it needs its own installed parser.
; Without that parser, the injection matches but renders nothing and gives no message.
;
; Write the pattern from the tree, not from memory.
; Use :InspectTree to see the tree, or `node:sexpr()` to print the exact structure of one node.
; The example below needed three corrections that error messages did not identify.
; A scoped call uses `scoped_identifier`, not `identifier`.
; `string_literal` passes quotes to the other parser, but `string_content` does not.
; Without the `.` anchor, the query also parses a second string argument as SQL.

; Static language: the macro always contains SQL, so set the language directly.
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

; This dynamic language rule gets the language from a fenced block.
; ((fenced_code_block
;    (info_string) @injection.language
;    (code_fence_content) @injection.content))
