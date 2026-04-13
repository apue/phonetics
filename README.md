# Phonetics Maestro

A minimal, distraction-free macOS desktop app for deliberate pronunciation practice through Minimal Pair contrast training.

## For Humans

**What it does:** Helps language learners (especially Chinese speakers learning English) train their ears and mouths through a perception → production → correction loop.

**Tech stack:** Swift 5.9+, SwiftUI, AVFoundation, SQLite (via GRDB), macOS 14.0+.

**How to build:**

```bash
swift build
swift test
open Package.swift  # opens in Xcode
```

## For Agents: Bootstrap Sequence

If you are a coding agent (Claude Code, Codex, or other), follow these steps in order:

1. **Read `AGENTS.md`** — project conventions, directory layout, code style, build commands.
2. **Read `requirements.md`** — full product requirements document with schema, seed data spec, and implementation phases.
3. **Read `ARCHITECTURE.md`** — module diagram, state machine spec, data flow, JSON schemas.
4. **Read `HANDOFF.md`** — how to generate and consume handoff notes between sessions.
5. **Check `docs/handoff-*.md`** — if any exist, read the latest one and resume from there.
6. **If no handoff notes exist:** Begin Phase 1 (Skeleton) per `requirements.md §6`.

### Quick Start for Fresh Project

```
Initialize a Swift Package (macOS app target) named PhoneticsMaestro.
Set up the directory structure per AGENTS.md.
Add GRDB.swift as SPM dependency.
Create the SQLite schema per requirements.md §4.
Import seed data from Resources/SeedData/.
Build and verify the skeleton runs.
```

## Project Status

- [ ] Phase 1: Skeleton
- [ ] Phase 2: Audio Engine
- [ ] Phase 3: Training Card
- [ ] Phase 4: Polish
