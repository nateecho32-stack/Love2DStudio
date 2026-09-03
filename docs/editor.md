# Scene editor

The editor authors the same versioned scene files the runtime plays — the
Gem Haul levels are authored in it.

## Opening and leaving

- `lovec . --editor` (or `E` from the demo) opens the editor on
  `scenes/sandbox.lua`.
- **F5** plays the current scene file in play mode; **Esc** pops back to the
  editor (or quits at the root).
- The scene-name textfield (top right) names the file `Save` writes.

## Layout

| Region | Contents |
|---|---|
| Top toolbar | Tool (Select / Place / Paint), Save, snap size, grid toggle, undo, redo, Play (F5), Make Prefab |
| Left | Archetype palette (Place tool) or tileset picker (Paint tool) |
| Right | Hierarchy list + **undo history panel** (click a label to jump back in time) |
| Bottom-right | Inspector: entity name, x/y/rot/scale, schema-driven fields (sliders, toggles, enum cycles, text) |

## World controls

| Input | Action |
|---|---|
| Click | Select |
| Shift-click | Add to / remove from selection |
| Drag on empty space | Marquee box-select |
| **Ctrl+A** | Select all |
| Drag selection | Group move (snapped to the current snap size) |
| **Q / E** | Rotate selection |
| **[ / ]** | Scale selection |
| **Ctrl+C / Ctrl+V** | Copy / paste |
| **Ctrl+D** | Duplicate |
| **Delete** | Delete selection |
| Right-click | Delete under cursor |
| Middle-drag | Pan |
| Wheel | Zoom to mouse |

## Placing entities

Pick an archetype from the palette, then click to place. The archetype schemas
(live in the game's `archetypes.lua`) drive both the palette and the inspector
fields — new fields appear in the editor with no editor changes.

## Tile painting

Switch the toolbar to **Paint**: left button paints the selected tile, right
button erases. Every tile stroke is an undoable command. Tiles persist in the
scene file and render in play mode.

## Prefabs

Select an entity (optionally name it in the inspector) → **Make Prefab**
stores `{base, props}` in `scenes/prefabs.lua` and adds it to the palette
(purple tint). Placing a prefab spawns the base archetype with the prefab's
props; per-instance edits are just prop overrides.

## Saving — mind the save directory

`Save` writes through `love.filesystem`, so scene files land in the game's
**save directory** (`%APPDATA%\LOVE\<identity>\scenes\…` on Windows), not the
project folder. To keep a scene in the repo, copy it out of the save dir —
the "promote step". `--play scenes/<file>.lua` (or F5) plays it either way.

## Editor vs runtime

The editor edits plain item lists (entities + tiles). An ecs is only built
when a scene is *played* (F5 / `--play`), which keeps editing cheap and the
model trivially serializable.
