# DropVolley — Audio (SFX) library

Real tennis sound effects for the app's cues. `AudioManager` (`CourtIQ/Core/Services/AudioManager.swift`)
uses a **hybrid** source:

1. **Real sample** — if a matching file exists in the bundled `Audio/` folder, it plays.
   Multiple files for one cue → one is chosen **at random** each time (natural variety).
2. **Synth fallback** — if no file is present, an in-code synthesised "pock" plays instead.

So the app always makes sound, and dropping in real audio is just adding files — **no code change**
for cues that already exist.

## Where files go

`CourtIQ/Resources/Audio/` — a **folder reference** in the Xcode project, so any file you add is
bundled automatically (no pbxproj edit needed). Loaded at `Audio/<name>.<ext>` in the bundle.

**Formats:** `caf`, `wav`, `aif`, `aiff`, `m4a`, `mp3`. Mono or stereo — anything not mono/44.1 kHz is
auto-converted on load. Keep clips short (SFX are one-shots) and normalized (not clipping).

## Naming scheme

The base-names `AudioManager` looks for (see `SFX.fileCandidates`). Add the extension:

| Cue (SFX) | File base-name(s) | When it fires |
|---|---|---|
| `.ballHit` | `racket_hit_1` … `racket_hit_4` | a struck ball (ProShot animation, drill tap) — list several takes for variety |
| `.sweetSpot` | `sweet_spot` | swing / doubles score lands (synth is fine here) |
| `.correct` | `correct` | correct quiz answer / green drill decision |
| `.wrong` | `net_thud` | wrong answer / red decision ("into the net") |

To add **variety** to an existing cue, just add more files and extend that case's list in
`SFX.fileCandidates`. To add a **new** cue, add an enum case + its base-names, then call
`AudioManager.shared.play(.yourCase)` where it should fire.

### Umpire voice calls (planned)
Generated via TTS (no licensing) — base-names like `umpire_out`, `umpire_fault`, `umpire_let`,
`umpire_deuce`, `umpire_advantage`, `umpire_game`. Add the enum cases + a scoring surface that plays them.

## ⚠️ Licensing — READ BEFORE ADDING ANYTHING

This is a **commercial** App Store app. Only add audio that is **one of**:

- **CC0 / public domain** — best, no attribution. (Freesound: filter to CC0.)
- **Royalty-free, commercial use allowed, no attribution** — Pixabay, Mixkit, Sonniss GDC bundle.
- **CC-BY** — allowed, but **you must credit** the author (add a row to *Credits* below **and** surface
  it in-app under Settings/About).

**Never add:** CC-BY-**NC** (non-commercial), "personal/educational only" (e.g. BBC Sound Effects),
or anything whose license you haven't verified. When in doubt, leave it out.

### Vetted sources
- **Pixabay** — https://pixabay.com/sound-effects/search/tennis/ · commercial OK, no attribution
- **Mixkit** — https://mixkit.co/free-sound-effects/ · commercial OK, no attribution, no signup
- **Sonniss GDC bundle** — https://gdc.sonniss.com/ · royalty-free, commercial, no attribution
- **Freesound** — https://freesound.org/ · **per-sound** license, filter to CC0 (or CC-BY + credit).
  Racket takes: https://freesound.org/people/singintime/packs/10630/ (verify each sound's badge)
- Umpire calls — Pixabay `umpire`, Videvo `umpire`, or TTS-generated.

## Credits (CC-BY attributions)

Keep this in sync with anything CC-BY that ships. Empty = only CC0 / no-attribution assets in use.

| File | Author | Source URL | License |
|---|---|---|---|
| _(none yet)_ | | | |
