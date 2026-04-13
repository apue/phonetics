# Phase 4 Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Phase 4 by shipping History, Settings, sidebar collapse, edge-case/error polish, and lightweight training-card animations as separate verifiable PR slices.

**Architecture:** Keep the existing MVVM + actor boundaries. Add read/query APIs to `DataService` for history summaries and settings persistence, keep views talking only to view models, and keep each Phase 4 slice independently shippable with its own tests and PR.

**Tech Stack:** SwiftUI, Observation (`@Observable`), Swift actors, GRDB, XCTest, GitHub Actions via `gh`

---

### Task 1: History Page Slice

**Files:**
- Create: `PhoneticsMaestro/Models/HistorySessionSummary.swift`
- Create: `PhoneticsMaestro/ViewModels/HistoryViewModel.swift`
- Modify: `PhoneticsMaestro/Services/DataService.swift`
- Modify: `PhoneticsMaestro/Views/History/HistoryView.swift`
- Modify: `PhoneticsMaestroTests/DataServiceTests.swift`
- Create: `PhoneticsMaestroTests/HistoryViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testFetchHistorySessionSummariesAggregatesByDate() async throws
func testLoadHistoryShowsMostRecentSessionsFirst() async
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter DataServiceTests && swift test --filter HistoryViewModelTests`
Expected: FAIL because history query/model/view model do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
struct HistorySessionSummary: Equatable, Sendable, Identifiable { ... }
@Observable final class HistoryViewModel { ... }
extension DataService { func fetchHistorySessionSummaries() throws -> [HistorySessionSummary] { ... } }
```

- [ ] **Step 4: Render the History screen**

```swift
HistoryView(viewModel: HistoryViewModel())
```

Show date, total time, total listens, accuracy ratio, and practice count. Use an empty state when no sessions exist.

- [ ] **Step 5: Run verification**

Run: `swift build && swift test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add PhoneticsMaestro/Models/HistorySessionSummary.swift \
  PhoneticsMaestro/ViewModels/HistoryViewModel.swift \
  PhoneticsMaestro/Services/DataService.swift \
  PhoneticsMaestro/Views/History/HistoryView.swift \
  PhoneticsMaestroTests/DataServiceTests.swift \
  PhoneticsMaestroTests/HistoryViewModelTests.swift
git commit -m "Add history summaries"
```

### Task 2: Settings Page Slice

**Files:**
- Create: `PhoneticsMaestro/Models/AppSettings.swift`
- Create: `PhoneticsMaestro/ViewModels/SettingsViewModel.swift`
- Modify: `PhoneticsMaestro/Services/DataService.swift`
- Modify: `PhoneticsMaestro/Views/Settings/SettingsView.swift`
- Modify: `PhoneticsMaestroTests/DataServiceTests.swift`
- Create: `PhoneticsMaestroTests/SettingsViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testFetchSettingsReturnsDefaultsBeforeFirstSave() async throws
func testUpdateSettingsPersistsVoiceMicrophoneAndABABInterval() async throws
func testLoadSettingsUsesPersistedValues() async
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter DataServiceTests && swift test --filter SettingsViewModelTests`
Expected: FAIL because settings storage/query APIs are missing.

- [ ] **Step 3: Write minimal implementation**

```swift
struct AppSettings: Equatable, Sendable { ... }
@Observable final class SettingsViewModel { ... }
extension DataService {
    func fetchSettings() throws -> AppSettings { ... }
    func updateSettings(_ settings: AppSettings) throws { ... }
}
```

- [ ] **Step 4: Render the Settings screen**

Use SwiftUI `Picker` / `Slider` controls for:
- TTS voice
- Microphone choice
- ABAB interval

Keep values local and persisted through `DataService`.

- [ ] **Step 5: Run verification**

Run: `swift build && swift test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add PhoneticsMaestro/Models/AppSettings.swift \
  PhoneticsMaestro/ViewModels/SettingsViewModel.swift \
  PhoneticsMaestro/Services/DataService.swift \
  PhoneticsMaestro/Views/Settings/SettingsView.swift \
  PhoneticsMaestroTests/DataServiceTests.swift \
  PhoneticsMaestroTests/SettingsViewModelTests.swift
