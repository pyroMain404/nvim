; extends
;
; The `sqlx` macros check their query against the database during crate compilation.
; Thus, the compiler reads the SQL as code.
; These patterns parse it as SQL instead of leaving it as a grey string in the editor.
;
; These patterns cover `sqlx::query!` and the bare `query!` from `use sqlx::query`.
; The `_as` family names a type first, so its string is the second call element instead of the
; first.
; The anchors prevent the parser from reading a second string argument as SQL.
;
; These patterns need the `sql` parser.
; Only this requirement puts it in `languages` in 'plugin/40_plugins.lua'.

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
