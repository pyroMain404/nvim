; extends
;
; The `sqlx` macros check their query against the database while the crate is
; compiled, so the SQL is real code that the compiler reads. In the editor it
; stays a grey string, and this parses it as SQL instead.
;
; Both spellings of the call are covered: `sqlx::query!` and the bare `query!`
; left by `use sqlx::query`. The `_as` family names a type first, so there the
; string is the second element of the call rather than the first, and the
; anchors are what keep a second string argument from being read as SQL too.
;
; Nothing here fires until the `sql` parser is installed; it is in `languages`
; in 'plugin/40_plugins.lua' for this reason alone.

((macro_invocation
  macro: [
    (identifier) @_name
    (scoped_identifier name: (identifier) @_name)
  ]
  (token_tree
    .
    (string_literal (string_content) @injection.content)))
  (#any-of? @_name
    "query" "query_unchecked"
    "query_scalar" "query_scalar_unchecked"
    "query_file" "query_file_unchecked")
  (#set! injection.language "sql"))

((macro_invocation
  macro: [
    (identifier) @_name
    (scoped_identifier name: (identifier) @_name)
  ]
  (token_tree
    .
    (identifier)
    .
    (string_literal (string_content) @injection.content)))
  (#any-of? @_name
    "query_as" "query_as_unchecked"
    "query_file_as" "query_file_as_unchecked")
  (#set! injection.language "sql"))
