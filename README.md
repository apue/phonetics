# Phonetics Maestro

Phonetics Maestro is a macOS pronunciation training app built around a perception -> production -> correction loop for English minimal pairs.

## Current Status

The V1 app is implemented and runnable today. Current development is no longer "build Phase 1-4 from scratch"; it is now iterative bug fixing, testing, and incremental feature work on top of the shipped baseline.

For the most accurate snapshot of the current app and workflow, read [docs/current-state.md](docs/current-state.md).

## Run The App

Best option for humans:

```bash
open PhoneticsMaestro.xcodeproj
```

Then run the `PhoneticsMaestroApp` scheme on `My Mac`.

CLI entry points:

```bash
swift run phoneticsctl --gui
swift run phoneticsctl --headless seed-check
swift run phoneticsctl --headless db-summary
swift run phoneticsctl --headless smoke-test
```

## Standard Verification Chain

```bash
swift build
swift test
swift run phoneticsctl --headless seed-check
swift run phoneticsctl --headless smoke-test
```

Useful diagnostic command:

```bash
swift run phoneticsctl --headless db-summary
```

## Project Map

- [AGENTS.md](AGENTS.md): agent workflow, coding rules, directory layout
- [docs/current-state.md](docs/current-state.md): current functionality, runtime shape, known limits
- [ARCHITECTURE.md](ARCHITECTURE.md): current application architecture
- [requirements.md](requirements.md): original V1 PRD and future reference scope
- [HANDOFF.md](HANDOFF.md): handoff protocol for agent-to-agent continuity

## For Agents

Start in this order:

1. Read [AGENTS.md](AGENTS.md).
2. Read [docs/current-state.md](docs/current-state.md).
3. Read the latest `docs/handoff-*.md` if present.
4. Read [ARCHITECTURE.md](ARCHITECTURE.md) if the task touches runtime structure.
5. Read [requirements.md](requirements.md) only as product intent and backlog context, not as an active "build from scratch" checklist.
