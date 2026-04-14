# AGENTS.md — Phonetics Maestro

> This file is the **single source of truth** for all coding agents working on this project.
> Both Claude Code (CLAUDE.md → @AGENTS.md) and Codex read this file.

## Project Identity

- **Name:** Phonetics Maestro
- **Type:** macOS native desktop app (SwiftUI)
- **Target:** macOS 14.0+ (Sonoma)
- **Language:** Swift 5.9+ with strict concurrency
- **Full PRD:** `requirements.md`
- **Architecture:** `ARCHITECTURE.md`
- **Handoff protocol:** `HANDOFF.md`

## Directory Layout

```
PhoneticsMaestro/
├── PhoneticsMaestro/
│   ├── App/                    # App entry point, main window
│   ├── Views/                  # SwiftUI views, grouped by screen
│   │   ├── Welcome/
│   │   ├── Training/
│   │   ├── History/
│   │   └── Settings/
│   ├── ViewModels/             # @Observable view models
│   ├── Services/               # Actor-based services
│   │   ├── AudioService.swift  # singleton actor: TTS, record, playback, ABAB
│   │   └── DataService.swift   # singleton actor: SQLite CRUD
│   ├── Models/                 # Data models / DB row types
│   ├── Utils/                  # Extensions, helpers
│   └── Resources/
│       └── SeedData/           # seed-phonemes.json, seed-sentences.json
├── PhoneticsMaestroTests/
├── Package.swift               # SPM dependencies
└── Makefile                    # build / test / run shortcuts
```

## Build & Test Commands

```bash
# Standard verification chain
swift build
swift test
swift run phoneticsctl --headless seed-check
swift run phoneticsctl --headless smoke-test
# Open in Xcode
open Package.swift
# Format (if swift-format is installed)
swift-format format -i -r Sources/
```

## Code Conventions

### Swift Style
- Use `@Observable` macro (Observation framework). **Never** use `ObservableObject` / `@Published`.
- Use Swift Actors for service singletons (`AudioService`, `DataService`).
- Use `async/await` everywhere. No completion handlers, no Combine.
- Use `enum` for all finite states (audio state machine, navigation).
- Prefer value types (`struct`) over classes unless Actor or reference semantics required.
- One type per file. File name = type name.
- Max function body: 40 lines. Extract private helpers if longer.

### Naming
- Views: `TrainingCardView`, `WelcomeView`
- ViewModels: `TrainingCardViewModel`, `HistoryViewModel`
- Services: `AudioService`, `DataService`
- Models: `Word`, `PhonePair`, `Sentence`, `UserProgress`

### Error Handling
- Services throw typed errors: `AudioServiceError`, `DataServiceError`.
- ViewModels catch and expose errors via `@Observable` published error state.
- Views show errors via `.alert()`.

### Git
- One commit per logical change. Descriptive message in imperative mood.
- Branch naming: `feat/phase-N-description`, `fix/description`.

### GitHub Workflow (Required)
- After initial repository bootstrap, all implementation work must follow this workflow:
  1. Run local verification: `swift build`, `swift test`, `swift run phoneticsctl --headless seed-check`, and `swift run phoneticsctl --headless smoke-test`.
  2. Create or switch to a task branch from `main` using the branch naming rules above.
  3. Commit only the intended logical change.
  4. Push the branch to `origin`.
  5. Open a pull request.
  6. Wait for automated checks to complete and inspect failures with `gh` CLI if needed.
  7. Perform code review before merge, prioritizing bugs, regressions, edge cases, and missing tests.
  8. Address review comments on the same branch, re-run local verification, and push updates.
  9. Merge only after local checks pass, remote checks pass, review comments are addressed, and the user confirms.
- Prefer `gh` CLI for repository, PR, review, and Actions interactions.
- Do not merge directly to `main` without an explicit user request.
- When a task ends without merge, leave the branch pushed and the PR updated with the latest verified state.

## Architecture Rules

1. **Views never call Services directly.** Views → ViewModel → Service.
2. **AudioService is a singleton actor** with an explicit state machine. All state transitions go through a single `transition(to:)` method.
3. **DataService is a singleton actor** wrapping SQLite. Exposed via async methods returning model types.
4. **No network calls in V1.** If you find yourself importing URLSession, stop.
5. **Seed data flows one way:** Bundle JSON → `SeedDataImporter` → SQLite. The app never writes back to JSON.

## Implementation Priority

Follow the phases in `requirements.md §6` strictly:
1. **Phase 1** (Skeleton) must be fully complete and testable before starting Phase 2.
2. Within each phase, implement items top-to-bottom as listed.
3. After completing each phase, generate a handoff note per `HANDOFF.md` protocol.

## What NOT To Do

- Do NOT implement the CLI data pipeline (V2 feature).
- Do NOT add network/API calls.
- Do NOT use third-party UI frameworks (no AppKit bridging unless absolutely necessary for audio).
- Do NOT use `@StateObject`, `@ObservedObject`, `@EnvironmentObject` — use `@Observable` + `@State` / `@Environment`.
- Do NOT store recordings in the app bundle. Use `~/Library/Application Support/PhoneticsMaestro/recordings/`.
