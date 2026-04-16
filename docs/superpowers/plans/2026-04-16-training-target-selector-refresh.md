# Training Target Selector Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the approved target selector, unified pair/sentence training flow, refreshed shell semantics, OCR-style UI verification, and the full GitHub PR workflow for the training workspace.

**Architecture:** Build a normalized training-card domain that sits between SQLite and SwiftUI, so the training view stops depending directly on `PhonePair`. Refresh the shell and training card around that model, then verify with behavior tests, deterministic screenshots, and textual screenshot readouts.

**Tech Stack:** SwiftUI, Observation, async/await, GRDB, XCTest, Vision OCR via Swift script/command, `gh` CLI

---

## File Map

- Create: `PhoneticsMaestro/Models/TrainingTargetGroup.swift`
- Create: `PhoneticsMaestro/Models/TrainingTargetSummary.swift`
- Create: `PhoneticsMaestro/Models/TrainingCardItem.swift`
- Create: `PhoneticsMaestro/Models/TrainingCardItemKind.swift`
- Modify: `PhoneticsMaestro/Models/AppScreen.swift`
- Modify: `PhoneticsMaestro/Models/AppSettings.swift`
- Modify: `PhoneticsMaestro/ViewModels/TrainingDataServing.swift`
- Modify: `PhoneticsMaestro/ViewModels/TrainingAudioServing.swift`
- Modify: `PhoneticsMaestro/ViewModels/TrainingCardViewModel.swift`
- Modify: `PhoneticsMaestro/ViewModels/AppViewModel.swift`
- Modify: `PhoneticsMaestro/Services/DataService.swift`
- Modify: `PhoneticsMaestro/Services/AudioService.swift`
- Modify: `PhoneticsMaestro/App/RootView.swift`
- Modify: `PhoneticsMaestro/Views/Training/TrainingCardView.swift`
- Modify: `PhoneticsMaestro/Services/UIScreenshotRenderer.swift`
- Modify: `PhoneticsMaestro/Services/HeadlessAcceptanceCommand.swift`
- Modify: `PhoneticsMaestro/Services/HeadlessAcceptanceRunner.swift`
- Modify: `PhoneticsCLI/CLICommand.swift`
- Create: `PhoneticsMaestroTests/TrainingTargetCatalogTests.swift`
- Modify: `PhoneticsMaestroTests/TrainingCardViewModelTests.swift`
- Modify: `PhoneticsMaestroTests/DataServiceTests.swift`
- Modify: `PhoneticsMaestroTests/AppViewModelTests.swift`
- Modify: `PhoneticsMaestroTests/HeadlessAcceptanceRunnerTests.swift`

### Task 1: Add Normalized Training Target And Card Models

**Files:**
- Create: `PhoneticsMaestro/Models/TrainingTargetGroup.swift`
- Create: `PhoneticsMaestro/Models/TrainingTargetSummary.swift`
- Create: `PhoneticsMaestro/Models/TrainingCardItem.swift`
- Create: `PhoneticsMaestro/Models/TrainingCardItemKind.swift`
- Modify: `PhoneticsMaestro/ViewModels/TrainingDataServing.swift`
- Modify: `PhoneticsMaestroTests/TrainingTargetCatalogTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testSoundContrastTargetUsesContrastAndExampleSummary() {
    let target = TrainingTargetSummary(
        id: "pair:ʌ-æ",
        group: .soundContrasts,
        title: "ʌ-æ",
        subtitle: "but / bat",
        currentItemType: "pair"
    )

    XCTAssertEqual(target.group.sectionTitle, "Sound Contrasts")
    XCTAssertEqual(target.displayLabel, "ʌ-æ")
}

func testSentenceBackedCardUsesLeftAndRightSentenceTargets() {
    let card = TrainingCardItem(
        kind: .sentence(phenomenon: "linking"),
        itemType: "sentence",
        itemID: 1,
        targetID: "sentence:linking",
        title: "Linking",
        subtitle: "Pick it up.",
        leftText: "Pick it up.",
        leftIPA: "/pɪk‿ɪt‿ʌp/",
        rightText: "Turn it on.",
        rightIPA: "/tɜːn‿ɪt‿ɒn/",
        tierLabel: "Sentence"
    )

    XCTAssertEqual(card.leftText, "Pick it up.")
    XCTAssertEqual(card.rightText, "Turn it on.")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter 'TrainingTargetCatalogTests'`
