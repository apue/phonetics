# Training Playback Interaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add interruptible Training playback so target cards speak on click, all page playback interactions share one interruption model, and the Training page exposes an explicit stop control.

**Architecture:** Keep `AudioService` as the single audio coordinator, but change playback behavior from "reject overlap" to "interrupt current playback unless recording is active." Add a small Training-specific playback UI state in the view model so the view can show active source, wire target-card taps through the view model, and surface a shared `Stop` action plus `Esc` shortcut.

**Tech Stack:** Swift 5.9, SwiftUI, Observation, Swift actors, AVFoundation, XCTest

---

### Task 1: Make Audio Playback Interruptible In `AudioService`

**Files:**
- Modify: `PhoneticsMaestro/Services/AudioPlaybackSource.swift`
- Modify: `PhoneticsMaestro/Services/AudioState.swift`
- Modify: `PhoneticsMaestro/ViewModels/TrainingAudioServing.swift`
- Modify: `PhoneticsMaestro/Services/AudioService.swift`
- Test: `PhoneticsMaestroTests/AudioServiceTests.swift`

- [ ] **Step 1: Add failing service tests for interruption behavior**

Add these tests to `PhoneticsMaestroTests/AudioServiceTests.swift`:

```swift
func testPlayStandardInterruptsCurrentPlaybackAndStartsNewSpeech() async throws {
    let platform = MockAudioPlatformClient(playbackMode: .controlled)
    let service = AudioService(platformClient: platform)

    let firstPlayback = Task {
        try await service.playRandomTest(options: ["but", "bat"])
    }

    await platform.waitUntilPlaybackStarts(count: 1)

    let secondPlayback = Task {
        try await service.playStandard(for: "luck")
    }

    await platform.waitUntilPlaybackStarts(count: 2)
    await platform.completePlayback()

    let spokenTexts = await platform.spokenTexts()
    let stopCount = await platform.stopPlaybackCallCount()

    _ = try await firstPlayback.value
    try await secondPlayback.value

    let state = await service.currentState()
    XCTAssertEqual(spokenTexts, ["but", "luck"])
    XCTAssertGreaterThanOrEqual(stopCount, 1)
    XCTAssertEqual(state, .idle)
}

func testStartRecordingStopsPlaybackBeforeEnteringRecording() async throws {
    let platform = MockAudioPlatformClient(playbackMode: .controlled)
    let appSupportURL = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: appSupportURL) }

    let service = AudioService(
        platformClient: platform,
        fileManager: .default,
        appSupportURL: appSupportURL
    )

    let firstPlayback = Task {
        try await service.playStandard(for: "bat")
    }

    await platform.waitUntilPlaybackStarts(count: 1)
    let recordingURL = try await service.startRecording(
        itemType: "pair",
        itemID: 1,
        attempt: 1,
        sessionDate: "2026-04-16"
    )

    _ = try await firstPlayback.value
    XCTAssertEqual(await platform.stopPlaybackCallCount(), 1)
    XCTAssertEqual(await service.currentState(), .recording(recordingURL: recordingURL))
}
```

Also replace the playback-start helper in `MockAudioPlatformClient` with a count-aware version:

```swift
private var playbackStartCount = 0

func playSpeech(text: String, voiceIdentifier _: String?, rate _: Float) async throws {
    speechTexts.append(text)
    playbackStartCount += 1
    playbackStartedContinuation?.resume()
    playbackStartedContinuation = nil
    try await waitForPlaybackIfNeeded()
}

func playAudioFile(at url: URL, rate _: Float) async throws {
    audioFilePlaybackCountValue += 1
    fileURLs.insert(url.path)
    playbackStartCount += 1
    playbackStartedContinuation?.resume()
    playbackStartedContinuation = nil
    try await waitForPlaybackIfNeeded()
}

func waitUntilPlaybackStarts(count: Int) async {
    if playbackStartCount >= count {
        return
    }

    await withCheckedContinuation { continuation in
        playbackStartedContinuation = continuation
    }
}
```

- [ ] **Step 2: Run the focused service tests and confirm failure**

Run:

```bash
swift test --filter AudioServiceTests
```

Expected: FAIL because the current implementation throws `illegalTransition` instead of interrupting active playback.

- [ ] **Step 3: Normalize playback state definitions**

Update `PhoneticsMaestro/Services/AudioPlaybackSource.swift`:

```swift
enum AudioPlaybackSource: Equatable, Sendable {
    case standard
    case userRecording
    case randomTest
    case ababLoop
}
```

