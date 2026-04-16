# Maintainability Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce duplication and coupling in training state, app startup, and pair data access without changing runtime behavior.

**Architecture:** Add a small startup abstraction for app initialization, collapse training interaction flags into one view-model state enum with derived properties, and centralize repeated pair projection SQL inside `DataService`.

**Tech Stack:** Swift 5.9, SwiftUI Observation, GRDB, XCTest, SwiftPM, gh CLI

---

### Task 1: Decouple App Startup Initialization

**Files:**
- Create: `PhoneticsMaestro/ViewModels/AppInitializing.swift`
- Modify: `PhoneticsMaestro/ViewModels/AppViewModel.swift`
- Test: `PhoneticsMaestroTests/AppViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testInitializeUsesInjectedAppInitializer() async {
    let initializer = MockAppInitializer()
    let settingsService = MockOnboardingSettingsDataService(
        settings: AppSettings(hasDismissedOnboarding: true)
    )
    let viewModel = AppViewModel(
        trainingCardViewModel: TrainingCardViewModel(
            dataService: MockTrainingDataService(),
            audioService: MockTrainingAudioService(randomTestIndex: 0)
        ),
        appInitializer: initializer,
        settingsService: settingsService
    )

    await viewModel.initialize()

    let callCount = await initializer.callCount()
    XCTAssertEqual(callCount, 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AppViewModelTests/testInitializeUsesInjectedAppInitializer`
Expected: FAIL because `AppViewModel` does not accept `appInitializer` yet.

- [ ] **Step 3: Write minimal implementation**

```swift
protocol AppInitializing: Sendable {
    func initialize() async throws
}

extension DataService: AppInitializing {}
```

```swift
private let appInitializer: any AppInitializing

init(
    trainingCardViewModel: TrainingCardViewModel = TrainingCardViewModel(),
    appInitializer: any AppInitializing = DataService.shared,
    settingsService: any SettingsDataServing = DataService.shared
) {
    self.trainingCardViewModel = trainingCardViewModel
    self.appInitializer = appInitializer
    self.settingsService = settingsService
}
```

```swift
try await appInitializer.initialize()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AppViewModelTests/testInitializeUsesInjectedAppInitializer`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add PhoneticsMaestro/ViewModels/AppInitializing.swift \
  PhoneticsMaestro/ViewModels/AppViewModel.swift \
  PhoneticsMaestroTests/AppViewModelTests.swift
git commit -m "refactor: inject app startup initialization"
```

### Task 2: Collapse Training Interaction State

**Files:**
- Create: `PhoneticsMaestro/Models/TrainingInteractionState.swift`
- Modify: `PhoneticsMaestro/ViewModels/TrainingCardViewModel.swift`
- Modify: `PhoneticsMaestro/Views/Training/TrainingCardView.swift`
- Test: `PhoneticsMaestroTests/TrainingCardViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testInteractionStateReflectsRecordingLifecycle() async throws {
    let viewModel = TrainingCardViewModel(
        dataService: MockTrainingDataService(),
        audioService: MockTrainingAudioService(randomTestIndex: 0)
    )

    await viewModel.loadInitialPair()
    XCTAssertEqual(viewModel.interactionState, .idle)

    try await viewModel.toggleRecording()
    XCTAssertEqual(viewModel.interactionState, .recording)

    try await viewModel.toggleRecording()
    XCTAssertEqual(viewModel.interactionState, .idle)
}

