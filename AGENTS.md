# AGENTS.md — Phonetics Maestro

> This file is the **single source of truth** for all coding agents working on this project.
> Both Claude Code (CLAUDE.md → @AGENTS.md) and Codex read this file.

## Project Identity

- **Name:** Phonetics Maestro
- **Type:** macOS native desktop app (SwiftUI)
- **Target:** macOS 14.0+ (Sonoma)
- **Language:** Swift 5.9+ with strict concurrency
- **Current state snapshot:** `docs/current-state.md`
- **Full PRD:** `requirements.md`
- **Architecture:** `ARCHITECTURE.md`
- **Handoff protocol:** `HANDOFF.md`

## Read This First

When starting a new session, read in this order:

1. `AGENTS.md`
2. `docs/current-state.md`
3. The latest `docs/handoff-*.md` file, if one exists and is relevant
4. `ARCHITECTURE.md` if the task touches runtime structure, data flow, or app/CLI entry points
5. `requirements.md` only as product intent and future-scope context, not as an active "build V1 from scratch" checklist

## Repo Map

Use this as a navigation aid, not as the full architecture reference. For detailed runtime structure and boundary rules, see `ARCHITECTURE.md`.

```
PhoneticsMaestro/
├── PhoneticsMaestro/                  # Shared PhoneticsCore code
│   ├── Views/                         # Screen UI, including Training/
│   ├── ViewModels/                    # Screen interaction logic
│   ├── Services/                      # Audio, data, headless acceptance, launch helpers
│   ├── Models/                        # Domain and UI state models
│   └── Resources/SeedData/            # Bundled seed JSON
├── PhoneticsMaestroApp/               # macOS app host, bundle metadata, GUI entry
├── PhoneticsCLI/                      # phoneticsctl CLI entry
├── PhoneticsMaestroTests/             # Unit and regression tests
├── docs/
│   ├── current-state.md               # Current implementation baseline
│   └── handoff-*.md                   # Session deltas
├── PhoneticsMaestro.xcodeproj         # Open this for GUI work
├── Package.swift                      # Shared package and targets
└── Makefile                           # Local shortcuts
```

## Build & Test Commands

```bash
# Standard verification chain
swift build
swift test
swift run phoneticsctl --headless seed-check
swift run phoneticsctl --headless smoke-test

# Useful diagnostic
swift run phoneticsctl --headless db-summary

# Open in Xcode
open PhoneticsMaestro.xcodeproj

# GUI launch from CLI
swift run phoneticsctl --gui

# Format (if swift-format is installed)
swift-format format -i -r PhoneticsMaestro PhoneticsCLI PhoneticsMaestroApp PhoneticsMaestroTests
```

## Code Conventions

### Swift Style
- Use `@Observable` macro (Observation framework). **Never** use `ObservableObject` / `@Published`.
- Use Swift actors for service singletons (`AudioService`, `DataService`).
- Use `async/await` everywhere. No completion handlers, no Combine.
- Use `enum` for all finite states (audio state machine, navigation, CLI headless commands).
- Prefer value types (`struct`) over classes unless actor or reference semantics are required.
- One type per file. File name = type name.
- Max function body: 40 lines. Extract private helpers if longer.

### Naming
- Views: `TrainingCardView`, `WelcomeView`
- ViewModels: `TrainingCardViewModel`, `HistoryViewModel`
- Services: `AudioService`, `DataService`
- Models: `PhonePair`, `Sentence`, `SessionStats`, `AppSettings`

### Error Handling
- Services throw typed errors: `AudioServiceError`, `DataServiceError`.
- ViewModels catch and expose errors via `@Observable` error state.
- Views show errors via `.alert()`.
- Headless commands return stable `status=` / `command=` output for scripting and CI.

### Git
- One commit per logical change. Descriptive message in imperative mood.
- Branch naming: `feat/phase-N-description`, `fix/description`, `docs/description`.

### GitHub Workflow (Required)
- After repository bootstrap, all implementation work follows this workflow:
  1. Run local verification: `swift build`, `swift test`, `swift run phoneticsctl --headless seed-check`, and `swift run phoneticsctl --headless smoke-test`.
     Exception: for pure text-only changes that do not modify executable code, tests, build configuration, scripts, or CI workflow files, agents may skip proactively running the verification chain. When using this exception, state explicitly in the final summary that verification was intentionally skipped because the change was documentation-only.
  2. Create or switch to a task branch from `main`.
  3. Commit only the intended logical change.
  4. Push the branch to `origin`.
  5. Open a pull request.
  6. Wait for automated checks to complete and inspect failures with `gh` CLI if needed.
  7. Perform code review before merge, prioritizing bugs, regressions, edge cases, and missing tests.
  8. Address review comments on the same branch, re-run local verification, and push updates. Based on the recent review in handoff.md, please implement the fix for the dropped tags in note_bundle.py. After verifying with pytest, commit the changes and push to github using the gh workflow skill.
  9. Merge after local checks pass, remote checks pass, and review comments are addressed.
- Prefer `gh` CLI for repository, PR, review, and Actions interactions.
- Do not bypass the PR workflow by committing directly to `main`.
- When a task ends without merge, leave the branch pushed and the PR updated with the latest verified state.

## Documentation Layering

- `docs/current-state.md` is the baseline description of what the repository currently does.
- `requirements.md` is the product-intent document, not the source of truth for current implementation status.
- `ARCHITECTURE.md` describes the current runtime structure and system boundaries.
- `docs/handoff-*.md` files are deltas for session continuation, not the primary project overview.

## Architecture Rules

1. **Views never call Services directly.** Views → ViewModel → Service.
2. **AudioService is a singleton actor** with an explicit state machine. State changes must remain coherent and testable.
3. **DataService is a singleton actor** wrapping SQLite. Exposed via async methods returning model types.
4. **No network calls in V1.** If you find yourself importing `URLSession`, stop.
5. **Seed data flows one way:** Bundle JSON → `SeedDataImporter` → SQLite. The app never writes back to JSON.
6. **GUI and CLI share the same core code.** Do not fork business logic between `PhoneticsMaestroApp` and `phoneticsctl`.

## Current Development Mode

- Phase 1-4 implementation work is complete.
- The project is now in iterative maintenance and extension mode:
  - bug fixing
  - manual testing follow-up
  - incremental features
  - documentation and workflow refinement
- Use `requirements.md §6` as historical scope and future reference, not as an instruction to rebuild completed phases.

## What NOT To Do

- Do NOT implement the CLI data pipeline (V2 feature).
- Do NOT add network/API calls.
- Do NOT use third-party UI frameworks unless there is a clear, justified blocker.
- Do NOT use `@StateObject`, `@ObservedObject`, or `@EnvironmentObject`; use `@Observable` with `@State` / `@Environment`.
- Do NOT store recordings in the app bundle. Use `~/Library/Application Support/PhoneticsMaestro/recordings/`.
- Do NOT treat old handoff notes or outdated phase checklists as a more authoritative source than `AGENTS.md` and `docs/current-state.md`.
