# Maintainability Refactor Design

## Goal

Reduce duplication and cross-layer coupling in the current runtime without changing user-facing behavior.

## Scope

This refactor is intentionally limited to three structural problems identified in review:

1. Training playback and recording UI state is tracked through several overlapping booleans in `TrainingCardViewModel`, while `AudioService` already owns the runtime audio state machine.
2. `AppViewModel` still hard-codes startup initialization to `DataService.shared`, which weakens dependency injection and makes top-level startup logic harder to test.
3. `DataService` repeats pair-loading SQL and keeps training/history/settings persistence concerns tightly packed together.

## Non-Goals

- No user-facing workflow changes
- No database schema changes
- No new runtime entry points
- No new external dependencies

## Design

### 1. Training interaction state

`TrainingCardViewModel` will replace its overlapping playback booleans with one view-model state enum that represents the current training interaction:

- `idle`
- `recording`
- `playing(control: TrainingPlaybackControl)`

The existing UI booleans remain as computed properties derived from this enum so the SwiftUI layer does not need a large rewrite. The view model will still choose which control initiated playback, but it will no longer maintain parallel playback bookkeeping through several mutable flags.

`AudioService` remains the source of truth for legal audio transitions. The view model's interaction state becomes the single UI-level source of truth for rendering, while service transitions stay in the service.

### 2. App initialization boundary

Introduce a tiny startup protocol for app initialization, implemented by `DataService`. `AppViewModel` will depend on that protocol instead of directly invoking `DataService.shared.initialize()`.

This keeps startup orchestration in `AppViewModel`, while moving the concrete persistence dependency behind an injected boundary that tests can replace.

### 3. Data access reuse

Keep `DataService` as the shared actor for now, but refactor its internal pair-loading implementation so the shared pair projection query is defined once and reused by next/previous/first/last fetch helpers.

This does not fully split the service into multiple actors yet. It is a targeted decomposition that lowers duplication immediately without forcing a broad repository rewrite.

## Testing Strategy

Add tests that prove the refactor boundaries:

- `AppViewModel` uses an injected initializer service instead of the global singleton.
- `TrainingCardViewModel` exposes one interaction state and keeps derived UI flags consistent during playback and recording transitions.
- Existing `DataService` tests continue passing after pair query extraction; no behavior change is expected there unless a helper-specific regression test is needed.

## Risks

- The training view model already has broad responsibility; this refactor must avoid turning a cleanup into a behavior change.
- Playback state updates are async, so tests need to assert state before and after controlled playback completion.
- The data access cleanup should stop short of large-scale storage redesign in this PR.
