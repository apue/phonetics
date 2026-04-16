# Onboarding And Training UI Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace persistent welcome navigation with first-run onboarding, refresh the training layout to the approved native-editorial structure, and add deterministic screenshot verification for UI review.

**Architecture:** Keep `NavigationSplitView` as the shell, move onboarding into persisted app state, and refresh `TrainingCardView` composition without changing core audio behavior. Add a renderable UI fixture path through the existing headless CLI so verification produces PNGs in stable states.

**Tech Stack:** SwiftUI, Observation, async/await, GRDB-backed `DataService`, XCTest, existing `phoneticsctl` headless commands

---

## File Map

- Modify: `PhoneticsMaestro/Models/AppScreen.swift`
  remove the persistent welcome screen from navigation titles/images
- Modify: `PhoneticsMaestro/Models/AppSettings.swift`
  persist onboarding dismissal
- Modify: `PhoneticsMaestro/Services/DataService.swift`
  read/write onboarding dismissal and migrate schema
- Modify: `PhoneticsMaestro/ViewModels/AppViewModel.swift`
  derive default destination and onboarding state from persisted settings
- Modify: `PhoneticsMaestro/App/RootView.swift`
  stop routing detail through `WelcomeView`; host onboarding overlay over persistent detail content
- Create: `PhoneticsMaestro/Views/Onboarding/OnboardingView.swift`
  transient onboarding UI
- Modify: `PhoneticsMaestro/Views/Training/TrainingCardView.swift`
  implement approved layout hierarchy and stats/hint fixes
- Modify: `PhoneticsMaestro/Services/HeadlessAcceptanceCommand.swift`
  add screenshot command
- Modify: `PhoneticsMaestro/Services/HeadlessAcceptanceRunner.swift`
  invoke screenshot renderer and emit stable output paths
- Create: `PhoneticsMaestro/Services/UIScreenshotRenderer.swift`
  render fixed-state onboarding and training PNGs
- Modify: `PhoneticsCLI/CLICommand.swift`
  accept new headless command
- Modify: `PhoneticsMaestroTests/AppViewModelTests.swift`
  add onboarding/default-destination tests
- Modify: `PhoneticsMaestroTests/DataServiceTests.swift`
  cover onboarding persistence
- Modify: `PhoneticsMaestroTests/HeadlessAcceptanceRunnerTests.swift`
  cover screenshot command output
- Modify: `PhoneticsMaestroTests/TrainingCardViewModelTests.swift`
  preserve selected-target semantics where needed

### Task 1: Persist Onboarding State And Default To Training

**Files:**
- Modify: `PhoneticsMaestro/Models/AppSettings.swift`
- Modify: `PhoneticsMaestro/Services/DataService.swift`
- Modify: `PhoneticsMaestro/ViewModels/AppViewModel.swift`
- Modify: `PhoneticsMaestroTests/AppViewModelTests.swift`
- Modify: `PhoneticsMaestroTests/DataServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
@MainActor
func testInitializedAppDefaultsToTrainingWhenOnboardingIsDismissed() async {
    let trainingViewModel = TrainingCardViewModel(
        dataService: StubTrainingDataService(),
        audioService: StubAudioService()
    )
    let settingsService = StubAppSettingsService(settings: AppSettings(hasDismissedOnboarding: true))
    let viewModel = AppViewModel(
        trainingCardViewModel: trainingViewModel,
        settingsService: settingsService
    )

    await viewModel.initialize()

    XCTAssertEqual(viewModel.selectedScreen, .training)
    XCTAssertFalse(viewModel.shouldShowOnboarding)
}

@MainActor
func testInitializedAppShowsOnboardingUntilDismissed() async {
    let viewModel = AppViewModel(
        trainingCardViewModel: TrainingCardViewModel(
            dataService: StubTrainingDataService(),
            audioService: StubAudioService()
        ),
        settingsService: StubAppSettingsService(settings: AppSettings(hasDismissedOnboarding: false))
    )

    await viewModel.initialize()
    XCTAssertTrue(viewModel.shouldShowOnboarding)

    await viewModel.dismissOnboarding()
    XCTAssertFalse(viewModel.shouldShowOnboarding)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AppViewModelTests`
Expected: FAIL because `AppViewModel` has no onboarding settings dependency or dismissal API.

- [ ] **Step 3: Add the persistence model and minimal implementation**

```swift
struct AppSettings: Codable, Equatable, Sendable {
    var preferredVoiceName: String
    var preferredMicrophoneName: String
    var ababIntervalMilliseconds: Int
    var hasDismissedOnboarding: Bool

    init(
        preferredVoiceName: String = "System Default",
        preferredMicrophoneName: String = "System Default",
        ababIntervalMilliseconds: Int = 300,
        hasDismissedOnboarding: Bool = false
    ) {
        self.preferredVoiceName = preferredVoiceName
        self.preferredMicrophoneName = preferredMicrophoneName
        self.ababIntervalMilliseconds = ababIntervalMilliseconds
        self.hasDismissedOnboarding = hasDismissedOnboarding
    }
}
```

