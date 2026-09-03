# Packaging a `.love`

A `.love` file is a zip of the game root that LÖVE can run directly
(`lovec game.love`, or double-click on Windows). `tools/package.bat` builds
one — and it exists because two subtle things go wrong with naive zipping:

1. **Allowlist staging.** The build stages only folders/files that ship, so a
   shipped build cannot accidentally contain tests or tooling.
2. **Forward-slash zip entries.** `Compress-Archive` and friends write
   backslash entries that LÖVE cannot read; the script zips via .NET's
   `ZipFile` with entries normalized to `/`.

## Usage

From the repo:

```bat
tools\package.bat                       REM → love2d-studio.love at the repo root
tools\package.bat out.love              REM explicit output path
tools\package.bat out.love C:\path\to\game   REM package an embedded game
```

Verify the result by booting it: `lovec out.love`.

## The allowlist

The staged set is explicit at the top of the script:

- Folders: `core render save audio ui editor content sample tools template`
- Root files: `init.lua main.lua conf.lua demo.lua play.lua archetypes.lua version.lua`

**When your game embeds the studio, extend the list** with your own folders
(e.g. your `scenes`, `assets`, plus any extra root `.lua` files) by editing
the `for %%D in (…)` / `for %%F in (…)` lines in `tools/package.bat`. Anything
not listed is excluded by construction — that is the point.

Note the script is a `.bat` with parenthesized blocks — it must keep CRLF
line endings (cmd.exe misparses LF-only batch files).

## Release checklist

1. Bump `version.lua` (single source of truth — window title, console
   `version`, and `S._VERSION` all read it).
2. `run-tests.bat` green; `lovec . --audit` report PASS on every scene.
3. Package, then boot the `.love` standalone.
4. Ship `out.love` (players need LÖVE installed) or wrap it per-platform with
   a fused LÖVE executable if you want a double-clickable binary.
