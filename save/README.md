# save/ — Pass 3

Versioned save system with sidecar-per-system files.

## System links

```
init.lua (orchestrator) ──uses──> serialize.lua, migration.lua
thumbnail.lua ──standalone (one-shot LÖVE thread)──
games inject fs={read,write,remove,list} for headless tests (defaults to love.filesystem)
```

- **serialize** — plain tables -> loadable source; functions/userdata dropped;
  cycles and runaway depth drop; decode is sandboxed (`setfenv`) and rejects
  non-table roots.
- **migration** — `{version, data}` wrapper; ordered `from = n` steps; future
  versions refused (`unsupported_future_version`); steps may return a note
  (lost-content disclosure).
- **init** — `save.new{dir, version, migrations, fs}`: `write(system, data)` /
  `read(system)` (failure names the exact `.dat`), `exists/delete/systems`,
  `notes` after read; `AUTOSAVE_LADDER` + `nearestLadder` for settings UIs.
- **thumbnail** — `capture(captureFn, path)`: nearest-neighbor 320x180 downscale,
  PNG encoded in a one-shot thread; `poll()` surfaces worker errors.