```swift
@MainActor
@Observable
public final class AppViewModel {
    var selectedScreen: AppScreen = .training
    var shouldShowOnboarding = false

    private let settingsService: any SettingsDataServing

    init(
        trainingCardViewModel: TrainingCardViewModel = TrainingCardViewModel(),
        settingsService: any SettingsDataServing = DataService.shared
    ) {
        self.trainingCardViewModel = trainingCardViewModel
        self.settingsService = settingsService
    }

    public func initialize() async {
        ...
        let settings = try await settingsService.fetchSettings()
        shouldShowOnboarding = !settings.hasDismissedOnboarding
        selectedScreen = .training
        await trainingCardViewModel.loadInitialPair()
    }

    func dismissOnboarding() async {
        guard shouldShowOnboarding else { return }
        shouldShowOnboarding = false
        var settings = (try? await settingsService.fetchSettings()) ?? AppSettings()
        settings.hasDismissedOnboarding = true
        try? await settingsService.updateSettings(settings)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter 'AppViewModelTests|DataServiceTests'`
Expected: PASS for onboarding defaults and persistence coverage.

- [ ] **Step 5: Commit**

```bash
git add PhoneticsMaestro/Models/AppSettings.swift \
        PhoneticsMaestro/Services/DataService.swift \
        PhoneticsMaestro/ViewModels/AppViewModel.swift \
        PhoneticsMaestroTests/AppViewModelTests.swift \
        PhoneticsMaestroTests/DataServiceTests.swift
git commit -m "feat: persist onboarding dismissal state"
```

### Task 2: Replace Welcome With Onboarding Overlay In The Root Shell

**Files:**
- Modify: `PhoneticsMaestro/Models/AppScreen.swift`
- Modify: `PhoneticsMaestro/App/RootView.swift`
- Create: `PhoneticsMaestro/Views/Onboarding/OnboardingView.swift`
- Modify: `PhoneticsMaestroTests/AppViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testAppScreenCasesExcludeWelcome() {
    XCTAssertEqual(AppScreen.allCases, [.training, .history, .settings])
}
```

```swift
@MainActor
func testDismissOnboardingPersistsAndKeepsTrainingSelected() async {
    let settingsService = StubAppSettingsService(settings: AppSettings())
    let viewModel = AppViewModel(
        trainingCardViewModel: TrainingCardViewModel(
            dataService: StubTrainingDataService(),
            audioService: StubAudioService()
        ),
        settingsService: settingsService
    )

    await viewModel.initialize()
    await viewModel.dismissOnboarding()

    XCTAssertEqual(viewModel.selectedScreen, .training)
    XCTAssertEqual(settingsService.updatedSettings?.hasDismissedOnboarding, true)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AppViewModelTests`
Expected: FAIL because `AppScreen` still includes `.welcome` and dismissal does not persist.

- [ ] **Step 3: Write the minimal implementation**

```swift
enum AppScreen: String, CaseIterable, Identifiable {
    case training
    case history
    case settings
    ...
}
```

```swift
public struct RootView: View {
    ...

    public var body: some View {
        NavigationSplitView(columnVisibility: $viewModel.splitViewVisibility) {
            List(AppScreen.allCases, selection: $viewModel.selectedScreen) { screen in
                Label(screen.title, systemImage: screen.systemImage).tag(screen)
            }
        } detail: {
            detailView
                .overlay {
                    if viewModel.shouldShowOnboarding {
                        OnboardingView(
                            beginAction: { Task { await viewModel.dismissOnboarding() } },
                            dismissAction: { Task { await viewModel.dismissOnboarding() } }
                        )
                    }
                }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AppViewModelTests`
Expected: PASS with `.welcome` removed and onboarding dismissal preserving `Training`.

- [ ] **Step 5: Commit**

```bash
git add PhoneticsMaestro/Models/AppScreen.swift \
        PhoneticsMaestro/App/RootView.swift \
        PhoneticsMaestro/Views/Onboarding/OnboardingView.swift \
        PhoneticsMaestroTests/AppViewModelTests.swift
git commit -m "feat: present onboarding as transient overlay"
```

### Task 3: Refresh Training Layout Hierarchy

**Files:**
- Modify: `PhoneticsMaestro/Views/Training/TrainingCardView.swift`
- Modify: `PhoneticsMaestroTests/TrainingCardViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testPracticePlaybackUsesSelectedTargetForStandardAndABAB() async throws {
    ...
    XCTAssertEqual(audioService.standardPlaybackRequests().last, "bat")
    XCTAssertEqual(audioService.ababLoopRequests().last, "bat")
}
```