Expected: FAIL because the normalized selector/card models do not exist yet.

- [ ] **Step 3: Add the minimal models and protocol changes**

```swift
enum TrainingTargetGroup: String, CaseIterable, Sendable {
    case soundContrasts
    case linkingReduction
    case stressIntonation

    var sectionTitle: String { ... }
}
```

```swift
struct TrainingTargetSummary: Equatable, Identifiable, Sendable {
    let id: String
    let group: TrainingTargetGroup
    let title: String
    let subtitle: String
    let currentItemType: String

    var displayLabel: String { title }
}
```

```swift
struct TrainingCardItem: Equatable, Sendable, Identifiable {
    let kind: TrainingCardItemKind
    let itemType: String
    let itemID: Int64
    let targetID: String
    let title: String
    let subtitle: String
    let leftText: String
    let leftIPA: String?
    let rightText: String
    let rightIPA: String?
    let tierLabel: String

    var id: String { "\(itemType):\(itemID)" }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter 'TrainingTargetCatalogTests'`
Expected: PASS with the new selector/card model coverage green.

- [ ] **Step 5: Commit**

```bash
git add PhoneticsMaestro/Models/TrainingTargetGroup.swift \
        PhoneticsMaestro/Models/TrainingTargetSummary.swift \
        PhoneticsMaestro/Models/TrainingCardItem.swift \
        PhoneticsMaestro/Models/TrainingCardItemKind.swift \
        PhoneticsMaestro/ViewModels/TrainingDataServing.swift \
        PhoneticsMaestroTests/TrainingTargetCatalogTests.swift
git commit -m "feat: add normalized training target models"
```

### Task 2: Generalize Data And Playback Services For Unified Targets

**Files:**
- Modify: `PhoneticsMaestro/Services/DataService.swift`
- Modify: `PhoneticsMaestro/ViewModels/TrainingDataServing.swift`
- Modify: `PhoneticsMaestro/ViewModels/TrainingAudioServing.swift`
- Modify: `PhoneticsMaestro/Services/AudioService.swift`
- Modify: `PhoneticsMaestroTests/DataServiceTests.swift`
- Modify: `PhoneticsMaestroTests/TrainingCardViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testFetchTrainingTargetsIncludesSentencePhenomenaGroups() async throws {
    let service = try makeInitializedDataService()

    let targets = try await service.fetchTrainingTargets()

    XCTAssertTrue(targets.contains { $0.id == "pair:ʌ-æ" })
    XCTAssertTrue(targets.contains { $0.id == "sentence:linking" })
    XCTAssertTrue(targets.contains { $0.id == "sentence:intonation" })
}

func testFetchTrainingCardsForSentenceTargetBuildsComparisonCard() async throws {
    let service = try makeInitializedDataService()

    let cards = try await service.fetchTrainingCards(forTargetID: "sentence:linking")

    XCTAssertEqual(cards.first?.leftText, "Pick it up.")
    XCTAssertEqual(cards.first?.rightText, "Turn it on.")
    XCTAssertEqual(cards.first?.itemType, "sentence")
}

func testPracticePlaybackRateUpdatesPracticeActionsOnly() async throws {
    let viewModel = TrainingCardViewModel(
        dataService: MockTrainingDataService(),
        audioService: MockTrainingAudioService(randomTestIndex: 0)
    )

    await viewModel.loadInitialState()
    viewModel.playbackRate = 1.25
    try await viewModel.playSelectedStandard()

    let rates = await audioService.standardPlaybackRates()
    XCTAssertEqual(rates, [1.25])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter 'DataServiceTests|TrainingCardViewModelTests'`
Expected: FAIL because data service has only pair APIs and playback service does not expose configurable rates to the training view model.

- [ ] **Step 3: Implement generic target/card queries and rate-aware playback**

