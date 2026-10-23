; extends
;
; `[[note]]` is not a node: its outer brackets are tokens beside a
; `shortcut_link`, under any parent (`inline`, emphasis, ...); the anchors
; exclude a bare `[text]`. 'plugin/40_plugins.lua' defines the group.

(inline_link) @markup.link.underlined

(_
  "[" @markup.link.underlined
  .
  (shortcut_link) @markup.link.underlined
  .
  "]" @markup.link.underlined)
