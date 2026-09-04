; extends
;
; A component can carry its template and its styles inline, in the `@Component`
; decorator, instead of pointing at a '.html' and a '.css' next to it. Those are
; the same markup and the same stylesheet — the Angular compiler reads them as
; such and reports errors at a line and column inside the backticks — but to the
; TypeScript parser they are one long string, and they render as one flat colour.
;
; The `angular` parser is in `languages` in 'plugin/40_plugins.lua', and so are
; `css` and `scss`; without them these patterns match and render nothing, in
; silence.
;
; `#offset!` is what makes the whole `template_string` usable as the content: it
; trims one character from each end so the backticks stay with TypeScript
; instead of being handed to the other parser as markup. Capturing the
; `(string_fragment)` inside would look simpler and be wrong — a template with a
; `${}` in it has several fragments, and each would be parsed on its own, so a
; tag opened before the substitution and closed after it would never match.

((pair
  key: (property_identifier) @_key
  value: (template_string) @injection.content)
  (#eq? @_key "template")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "angular"))

; `styles` takes an array in current Angular and took a bare string in older
; code, so both shapes are listed. The language is `css`: a component's inline
; styles are compiled as plain CSS even in a project whose files are '.scss'.
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