func testInteractionStateReflectsControlledPlaybackLifecycle() async {
    let viewModel = TrainingCardViewModel(
        dataService: MockTrainingDataService(),
        audioService: MockTrainingAudioService(randomTestIndex: 0, playbackMode: .controlled)
    )

    await viewModel.loadInitialPairIfNeeded()
    let task = Task { await viewModel.tapTargetCard(.left) }

    await audioService.waitUntilPlaybackStarts(count: 1)
    XCTAssertEqual(viewModel.interactionState, .playing(control: .targetCard(.left)))

    await audioService.completePlayback()
    await task.value
    XCTAssertEqual(viewModel.interactionState, .idle)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TrainingCardViewModelTests/testInteractionState`
Expected: FAIL because `interactionState` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
enum TrainingInteractionState: Equatable, Sendable {
    case idle
    case recording
    case playing(control: TrainingPlaybackControl)
}
```

```swift
var interactionState: TrainingInteractionState = .idle

var isRecording: Bool {
    if case .recording = interactionState { return true }
    return false
}

var isPlaybackActive: Bool {
    if case .playing = interactionState { return true }
    return false
}

var isABABLooping: Bool {
    if case .playing(control: .ababLoop) = interactionState { return true }
    return false
}

var activePlaybackControl: TrainingPlaybackControl? {
    if case let .playing(control) = interactionState { return control }
    return nil
}
```

```swift
interactionState = .recording
interactionState = .idle
interactionState = .playing(control: control)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter TrainingCardViewModelTests/testInteractionState`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add PhoneticsMaestro/Models/TrainingInteractionState.swift \
  PhoneticsMaestro/ViewModels/TrainingCardViewModel.swift \
  PhoneticsMaestro/Views/Training/TrainingCardView.swift \
  PhoneticsMaestroTests/TrainingCardViewModelTests.swift
git commit -m "refactor: unify training interaction state"
```

### Task 3: Reuse Pair Projection Queries In DataService

**Files:**
- Modify: `PhoneticsMaestro/Services/DataService.swift`
- Test: `PhoneticsMaestroTests/DataServiceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testPairNavigationStillWrapsAfterQueryRefactor() async throws {
    let service = makeService()
    try await service.initialize()

    let first = try await service.fetchNextPair()
    let wrappedPrevious = try await service.fetchPreviousPair(beforeID: first?.id)
    let wrappedNext = try await service.fetchNextPair(afterID: wrappedPrevious?.id)

    XCTAssertEqual(wrappedNext?.id, first?.id)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DataServiceTests/testPairNavigationStillWrapsAfterQueryRefactor`
Expected: FAIL until the helper is added and navigation code is updated.

- [ ] **Step 3: Write minimal implementation**

```swift
private let pairProjectionSQL = """
SELECT
  pairs.id,
  pairs.phoneme_contrast AS phonemeContrast,
  pairs.tier,
  pairs.difficulty,
  wordA.text AS leftText,
  wordA.ipa AS leftIPA,
  wordB.text AS rightText,
  wordB.ipa AS rightIPA
FROM pairs
JOIN words AS wordA ON wordA.id = pairs.word_a_id
JOIN words AS wordB ON wordB.id = pairs.word_b_id
"""
```

```swift
private func fetchPair(
    where clause: String = "",
    orderBy: String
) throws -> PhonePair? {
    try PhonePair.fetchOne(db, sql: pairProjectionSQL + clause + "\nORDER BY " + orderBy + "\nLIMIT 1")
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DataServiceTests/testPairNavigationStillWrapsAfterQueryRefactor`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add PhoneticsMaestro/Services/DataService.swift \
  PhoneticsMaestroTests/DataServiceTests.swift
git commit -m "refactor: reuse pair projection queries"
```

### Task 4: Full Verification And GitHub Workflow

**Files:**
- Modify: implementation files from Tasks 1-3 as needed

- [ ] **Step 1: Run focused test slices**

Run:

```bash
swift test --filter AppViewModelTests
swift test --filter TrainingCardViewModelTests
swift test --filter DataServiceTests
```

Expected: PASS

- [ ] **Step 2: Run required verification chain**

Run:

```bash
swift build
swift test
swift run phoneticsctl --headless seed-check
swift run phoneticsctl --headless smoke-test
```

Expected: PASS

- [ ] **Step 3: Publish branch and open PR**

Run:

```bash
git push -u origin refactor/maintainability-boundaries
gh pr create \
  --base main \
  --head refactor/maintainability-boundaries \
  --title "Refactor training state and startup boundaries" \
  --body "## Summary\n- inject app startup initialization\n- unify training interaction state\n- reuse pair projection queries in DataService\n\n## Verification\n- swift build\n- swift test\n- swift run phoneticsctl --headless seed-check\n- swift run phoneticsctl --headless smoke-test"
```

- [ ] **Step 4: Watch checks and address review**

Run:

```bash
gh pr checks --watch
gh pr view --comments
```

Expected: all checks pass; fix any review comments on the same branch and re-run verification before pushing.

- [ ] **Step 5: Merge after review is clean**

Run:

```bash
gh pr merge --squash --delete-branch
```

Expected: merged cleanly after all comments are addressed.