Update `PhoneticsMaestro/Services/AudioState.swift`:

```swift
import Foundation

enum AudioState: Equatable, Sendable {
    case idle
    case recording(recordingURL: URL)
    case playing(source: AudioPlaybackSource)
}
```

Update `PhoneticsMaestro/ViewModels/TrainingAudioServing.swift`:

```swift
import Foundation

protocol TrainingAudioServing: Sendable {
    func currentState() async -> AudioState
    func playRandomTest(options: [String]) async throws -> Int
    func playStandard(for text: String) async throws
    func startRecording(itemType: String, itemID: Int64, attempt: Int, sessionDate: String) async throws -> URL
    func stopRecording() async throws -> URL
    func playUserRecording() async throws
    func startABABLoop(standardText: String) async throws
    func stop() async
}
```

- [ ] **Step 4: Rework `AudioService` to interrupt playback instead of rejecting it**

Update `PhoneticsMaestro/Services/AudioService.swift` so playback requests and recording start use one interruption helper:

```swift
private func prepareForPlayback(action: String, source: AudioPlaybackSource) async throws {
    switch state {
    case .idle:
        transition(to: .playing(source: source))
    case .recording:
        throw AudioServiceError.illegalTransition(currentState: state, attemptedAction: action)
    case .playing:
        await stop()
        transition(to: .playing(source: source))
    }
}

private func prepareForRecording(action: String) async throws {
    switch state {
    case .idle:
        return
    case .recording:
        throw AudioServiceError.illegalTransition(currentState: state, attemptedAction: action)
    case .playing:
        await stop()
    }
}
```

Use the helpers from:

```swift
func startRecording(...) async throws -> URL
func playStandard(for text: String, voiceIdentifier: String? = nil, rate: Float = 1.0) async throws
func playRandomTest(...) async throws -> Int
func playUserRecording(rate: Float = 1.0) async throws
func startABABLoop(...) async throws
```

Set `startABABLoop` to:

```swift
transition(to: .playing(source: .ababLoop))
```

And simplify `stop()` to:

```swift
func stop() async {
    ababTask?.cancel()
    ababTask = nil
    await platformClient.stopPlayback()

    if case .playing = state {
        transition(to: .idle)
    }
}
```

- [ ] **Step 5: Extend the service tests to cover loop interruption**

Add one more test in `PhoneticsMaestroTests/AudioServiceTests.swift`:

```swift
func testStartABABLoopInterruptsSinglePlayback() async throws {
    let platform = MockAudioPlatformClient(playbackMode: .controlled)
    let appSupportURL = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: appSupportURL) }

    let service = AudioService(
        platformClient: platform,
        fileManager: .default,
        appSupportURL: appSupportURL
    )

    _ = try await service.startRecording(
        itemType: "pair",
        itemID: 7,
        attempt: 1,
        sessionDate: "2026-04-16"
    )
    _ = try await service.stopRecording()

    let firstPlayback = Task {
        try await service.playStandard(for: "luck")
    }

    await platform.waitUntilPlaybackStarts(count: 1)
    try await service.startABABLoop(standardText: "lock", silenceNanoseconds: 1_000_000)

    _ = try await firstPlayback.value
    XCTAssertEqual(await service.currentState(), .playing(source: .ababLoop))
    XCTAssertGreaterThanOrEqual(await platform.stopPlaybackCallCount(), 1)
}
```

- [ ] **Step 6: Run service verification**

Run:

```bash
swift test --filter AudioServiceTests
```

Expected: PASS. Playback overlap tests now pass without alert-style errors.

- [ ] **Step 7: Commit**

```bash
git add PhoneticsMaestro/Services/AudioPlaybackSource.swift \
  PhoneticsMaestro/Services/AudioState.swift \
  PhoneticsMaestro/ViewModels/TrainingAudioServing.swift \
  PhoneticsMaestro/Services/AudioService.swift \
  PhoneticsMaestroTests/AudioServiceTests.swift
git commit -m "Make training audio playback interruptible"
```

### Task 2: Add Training Playback UI State And ViewModel Entry Points

**Files:**
- Create: `PhoneticsMaestro/Models/TrainingPlaybackControl.swift`
- Modify: `PhoneticsMaestro/ViewModels/TrainingCardViewModel.swift`
- Test: `PhoneticsMaestroTests/TrainingCardViewModelTests.swift`

