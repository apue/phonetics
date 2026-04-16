# Training Playback Interaction Design

Date: 2026-04-16
Project: Phonetics Maestro
Status: Approved for planning

## Goal

Make Training card playback interactions consistent and interruptible:

- the two target cards at the top can be clicked to play pronunciation
- only one playback interaction can be active at a time
- a new playback request interrupts the current playback and starts immediately
- `A/B` remains a toggle loop
- the page exposes an explicit stop control

## Problem Statement

The current Training screen has multiple audio entry points, but they do not follow one interaction model.

- The target cards only change `selectedPracticeTarget`; they do not play audio.
- Playback conflicts are currently handled mostly by `AudioService` rejecting non-idle playback requests.
- That produces the wrong user experience for this page. The user expectation is not "error on overlap"; it is "new click interrupts old playback."

This makes the Training screen feel inconsistent even though the underlying state machine is explicit and testable.

## Functional Requirements

### Target Cards

- Clicking the left or right target card must:
  - select that target as the current practice target
  - immediately play that target's standard pronunciation
- Clicking the same target card while it is already playing must restart playback from the beginning.

### Single-Playback Rule

- Training must allow only one active playback interaction at a time.
- The following interactions are part of the same playback system:
  - target-card pronunciation
  - `Random Test`
  - incorrect-answer automatic replay
  - `Standard`
  - `Me`
  - `A/B`

### Interrupt Behavior

- Starting a new single-playback action while another playback is running must:
  - stop the active playback
  - start the new playback immediately
- Starting `A/B` while a single-playback action is running must:
  - stop the active playback
  - start the loop
- Starting a single-playback action while `A/B` is running must:
  - stop the loop
  - start the new playback

### Stop Control

- Training must expose a `Stop` control for the current page.
- `Stop` must stop any current playback and return the page to a neutral playback state.
- `Esc` should trigger the same stop action.

### Recording Boundary

- Starting recording while playback is active must stop playback before recording begins.
- While recording is active, playback controls must remain unavailable.
- Playback must not auto-start during an active recording session.

## Non-Goals

- No changes outside the Training screen flow.
- No audio queueing or simultaneous playback.
- No new third-party dependencies.
- No changes to session-stat meaning:
  - `LISTENS` still belongs to `Random Test`
  - `PRACTICES` still increments when a recording attempt is saved

## Interaction Model

### Single-Playback Controls

These controls always mean "play from the beginning":

- target-card click
- `Random Test`
- incorrect-answer automatic replay
- `Standard`
- `Me`

If one of these controls is activated while any playback is active, the current playback is interrupted first.

### Loop Control

`A/B` keeps toggle semantics:

- first click starts the loop
- second click stops the loop

`A/B` still participates in the same interrupt system as the single-playback controls.

### Selection Versus Playback

The target cards now do two things together:

1. update `selectedPracticeTarget`
2. trigger standard pronunciation playback for that target

This keeps the card interaction direct and avoids separate "select" and "play" affordances for the same visible unit.

## Service-Level Design

`AudioService` remains the single audio coordinator and keeps the responsibility for enforcing legal recording and playback state transitions.

The behavioral change is:

- playback requests become interruptible when the current state is playback
- playback requests remain illegal when the current state is recording
- recording start becomes interruptible with respect to playback

### Recommended State Shape

Use one playback state model for all playback sources:

- `idle`
- `recording(recordingURL:)`
- `playing(source:)`

Extend `AudioPlaybackSource` to include the loop case:

- `.standard`
- `.userRecording`
- `.randomTest`
- `.ababLoop`

This removes the need for a separate `playingABAB` top-level state and makes playback-state inspection simpler for tests and UI coordination.

### Service Rules

- `playStandard`
- `playRandomTest`
- `playUserRecording`
- `startABABLoop`

All four APIs must:

- interrupt current playback if the service is already in a playback state
- throw `illegalTransition` if the service is in a recording state

`startRecording` must:

- interrupt current playback if the service is already in a playback state
- remain illegal if the service is already recording

`stop()` must:

- stop TTS playback
- stop file playback
- cancel the `A/B` task if active
- return the service to `idle`

## ViewModel Design

`TrainingCardViewModel` remains the boundary between view intent and `AudioService`.

### New Or Updated ViewModel APIs

- `tapTargetCard(_ option: PairOption) async`
- `playRandomTest() async throws`
- `submitPerceptionGuess(_ guess: PairOption) async`
- `playSelectedStandard() async throws`
- `playUserRecording() async throws`
- `toggleABABLoop() async throws`
- `stopPlayback() async`
- `toggleRecording() async throws`

### ViewModel Playback UI State

The view model should track page-level playback UI state separately from `AudioService` internals so the view can show clear affordances.

Recommended UI-facing state:

- whether playback is currently active
- which Training control initiated the current playback

This state is for view rendering only. The service still owns real audio coordination.

## View Design

### Target Cards

- Keep the existing card layout.
- Change the click action from "select only" to "select and play."
- Preserve selected-target highlighting.
- Add lightweight playback feedback if practical, but do not block delivery on richer animation.

### Practice Controls

- Add a `Stop` button alongside `Standard`, `Me`, and `A/B`.
- `Stop` is enabled only while playback is active.

### Copy Updates

- Update helper text so it reflects that target cards can be clicked to preview pronunciation.
- Keep existing record-state and `A/B` status messaging, but make stop/reset behavior explicit where needed.

## Error Handling

Normal playback interruption is not an error and must not surface an alert.

Alerts should remain reserved for genuine failures:

- no pair loaded
- missing user recording for `Me` or `A/B`
- microphone permission denied
- underlying playback or recording failure

## Validation Criteria

### Unit Tests

`AudioServiceTests` must cover:

- playback interruption by another playback request
- `A/B` interrupted by single-playback request
- single-playback interrupted by `A/B`
- recording start interrupting playback
- recording still rejecting playback requests while active

`TrainingCardViewModelTests` must cover:

- target-card tap selects and plays
- repeated taps restart the latest requested card playback path
- `Stop` delegates to audio stop and clears playback UI state
- recording start stops active playback first

### Manual Validation

- Clicking either target card speaks that word.
- Rapidly clicking between target cards never leaves overlapping audio.
- `Standard`, `Me`, `Random Test`, and `A/B` interrupt each other predictably.
- `Stop` and `Esc` stop current playback.
- Recording disables playback controls and stops active playback before recording begins.

## Delivery Risks

### State Drift Risk

The page-level playback indicator can drift from service state if view model updates are only partially synchronized.

Mitigation:

- keep service interruption logic centralized
- update the view model through a small number of audio entry points
- cover transitions with unit tests

### Loop Cancellation Risk

`A/B` loop cancellation can leave stale UI state if stop and completion paths diverge.

Mitigation:

- route all loop shutdown through `stop()`
- make `toggleABABLoop()` and `stopPlayback()` normalize loop flags the same way
