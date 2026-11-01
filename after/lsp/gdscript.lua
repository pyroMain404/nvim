-- ┌────────────────────┐
-- │ GDScript via Godot │
-- └────────────────────┘
--
-- Served by the Godot editor while it has a project open. `root_markers` drops
-- the inherited '.git' so a loose '.gd' never attaches to another game's editor.
-- NOTE: `cmd` stays inherited (a function, replaced if set); two editors at once
-- are not handled: the second gets no port and attaches to the first.
return { root_markers = { 'project.godot' } }