- [ ] **Step 1: Add failing view-model tests for card tap and stop behavior**

Add these tests to `PhoneticsMaestroTests/TrainingCardViewModelTests.swift`:

```swift
func testTapTargetCardSelectsTargetAndPlaysStandard() async throws {
    let audioService = MockTrainingAudioService(randomTestIndex: 0)
    let viewModel = TrainingCardViewModel(
        dataService: MockTrainingDataService(),
        audioService: audioService
    )

    await viewModel.loadInitialPairIfNeeded()
    await viewModel.tapTargetCard(.right)

    XCTAssertEqual(viewModel.selectedPracticeTarget, .right)
    XCTAssertEqual(await audioService.standardPlaybackRequests(), ["bat"])
}

func testStopPlaybackDelegatesToAudioServiceAndClearsPlaybackState() async throws {
    let audioService = MockTrainingAudioService(randomTestIndex: 0)
    let viewModel = TrainingCardViewModel(
        dataService: MockTrainingDataService(),
        audioService: audioService
    )

    await viewModel.loadInitialPairIfNeeded()
    await viewModel.tapTargetCard(.left)
    await viewModel.stopPlayback()

    XCTAssertNil(viewModel.activePlaybackControl)
    XCTAssertFalse(viewModel.isPlaybackActive)
    XCTAssertEqual(await audioService.stopCallCount(), 1)
}
```

- [ ] **Step 2: Run the focused view-model tests and confirm failure**

Run:

```bash
swift test --filter TrainingCardViewModelTests
```

Expected: FAIL because the new API and playback UI state do not exist yet.

- [ ] **Step 3: Add a focused playback-state model**

Create `PhoneticsMaestro/Models/TrainingPlaybackControl.swift`:

```swift
import Foundation

enum TrainingPlaybackControl: Equatable, Sendable {
    case targetCard(PairOption)
    case randomTest
    case practiceStandard(PairOption)
    case userRecording
    case ababLoop(PairOption)
}
```

- [ ] **Step 4: Update `TrainingCardViewModel` to own page playback state**

Add these properties near the other observable state in `PhoneticsMaestro/ViewModels/TrainingCardViewModel.swift`:

```swift
var activePlaybackControl: TrainingPlaybackControl?
var isPlaybackActive = false
```

Add the new target-card action:

```swift
func tapTargetCard(_ option: PairOption) async {
    guard let currentPair else {
        errorMessage = "Load a training pair before playback."
        return
    }

    selectedPracticeTarget = option

    do {
        activePlaybackControl = .targetCard(option)
        isPlaybackActive = true
        try await audioService.playStandard(for: text(for: option, pair: currentPair))
    } catch {
        errorMessage = error.localizedDescription
    }

    if activePlaybackControl == .targetCard(option) {
        activePlaybackControl = nil
        isPlaybackActive = false
    }
}
```

Update the other playback methods so they set and clear `activePlaybackControl` in one place:

```swift
private func runPlayback(
    control: TrainingPlaybackControl,
    operation: @escaping () async throws -> Void
) async throws {
    activePlaybackControl = control
    isPlaybackActive = true

    do {
        try await operation()
    } catch {
        activePlaybackControl = nil
        isPlaybackActive = false
        throw error
    }

    if activePlaybackControl == control {
        activePlaybackControl = nil
        isPlaybackActive = false
    }
}
```

Update `toggleRecording()` so start-recording clears active playback UI state before setting `isRecording = true`:

```swift
activePlaybackControl = nil
isPlaybackActive = false
```

Update `stopPlayback()` to normalize both the service and view-model state:

```swift
func stopPlayback() async {
    await audioService.stop()
    activePlaybackControl = nil
    isPlaybackActive = false
    isABABLooping = false
}
```

- [ ] **Step 5: Extend the test double to support the new protocol surface**

Update `MockTrainingAudioService` in `PhoneticsMaestroTests/TrainingCardViewModelTests.swift`:

```swift
private var currentAudioState: AudioState = .idle

func currentState() async -> AudioState {
    currentAudioState
}

func playStandard(for text: String) async throws {
    currentAudioState = .playing(source: .standard)
    standardRequests.append(text)
    currentAudioState = .idle
}

func startABABLoop(standardText: String) async throws {
    currentAudioState = .playing(source: .ababLoop)
    ababRequests.append(standardText)
}

func stop() async {
    currentAudioState = .idle
    stopCount += 1
}
```

- [ ] **Step 6: Run view-model verification**