```swift
func testStatsUseSeparateAbsoluteCounts() {
    let stats = SessionStats(listens: 12, correct: 9, practices: 4, elapsedSeconds: 154)
    XCTAssertEqual(stats.correct, 9)
    XCTAssertEqual(stats.listens, 12)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TrainingCardViewModelTests`
Expected: any new target-semantics assertions fail until layout refactor preserves them explicitly.

- [ ] **Step 3: Write the minimal implementation**

```swift
private var correctStatText: String {
    "\(viewModel.sessionStats.correct)"
}
```

```swift
private var contentBody: some View {
    VStack(alignment: .leading, spacing: 24) {
        headerSection(pair: pair)
        HStack(alignment: .top, spacing: 20) {
            perceptionSection(pair: pair)
            practiceSection(pair: pair)
        }
        footerSection
    }
}
```

```swift
Text(practiceFeedbackText)
    .font(.callout)
    .foregroundStyle(viewModel.isRecording ? .red : .secondary)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter TrainingCardViewModelTests`
Expected: PASS with target-selection semantics preserved.

- [ ] **Step 5: Commit**

```bash
git add PhoneticsMaestro/Views/Training/TrainingCardView.swift \
        PhoneticsMaestroTests/TrainingCardViewModelTests.swift
git commit -m "feat: refresh training card layout"
```

### Task 4: Add Deterministic Screenshot Verification

**Files:**
- Modify: `PhoneticsMaestro/Services/HeadlessAcceptanceCommand.swift`
- Modify: `PhoneticsMaestro/Services/HeadlessAcceptanceRunner.swift`
- Modify: `PhoneticsCLI/CLICommand.swift`
- Create: `PhoneticsMaestro/Services/UIScreenshotRenderer.swift`
- Modify: `PhoneticsMaestroTests/HeadlessAcceptanceRunnerTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testUIScreenshotCommandProducesStableOutputFields() async {
    let runner = HeadlessAcceptanceRunner(appSupportURL: appSupportURL)

    let result = await runner.run(.uiScreenshots)

    XCTAssertEqual(result.exitCode, 0)
    XCTAssertTrue(result.output.contains("command=ui-screenshots"))
    XCTAssertTrue(result.output.contains("onboarding_png="))
    XCTAssertTrue(result.output.contains("training_png="))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter HeadlessAcceptanceRunnerTests`
Expected: FAIL because `.uiScreenshots` and the renderer do not exist.

- [ ] **Step 3: Write the minimal implementation**

```swift
public enum HeadlessAcceptanceCommand: String, Equatable, Sendable {
    case seedCheck = "seed-check"
    case dbSummary = "db-summary"
    case smokeTest = "smoke-test"
    case uiScreenshots = "ui-screenshots"
}
```

```swift
@MainActor
struct UIScreenshotRenderer {
    func render(to directory: URL) throws -> (onboarding: URL, training: URL) {
        let onboardingURL = directory.appendingPathComponent("onboarding.png")
        let trainingURL = directory.appendingPathComponent("training.png")
        try render(OnboardingFixtureView(), to: onboardingURL, size: CGSize(width: 1440, height: 960))
        try render(TrainingFixtureView(), to: trainingURL, size: CGSize(width: 1440, height: 960))
        return (onboardingURL, trainingURL)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter HeadlessAcceptanceRunnerTests`
Expected: PASS and stable output fields for screenshot generation.

- [ ] **Step 5: Commit**

```bash
git add PhoneticsMaestro/Services/HeadlessAcceptanceCommand.swift \
        PhoneticsMaestro/Services/HeadlessAcceptanceRunner.swift \
        PhoneticsMaestro/Services/UIScreenshotRenderer.swift \
        PhoneticsCLI/CLICommand.swift \
        PhoneticsMaestroTests/HeadlessAcceptanceRunnerTests.swift
git commit -m "feat: add headless ui screenshot verification"
```

### Task 5: Run Full Verification And Produce Review Artifacts

**Files:**
- Modify: `Resources/design-comparison.html`
  only if the generated screenshot paths or naming need documentation

- [ ] **Step 1: Run unit and package verification**

Run: `swift build`
Expected: BUILD SUCCEEDED

Run: `swift test`
Expected: all tests pass

- [ ] **Step 2: Run required headless verification**

Run: `swift run phoneticsctl --headless seed-check`
Expected: `status=ok`

Run: `swift run phoneticsctl --headless smoke-test`
Expected: `status=ok`

Run: `swift run phoneticsctl --headless ui-screenshots`
Expected: `status=ok` plus stable `onboarding_png=` and `training_png=` paths

- [ ] **Step 3: Inspect generated PNG artifacts**

Run: `open <generated-onboarding.png> <generated-training.png>`
Expected: onboarding is transient and training stats/hints match the UI contract.

- [ ] **Step 4: Commit**

```bash
git add Resources/design-comparison.html
git commit -m "docs: update ui review artifacts if needed"
```

