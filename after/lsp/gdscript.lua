-- ┌────────────────────┐
-- │ GDScript via Godot │
-- └────────────────────┘
--
-- The Godot editor supplies the server while a project is open.
-- `root_markers` removes the inherited '.git', so a separate '.gd' never attaches to another game's
-- editor.

-- NOTE: This file inherits `cmd`, which is a function; a new value would replace it.
-- This config does not handle two editors at once: the second gets no port and attaches to the first.
return { root_markers = { 'project.godot' } }
