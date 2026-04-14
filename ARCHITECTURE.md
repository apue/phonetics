# ARCHITECTURE.md — Phonetics Maestro

## 1. Runtime Shape

Phonetics Maestro is no longer a single SwiftPM executable pretending to be the whole app. The runtime is split into three layers:

```text
┌────────────────────────────────────────────────────┐
│                 PhoneticsMaestroApp                │
│        Standard macOS .app host and window         │
│  - PhoneticsMaestroApp.swift                       │
│  - Info.plist                                      │
│  - WindowGroup / App lifecycle                     │
└──────────────────────────┬─────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────┐
│                    PhoneticsCore                   │
│         Shared product logic used by app + CLI     │
│  - RootView / SwiftUI screens                      │
│  - ViewModels                                      │
│  - AudioService / DataService                      │
│  - SeedDataImporter                                │
│  - HeadlessAcceptanceRunner                        │
│  - Models and resources                            │
└──────────────────────────┬─────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────┐
│                    phoneticsctl                    │
│              Companion CLI entry point             │
│  - --gui                                           │
│  - --headless seed-check                           │
│  - --headless db-summary                           │
│  - --headless smoke-test                           │
└────────────────────────────────────────────────────┘
```

This split exists to satisfy two different launch modes cleanly:

- a real macOS `.app` for humans and Xcode
- a stable CLI surface for automation, CI, and agent validation

## 2. Targets And Entry Points

### 2.1 Shared Package

`Package.swift` defines:

- library product: `PhoneticsCore`
- executable product: `phoneticsctl`
- test target: `PhoneticsMaestroTests`

`PhoneticsCore` is built from the `PhoneticsMaestro/` directory and contains all shared runtime logic.

### 2.2 GUI Host

`PhoneticsMaestroApp/PhoneticsMaestroApp.swift` is the real app entry point:

```text
@main PhoneticsMaestroApp
  └─ WindowGroup
      └─ RootView(viewModel: AppViewModel())
          └─ .task { await viewModel.initialize() }
```

This target owns the application bundle, `Info.plist`, privacy descriptions, and the normal macOS window lifecycle.

### 2.3 CLI Host

`PhoneticsCLI/main.swift` parses arguments and dispatches one of two paths:

- `phoneticsctl --gui`
  launches the app host via `AppLauncher`
- `phoneticsctl --headless <command>`
  runs a non-UI acceptance command via `HeadlessAcceptanceRunner`

The CLI is intentionally thin. It should orchestrate, not duplicate, business logic.

## 3. UI Shell

The app shell lives in `PhoneticsMaestro/App/RootView.swift`.

Current structure:

- `NavigationSplitView`
- sidebar destinations: `Welcome`, `Training`, `History`, `Settings`
- toolbar sidebar toggle with `⌘+\`
- initialization overlay and alert handling

`AppViewModel` owns top-level app state:

- selected screen
- split view visibility
- initialization state
- shared `TrainingCardViewModel`

Initialization currently happens in `AppViewModel.initialize()`:

```text
RootView task
  └─ AppViewModel.initialize()
      ├─ DataService.shared.initialize()
      └─ TrainingCardViewModel.loadInitialPair()
```

## 4. Screen Responsibilities

### 4.1 Welcome

`WelcomeView` is the simple entry screen for:

- begin training
- open history
- open settings

### 4.2 Training

`TrainingCardView` + `TrainingCardViewModel` implement the core loop:

- minimal-pair display with IPA
- random perception test
- answer submission with success/error feedback
- record toggle
- single-track playback: `Standard`, `Me`
- `A/B` loop playback
- `Save` / `Hard` tagging
- session stats: `LISTENS`, `CORRECT`, `PRACTICES`, `TIME`
- card navigation and keyboard shortcuts

### 4.3 History

`HistoryView` + `HistoryViewModel` show session summaries loaded from SQLite.

Current data includes:

- session date
- total time
- correct/listen counts
- practice count

### 4.4 Settings

`SettingsView` + `SettingsViewModel` manage persisted local preferences:

- preferred TTS voice
- preferred microphone
- ABAB interval

## 5. Service Layer

The shared service layer lives under `PhoneticsMaestro/Services/`.

### 5.1 DataService

`DataService` is a singleton actor responsible for:

- resolving application support paths
- creating/opening the SQLite database
- running schema setup and migrations
- importing bundled seed data on first run
- CRUD for pairs, tag state, settings, and history summaries
- exposing lightweight query APIs for view models and headless commands

Storage location:

```text
~/Library/Application Support/PhoneticsMaestro/
├── maestro.sqlite
└── recordings/
    └── {session-date}/
```

### 5.2 AudioService

`AudioService` is a singleton actor responsible for:

- microphone recording
- standard playback
- user-recording playback
- random test playback
- ABAB loop playback
- audio state coordination

It uses a platform client abstraction:

- protocol: `AudioPlatformClient`
- production implementation: `SystemAudioPlatformClient`

This keeps the state machine testable without depending on real audio hardware during unit tests.

### 5.3 HeadlessAcceptanceRunner

`HeadlessAcceptanceRunner` exists in the shared core so CLI validation exercises the same data initialization path as the app.

Supported commands:

- `seed-check`
- `db-summary`
- `smoke-test`

Output format is line-based and script-friendly:

```text
status=ok
command=smoke-test
pair_count=...
...
```

## 6. Audio State Model

The audio runtime is modeled as explicit finite state:

```text
idle
recording
playing(source: .standard | .userRecording | .randomTest)
playingABAB
```

Important behavioral constraints:

- recording and playback modes must not overlap illegally
- navigation must stop active recording or playback before switching cards
- replaying the same user-recording source while already in that playback state is treated as idempotent, not a fatal transition

The state machine is enforced in `AudioService` and covered by unit tests.

## 7. Data Initialization Flow

On first launch or first headless run:

```text
DataService.initialize()
  ├─ resolve app support directory
  ├─ create/open maestro.sqlite
  ├─ run schema setup / migrations
  ├─ inspect whether seed data already exists
  └─ if needed, SeedDataImporter imports:
       - Resources/SeedData/seed-phonemes.json
       - Resources/SeedData/seed-sentences.json
```

Seed data is bundled with the app/package and loaded into SQLite. The app never mutates the JSON resources.

## 8. Testing And Verification Shape

There are three validation layers:

1. Package-level build and unit tests
   - `swift build`
   - `swift test`
2. Headless acceptance validation
   - `swift run phoneticsctl --headless seed-check`
   - `swift run phoneticsctl --headless smoke-test`
3. Manual GUI validation
   - `open PhoneticsMaestro.xcodeproj`
   - run `PhoneticsMaestroApp` on `My Mac`

`db-summary` is a diagnostic command, not part of the required verification chain.

## 9. Current Boundaries

These are deliberate current limits, not missing bugs:

- no network calls
- no V2 CLI data-generation pipeline
- no GUI automation layer in the repository
- headless commands validate data and initialization paths, not real microphone/TTS hardware behavior
- `phoneticsctl --gui` still relies on environment override or local development fallback for app bundle discovery, as noted in the latest handoff

## 10. Change Guidance

When changing architecture-sensitive code:

- keep shared business logic in `PhoneticsCore`
- avoid duplicating logic across app host and CLI host
- update `docs/current-state.md` if the user-visible baseline changes
- update this file if runtime boundaries, entry points, or validation shape change