Run:

```bash
swift test --filter TrainingCardViewModelTests
```

Expected: PASS. The view model now exposes page playback state and card-tap playback behavior.

- [ ] **Step 7: Commit**

```bash
git add PhoneticsMaestro/Models/TrainingPlaybackControl.swift \
  PhoneticsMaestro/ViewModels/TrainingCardViewModel.swift \
  PhoneticsMaestroTests/TrainingCardViewModelTests.swift
git commit -m "Add training playback UI coordination"
```

### Task 3: Wire The Training View To The New Playback Model

**Files:**
- Modify: `PhoneticsMaestro/Views/Training/TrainingCardView.swift`

- [ ] **Step 1: Replace target-card selection-only clicks with select-and-play**

Update the `Button` action inside `targetCard(label:title:ipa:option:)` in `PhoneticsMaestro/Views/Training/TrainingCardView.swift`:

```swift
Button {
    Task {
        await viewModel.tapTargetCard(option)
    }
} label: {
    VStack(alignment: .leading, spacing: 8) {
        Text(label)
            .font(.headline.monospaced())
            .foregroundStyle(.secondary)

        Text(title)
            .font(.system(size: 34, weight: .semibold))

        Text(ipa)
            .font(.title3.monospaced())
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: 260, alignment: .leading)
    .padding(24)
    .background(targetBackground(for: option), in: RoundedRectangle(cornerRadius: 16))
}
```

- [ ] **Step 2: Add a shared `Stop` button and `Esc` shortcut**

Add the new button to the practice controls group:

```swift
Button("Stop") {
    Task {
        await viewModel.stopPlayback()
    }
}
.buttonStyle(.bordered)
.disabled(!viewModel.isPlaybackActive)
.keyboardShortcut(.escape, modifiers: [])
```

- [ ] **Step 3: Surface playback-aware helper text**

Update the page helper text near the navigation buttons:

```swift
Text("Click either target card to hear its pronunciation. The selected target is used by Standard and A/B playback.")
    .font(.callout)
    .foregroundStyle(.secondary)
```

Update `practiceFeedbackText` to mention the shared stop behavior:

```swift
if viewModel.isABABLooping {
    return "ABAB comparison is running for the selected target. Use Stop or A/B to end it."
}

if viewModel.isPlaybackActive {
    return "Playback is active. Use Stop or start another playback action to interrupt it."
}
```

- [ ] **Step 4: Add lightweight playback highlighting**

Extend `targetBackground(for:)`:

```swift
private func targetBackground(for option: PairOption) -> some ShapeStyle {
    if viewModel.activePlaybackControl == .targetCard(option) {
        return Color.green.opacity(0.18)
    }

    if viewModel.selectedPracticeTarget == option {
        return Color.accentColor.opacity(0.2)
    }

    return Color.secondary.opacity(0.12)
}
```

- [ ] **Step 5: Run focused UI-impact verification**

Run:

```bash
swift test --filter TrainingCardViewModelTests
swift test --filter AudioServiceTests
```

Expected: PASS. The view compiles against the new view-model API and all playback tests still pass.

- [ ] **Step 6: Commit**

```bash
git add PhoneticsMaestro/Views/Training/TrainingCardView.swift
git commit -m "Wire training playback controls into the view"
```

### Task 4: Update Current-State Documentation And Run Full Verification

**Files:**
- Modify: `docs/current-state.md`

- [ ] **Step 1: Update the Training feature summary**

In `docs/current-state.md`, replace the Training bullets:

```md
- minimal-pair card with text and IPA for left/right targets
- target cards are clickable and play standard pronunciation
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
  - shared stop control
  - interruptible playback between all Training audio actions
```

- [ ] **Step 2: Run the full verification chain**

Run:

```bash
swift build
swift test
swift run phoneticsctl --headless seed-check
swift run phoneticsctl --headless smoke-test
```

Expected: PASS. No regressions in package build, unit coverage, or headless acceptance flow.

- [ ] **Step 3: Manual GUI verification**

Run the app and verify:

```bash
swift run phoneticsctl --gui
```

Check these behaviors manually:

- clicking left and right target cards plays the correct word
- clicking one playback control interrupts the previous one
- `A/B` toggles on and off correctly
- `Stop` and `Esc` stop active playback
- recording begins only after active playback stops

- [ ] **Step 4: Commit**

```bash
git add docs/current-state.md
git commit -m "Document training playback interaction updates"
```