```swift
protocol TrainingDataServing: Sendable {
    func fetchTrainingTargets() async throws -> [TrainingTargetSummary]
    func fetchTrainingCards(forTargetID targetID: String) async throws -> [TrainingCardItem]
    func fetchTagState(itemType: String, itemID: Int64) async throws -> TrainingTagState
    func fetchSessionStats(itemType: String, itemID: Int64, sessionDate: String) async throws -> SessionStats
    func updateTagState(itemType: String, itemID: Int64, sessionDate: String, isSaved: Bool, isHard: Bool) async throws
    func updateSessionStats(itemType: String, itemID: Int64, sessionDate: String, stats: SessionStats, isSaved: Bool, isHard: Bool) async throws
}
```

```swift
protocol TrainingAudioServing: Sendable {
    func playStandard(for text: String, rate: Float) async throws
    func playUserRecording(rate: Float) async throws
    func startABABLoop(standardText: String, rate: Float, silenceNanoseconds: UInt64) async throws
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter 'DataServiceTests|TrainingCardViewModelTests'`
Expected: PASS with target catalog, sentence-card derivation, generic persistence, and rate-aware practice playback covered.

- [ ] **Step 5: Commit**

```bash
git add PhoneticsMaestro/Services/DataService.swift \
        PhoneticsMaestro/ViewModels/TrainingDataServing.swift \
        PhoneticsMaestro/ViewModels/TrainingAudioServing.swift \
        PhoneticsMaestro/Services/AudioService.swift \
        PhoneticsMaestroTests/DataServiceTests.swift \
        PhoneticsMaestroTests/TrainingCardViewModelTests.swift
git commit -m "feat: generalize training data and playback services"
```

### Task 3: Refactor View Models And Shell/UI Around The Selector

**Files:**
- Modify: `PhoneticsMaestro/ViewModels/TrainingCardViewModel.swift`
- Modify: `PhoneticsMaestro/ViewModels/AppViewModel.swift`
- Modify: `PhoneticsMaestro/Models/AppScreen.swift`
- Modify: `PhoneticsMaestro/App/RootView.swift`
- Modify: `PhoneticsMaestro/Views/Training/TrainingCardView.swift`
- Modify: `PhoneticsMaestroTests/AppViewModelTests.swift`
- Modify: `PhoneticsMaestroTests/TrainingCardViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testSwitchingTargetResetsToFirstCardOfThatTarget() async {
    let viewModel = TrainingCardViewModel(
        dataService: MockTrainingDataService(),
        audioService: MockTrainingAudioService(randomTestIndex: 0)
    )

    await viewModel.loadInitialState()
    await viewModel.loadNextCard()
    await viewModel.selectTarget(id: "sentence:linking")

    XCTAssertEqual(viewModel.currentCard?.targetID, "sentence:linking")
    XCTAssertEqual(viewModel.currentCardIndex, 0)
}

func testSidebarUsesBeginLabelForTrainingDestination() {
    XCTAssertEqual(AppScreen.training.title, "Begin")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter 'AppViewModelTests|TrainingCardViewModelTests'`
Expected: FAIL because the training view model is still pair-only and the app shell still labels the destination as `Training`.

- [ ] **Step 3: Implement selector-driven state and refreshed shell**

```swift
@Observable
final class TrainingCardViewModel {
    var targets: [TrainingTargetSummary] = []
    var selectedTargetID: String?
    var cards: [TrainingCardItem] = []
    var currentCardIndex = 0
    var playbackRate: Float = 1.0

    var currentCard: TrainingCardItem? {
        guard cards.indices.contains(currentCardIndex) else { return nil }
        return cards[currentCardIndex]
    }
}
```

```swift
enum AppScreen: String, CaseIterable, Identifiable {
    case training
    case history
    case settings

    var title: String {
        switch self {
        case .training: return "Begin"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter 'AppViewModelTests|TrainingCardViewModelTests'`
Expected: PASS with target switching, Begin label semantics, and updated training state verified.

- [ ] **Step 5: Commit**