git commit -m "Add settings screen and persistence"
```

### Task 3: Sidebar Collapse Slice

**Files:**
- Modify: `PhoneticsMaestro/ViewModels/AppViewModel.swift`
- Modify: `PhoneticsMaestro/App/RootView.swift`
- Modify: `PhoneticsMaestro/App/PhoneticsMaestroApp.swift`
- Create: `PhoneticsMaestroTests/AppViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testToggleSidebarUpdatesCollapsedState() async
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AppViewModelTests`
Expected: FAIL because sidebar state/toggle API do not exist.

- [ ] **Step 3: Write minimal implementation**

```swift
@Observable final class AppViewModel {
    var isSidebarCollapsed = false
    func toggleSidebar() { ... }
}
```

In `RootView`, bind sidebar visibility to `isSidebarCollapsed` and add `⌘+\\` keyboard shortcut.

- [ ] **Step 4: Run verification**

Run: `swift build && swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add PhoneticsMaestro/ViewModels/AppViewModel.swift \
  PhoneticsMaestro/App/RootView.swift \
  PhoneticsMaestro/App/PhoneticsMaestroApp.swift \
  PhoneticsMaestroTests/AppViewModelTests.swift
git commit -m "Add sidebar collapse controls"
```

### Task 4: Error Handling And Edge Cases Slice

**Files:**
- Modify: `PhoneticsMaestro/ViewModels/TrainingCardViewModel.swift`
- Modify: `PhoneticsMaestro/ViewModels/HistoryViewModel.swift`
- Modify: `PhoneticsMaestro/ViewModels/SettingsViewModel.swift`
- Modify: `PhoneticsMaestro/Views/Training/TrainingCardView.swift`
- Modify: `PhoneticsMaestro/Views/History/HistoryView.swift`
- Modify: `PhoneticsMaestro/Views/Settings/SettingsView.swift`
- Modify: `PhoneticsMaestroTests/TrainingCardViewModelTests.swift`
- Modify: `PhoneticsMaestroTests/HistoryViewModelTests.swift`
- Modify: `PhoneticsMaestroTests/SettingsViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testHistoryLoadFailureExposesErrorMessage() async
func testSettingsSaveFailureRestoresSavingState() async
func testTrainingNavigationStopsABABBeforeSwitchingCards() async
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter HistoryViewModelTests && swift test --filter SettingsViewModelTests && swift test --filter TrainingCardViewModelTests`
Expected: FAIL because these edge-case behaviors are not implemented.

- [ ] **Step 3: Write minimal implementation**

Add consistent alert/empty/disabled handling and ensure active playback/recording is safely stopped or blocked before state transitions that would leave the UI inconsistent.

- [ ] **Step 4: Run verification**

Run: `swift build && swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add PhoneticsMaestro/ViewModels/TrainingCardViewModel.swift \
  PhoneticsMaestro/ViewModels/HistoryViewModel.swift \
  PhoneticsMaestro/ViewModels/SettingsViewModel.swift \
  PhoneticsMaestro/Views/Training/TrainingCardView.swift \
  PhoneticsMaestro/Views/History/HistoryView.swift \
  PhoneticsMaestro/Views/Settings/SettingsView.swift \
  PhoneticsMaestroTests/TrainingCardViewModelTests.swift \
  PhoneticsMaestroTests/HistoryViewModelTests.swift \
  PhoneticsMaestroTests/SettingsViewModelTests.swift
git commit -m "Polish Phase 4 error handling"
```

### Task 5: Lightweight Animation Slice

**Files:**
- Modify: `PhoneticsMaestro/Views/Training/TrainingCardView.swift`
- Modify: `PhoneticsMaestro/ViewModels/TrainingCardViewModel.swift`
- Modify: `PhoneticsMaestroTests/TrainingCardViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testPerceptionFeedbackStateRemainsAvailableForHighlightAnimation() async throws
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter TrainingCardViewModelTests`
Expected: FAIL because the animation-driving state is not explicit enough.

- [ ] **Step 3: Write minimal implementation**

Use SwiftUI animations only for:
- record-button pulse while `isRecording == true`
- feedback highlight when `perceptionState` becomes `.correct` or `.incorrect`

Do not change unrelated layout or styling.

- [ ] **Step 4: Run verification**

Run: `swift build && swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add PhoneticsMaestro/Views/Training/TrainingCardView.swift \
  PhoneticsMaestro/ViewModels/TrainingCardViewModel.swift \
  PhoneticsMaestroTests/TrainingCardViewModelTests.swift
git commit -m "Add training card feedback animations"
```

### Task 6: Phase 4 Completion Handoff

**Files:**
- Create: `docs/handoff-2026-04-13-<time>-codex.md`

- [ ] **Step 1: Verify final main state**

Run: `swift build && swift test`
Expected: PASS on `main`

- [ ] **Step 2: Write handoff note**

Capture merged PRs, current main SHA, completed Phase 4 items, known residual risks, and next steps for post-Phase-4 work.

- [ ] **Step 3: Commit**

```bash
git add docs/handoff-2026-04-13-<time>-codex.md
git commit -m "Add Phase 4 handoff note"
```
