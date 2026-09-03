# ui/ — UI kit + tweens

The layer every audited project was missing (they hand-rolled bars, buttons
and hit tests — the source of god-files).

## System links

```
init.lua (widgets) ──standalone (love.graphics/love.mouse for input state)
tween.lua ──standalone
demo.lua's settings overlay is the reference consumer (focus nav included)
```

## init.lua — `ui.new{theme, font, width, height}`

- **Per frame**: `beginFrame(mx, my, down, wheelY, confirm)` once, then draw
  widgets. `confirm` drives the FOCUSED widget (keyboard/gamepad navigation:
  `moveFocus(±1)` from input actions; see demo.lua's settings overlay).
- **Widgets**: `panel`, `label` (left/center/right align), `button`,
  `slider`, `toggle`, `list` (wheel + focus scrolling) — immediate mode,
  ids for state.
- **Helpers**: `tooltip(text)` near the mouse, `toast(text, opts)` queue
  (max 5, aged in `update(dt)`, drawn via `drawToasts(x, y)`), modal
  `pushOverlay/popOverlay/topOverlay`, `registerFocus/moveFocus/focusedId`.
- **Theme**: `applyTheme(target, overrides)` over the default palette.

## tween.lua — `tween.new()` + module default

`to(obj, {prop=target}, dur, {ease, delay, onDone})`, `cancel(handle)`,
`update(dt)`; eases: linear/smoothstep/easeInCubic/easeOutCubic.

Known gaps (fix.md): no textfield, dropdown, scrollable panel, 9-slice,
color picker. String props in the editor inspector are display-only until
`ui.textfield` lands.
