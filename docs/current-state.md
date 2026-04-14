# Current State — Phonetics Maestro

## Purpose

This document describes what the repository currently does today.

Read this before old handoff notes or historical phase plans. Use `requirements.md` for product intent, not for current implementation status.

## Current Development Mode

V1 Phase 1-4 implementation is complete. The repository is now in maintenance and extension mode:

- manual testing follow-up
- bug fixing
- small feature additions
- workflow and documentation refinement

New sessions should assume there is already a runnable baseline and should not treat the project as an uninitialized skeleton.

## Runtime Entry Points

### GUI

- Open the Xcode project:
  - `open PhoneticsMaestro.xcodeproj`
- Run scheme:
  - `PhoneticsMaestroApp`
- Destination:
  - `My Mac`

This is the normal path for humans testing the app.

### CLI

Available commands:

```bash
swift run phoneticsctl --gui
swift run phoneticsctl --headless seed-check
swift run phoneticsctl --headless db-summary
swift run phoneticsctl --headless smoke-test
```

Recommended uses:

- `--gui`: launch path for CLI-driven local development
- `--headless seed-check`: verify seed resources and import path
- `--headless smoke-test`: verify the baseline data and query path
- `--headless db-summary`: inspect current local data state

## Standard Verification Chain

Run this before opening or updating a PR:

```bash
swift build
swift test
swift run phoneticsctl --headless seed-check
swift run phoneticsctl --headless smoke-test
```

`db-summary` is diagnostic and useful during debugging, but it is not part of the required pass/fail chain.

## Current Architecture Shape

The project has three runtime pieces:

1. `PhoneticsMaestroApp`
   standard macOS app host with bundle metadata and privacy usage descriptions
2. `PhoneticsCore`
   shared UI, view model, service, model, and resource logic
3. `phoneticsctl`
   companion CLI that launches the GUI host or runs headless acceptance commands

Important implication:

- do not describe this repo as "a Swift Package app" anymore
- it is a shared Swift package plus a real macOS app host

## Current User-Facing Functionality

### Welcome / Navigation

- sidebar navigation for `Begin`, `History`, and `Settings`
- collapsible sidebar
- toolbar sidebar toggle with `⌘+\`

### Training

- minimal-pair card with text and IPA for left/right targets
- perception flow:
  - `Random Test`
  - left/right answer buttons
  - correct and incorrect feedback states
  - incorrect answer replays the correct standard sound
- practice flow:
  - record toggle
  - standard playback
  - user-recording playback
  - ABAB loop playback
- tagging:
  - `Save`
  - `Hard`
- per-card session stats:
  - `LISTENS`
  - `CORRECT`
  - `PRACTICES`
  - `TIME`
- navigation:
  - previous card
  - next card
  - reload
- shortcuts:
  - `←` / `→`
  - `Space`
  - `R`

### History

- session summary list
- per-session totals for time, listens/correct, and practices
- empty state and load/error handling

### Settings

- preferred TTS voice
- preferred microphone
- ABAB interval slider
- local persistence via `DataService`

## Current Data And Storage Behavior

- bundled seed data lives in:
  - `PhoneticsMaestro/Resources/SeedData/seed-phonemes.json`
  - `PhoneticsMaestro/Resources/SeedData/seed-sentences.json`
- first-run initialization imports bundled seed data into SQLite
- SQLite database path:
  - `~/Library/Application Support/PhoneticsMaestro/maestro.sqlite`
- recordings path:
  - `~/Library/Application Support/PhoneticsMaestro/recordings/`

## Headless Acceptance Coverage

Headless commands currently validate:

- database initialization
- seed import availability
- pair and sentence counts
- at least one training pair can load
- settings query path
- history query path

Headless commands do **not** currently validate:

- real microphone permissions
- real recording hardware behavior
- real TTS playback behavior
- full GUI interactions

## Known Limits And Non-Goals

- no network calls
- no V2 CLI data-generation pipeline
- no GUI automation layer in the repository
- `phoneticsctl --gui` still depends on current app-bundle discovery behavior described in the latest handoff
- historical handoff notes may mention old phase sequencing; use this file and `AGENTS.md` as the baseline instead

## Files New Sessions Usually Need

- `AGENTS.md`
  project rules and workflow
- `docs/current-state.md`
  current baseline
- `ARCHITECTURE.md`
  runtime structure and system boundaries
- latest `docs/handoff-*.md`
  recent deltas only
- `requirements.md`
  product intent and future scope

## When To Update This File

Update this file when any of the following changes:

- user-visible functionality
- runtime entry points
- standard verification chain
- major architecture shape
- key known limits that would affect a new session's assumptions
