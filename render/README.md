# render/ — Pass 2

Content-agnostic render stack. Everything draws without binary assets
(procedural textures from `proc.lua`).

## System links

```
init.lua (facade) ── builds ──> viewport, camera, lights, particles, postfx
                   ── feeds ──> pipeline
pipeline.lua ──uses──> viewport (all stages), camera (world+light stages),
                       lights (stage 2), postfx (stage 4)
particles.lua ──uses──> proc (glow texture)         lights.lua ──uses──> proc
camera:getView() ──feeds──> cull.lua
```

## Stage order (pipeline.draw)

1. world layers -> world canvas (camera space)
2. point lights -> light canvas (camera space, additive over ambient)
3. world x light multiply-composite -> out canvas
4. postfx reads out, writes the real screen (off / low / high)
5. HUD layers, logical space, after postfx (never receives world effects)

Games add layers with `pipeline:addLayer(name, fn, order)` and HUDs with
`addHud`. Lower `order` draws first.

## Modules

- **viewport** — logical res + letterbox + optional integer scale;
  `toLogical`/`getMouse` for picking.
- **camera** — `follow` (exp smoothing), world-bounds clamp, `setZoom`,
  `shake(strength, dur)` (30 Hz punches, max-accumulated, `shakeScale = 0`
  disables entirely), `toWorld`, `getView`.
- **cull** — `point/rect/circle` vs a view rect.
- **pipeline** — canvas set (world/light/out), resize + graphics-reset paths.
- **postfx** — shader chain, pcall-wrapped, degrades to plain draw on failure.
  `invalidate()` after any `love.window.setMode` (shaders die with the device).
- **light** — `add(x, y, radius, r, g, b, strength, ttl)`, rebuilt-per-frame
  friendly (`clear()` + re-add in scene update).
- **particles** — `registerPreset(name, cfg)`, `emit(name, x, y)`,
  `setQuality("off|low|medium|high")`, budget-capped, batched by
  (preset, color, alpha level); color behavior probed at runtime.
- **proc** — procedural texture painters + `cachedCanvas` dirty-flag helper.
- **text** — per-character drop-in animated text.
