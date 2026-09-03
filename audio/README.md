# audio/ — Pass 3

Audio manager + procedural synth (games can ship with zero audio files).

## System links

```
init.lua (manager: buses, resolver, play/playMusic) ──uses──> synth.lua
games inject fs={exists} + newSource for headless tests
```

- **init** — `audio.new{dirs, clipGain, buses, fs, newSource, random}`.
  Resolution: `<dir>/<family>/<name>` with ext priority `.ogg .mp3 .wav .flac`,
  variants `_2.._4` (existing ones are played via the base path), then
  `<family>/_default`, then `<dir>/_default`. Unresolved = nil (synth fallback
  contract). `play(name, {volume, pitch, pitchVariance, bus})`,
  `playMusic` (streams, loops, swaps), `setBusVolume(master/music/sfx/ambient)`,
  `clipGain[name]` makeup gain for AI-generated loudness variance.
- **synth** — `toneData/tone(freq, dur, {kind, vol, sweepTo, attack, release})`
  with sine/square/saw/triangle/noise + envelopes; `build(seconds, fn)` renders
  any shape (Burning's escape hatch).
