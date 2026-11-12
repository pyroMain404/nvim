; extends
;
; A component can include its template and styles in the `@Component` decorator instead of
; referencing adjacent '.html' and '.css' files.
; The Angular compiler reads the same markup and stylesheet, and reports errors at line and column
; positions inside the backticks.
; The TypeScript parser sees one long string and shows it in one colour.
;
; `languages` in 'plugin/40_plugins.lua' includes the `angular`, `css`, and `scss` parsers.
; Without them, these patterns match but silently render nothing.
;
; `#offset!` removes one character from each end of `template_string` to use the full string as
; content.
; The backticks stay with TypeScript instead of becoming markup for the other parser.
; Do not capture the inner `(string_fragment)`.
; A template with `${}` contains multiple fragments, which the parser would read separately.
; A tag that opens before the substitution and closes after it would not match.

((pair
  key: (property_identifier) @_key
  value: (template_string) @injection.content)
  (#eq? @_key "template")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "angular"))

; Current Angular takes an array for `styles`; older code took a bare string, so these patterns
; include both forms.
; The language is `css`: Angular compiles inline component styles as plain CSS even when the
; project uses '.scss' files.
((pair
  key: (property_identifier) @_key
  value: (array
    (template_string) @injection.content))
  (#eq? @_key "styles")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "css"))

((pair
  key: (property_identifier) @_key
  value: (template_string) @injection.content)
  (#eq? @_key "styles")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "css"))
