# fix.md — open issues only

Once an issue below is fixed, REMOVE its entry — the goal is a clean slate.

## Open

- Editor rotation-aware picking: selection hit-tests use axis-aligned bounds,
  so heavily rotated items select by their unrotated rect. Fine at editor
  zooms; rotate the test point if it ever bites.
- Editor string props write into raw scene data; `core.entities:validate`
  still drops unknown props at PLAY time (schema-strings like `goblin.name`
  need a schema entry to survive into gameplay).

## Fixed (removed on fix — keep the log clean)

(Resolved during the completion campaign: editor string-prop text input —
ui.textfield landed with love.textinput routing; list/palette wheel conflict —
each list scrolls only while hovered; particles color-probe flash risk —
probe runs once at first draw, cached thereafter.)
