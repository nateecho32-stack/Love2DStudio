# editor/ — the scene editor

Open with `--editor`, or E from the demo. Esc pops back (or quits at root).

## Layout

- Top toolbar: Tool (Select/Place/Paint), Save, snap size, grid, undo, redo,
  Play (F5), Make Prefab; scene-name textfield top-right.
- Left: archetype palette (Place) or tileset picker (Paint).
- Right: hierarchy list + **undo history panel** (click a label to jump).
- Bottom-right: inspector — name textfield, x/y/rot/scale readout, and
  schema-driven fields (sliders, toggles, enum cycles, string textfields).
- World: click select, shift-click multi, drag on empty space = marquee,
  drag items = group move (snapped), right-click delete, middle-drag pan,
  wheel zoom-to-mouse. Q/E rotate, `[`/`]` scale, ctrl+C/V clipboard,
  ctrl+D duplicate, ctrl+A select all, Delete deletes the selection.
- Paint tool: LMB paints the chosen tile, RMB erases; every tile is a command
  (undoable). Tiles persist in the scene file and render in play mode.

## Prefabs

Select an entity (optionally name it via the inspector name field) →
Make Prefab stores `{base, props}` in `scenes/prefabs.lua` and adds it to the
palette (purple tint). Placing a prefab spawns the base archetype with the
prefab's props — per-instance edits are just prop overrides on the item.

## Model vs scene

The editor edits plain item lists (the Pass 5 scene-data model: entities +
tiles). A runtime ecs is only built when the scene is PLAYED (F5 / --play).

## Save location (LÖVE constraint)

`Save` writes through `love.filesystem`, so scene files land in the game's SAVE
directory (`%APPDATA%/LOVE/<identity>/scenes/...`), not the project folder.
Copy files out of the save dir when they should live in the repo (Trippy's
promote-step pattern).

## System links

```
init.lua (scene) ──uses──> model.lua (pure: commands/history, pick/pickAll/
                           boxSelect, copyItems, snap, serializeTable)
                  ──uses──> S.ui (widgets + textfields), S.render, S.scenedata,
                           S.thumbnail, S.tablex, S.log, S.bus (graphics.reset)
archetypes passed in via editor.new{ archetypes = ... } (see archetypes.lua
and sample/archetypes.lua)
```