```bash
git add PhoneticsMaestro/ViewModels/TrainingCardViewModel.swift \
        PhoneticsMaestro/ViewModels/AppViewModel.swift \
        PhoneticsMaestro/Models/AppScreen.swift \
        PhoneticsMaestro/App/RootView.swift \
        PhoneticsMaestro/Views/Training/TrainingCardView.swift \
        PhoneticsMaestroTests/AppViewModelTests.swift \
        PhoneticsMaestroTests/TrainingCardViewModelTests.swift
git commit -m "feat: add training target selector UI flow"
```

### Task 4: Add Screenshot Readout Verification And Refresh Fixtures

**Files:**
- Modify: `PhoneticsMaestro/Services/UIScreenshotRenderer.swift`
- Modify: `PhoneticsMaestro/Services/HeadlessAcceptanceCommand.swift`
- Modify: `PhoneticsMaestro/Services/HeadlessAcceptanceRunner.swift`
- Modify: `PhoneticsCLI/CLICommand.swift`
- Modify: `PhoneticsMaestroTests/HeadlessAcceptanceRunnerTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testUIScreenshotReadoutCommandEmitsStableSections() async throws {
    let appSupportURL = makeTemporaryDirectory()
    let runner = HeadlessAcceptanceRunner(appSupportURL: appSupportURL)

    let result = await runner.run(.uiReadout)

    XCTAssertEqual(result.exitCode, 0)
    XCTAssertTrue(result.output.contains("command=ui-readout"))
    XCTAssertTrue(result.output.contains("training_text="))
    XCTAssertTrue(result.output.contains("onboarding_text="))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter HeadlessAcceptanceRunnerTests`
Expected: FAIL because the readout command does not exist yet.

- [ ] **Step 3: Implement deterministic screenshot OCR/readout**

```swift
enum HeadlessAcceptanceCommand: String {
    case seedCheck = "seed-check"
    case dbSummary = "db-summary"
    case smokeTest = "smoke-test"
    case uiScreenshots = "ui-screenshots"
    case uiReadout = "ui-readout"
}
```

```swift
struct UIScreenshotReadout {
    let onboardingText: String
    let trainingText: String
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter HeadlessAcceptanceRunnerTests`
Expected: PASS with stable screenshot and text-readout outputs.

- [ ] **Step 5: Commit**

```bash
git add PhoneticsMaestro/Services/UIScreenshotRenderer.swift \
        PhoneticsMaestro/Services/HeadlessAcceptanceCommand.swift \
        PhoneticsMaestro/Services/HeadlessAcceptanceRunner.swift \
        PhoneticsCLI/CLICommand.swift \
        PhoneticsMaestroTests/HeadlessAcceptanceRunnerTests.swift
git commit -m "feat: add UI screenshot readout verification"
```

### Task 5: Verify, Publish, Review, Fix, And Merge

**Files:**
- Modify: `docs/current-state.md` if user-visible behavior changes need baseline updates
- Modify: `docs/handoff-2026-04-16-codex.md` if a handoff is still needed after merge preparation

- [ ] **Step 1: Run full local verification**

```bash
swift build
swift test
swift run phoneticsctl --headless seed-check
swift run phoneticsctl --headless smoke-test
swift run phoneticsctl --headless ui-screenshots
swift run phoneticsctl --headless ui-readout
```

- [ ] **Step 2: Review the generated UI outputs**

```bash
open .build/ui-snapshots/onboarding.png
open .build/ui-snapshots/training.png
swift run phoneticsctl --headless ui-readout
```

Expected:
- screenshots match the editorial hierarchy
- OCR/readout includes `Begin`, `Target:`, `Perception`, `Practice`, `LISTENS`, `CORRECT`, `PRACTICES`, `TIME`

- [ ] **Step 3: Push and open the PR**

```bash
git push -u origin feat/training-target-selector-refresh
gh pr create --fill --base main --head feat/training-target-selector-refresh
```

- [ ] **Step 4: Wait for remote checks and perform review**

```bash
gh pr checks --watch
gh pr view --json files,comments,reviews
```

- [ ] **Step 5: Address review comments, re-run verification, and merge**

```bash
swift build
swift test
swift run phoneticsctl --headless seed-check
swift run phoneticsctl --headless smoke-test
swift run phoneticsctl --headless ui-readout
git push
gh pr merge --squash --delete-branch
```
