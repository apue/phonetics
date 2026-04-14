# Dual-Entry Launch Design

Date: 2026-04-14
Project: Phonetics Maestro
Status: Proposed

## Goal

Support two stable ways to run the product without splitting business logic:

1. A standard macOS `.app` that users can open by double-clicking or from Xcode.
2. A CLI entry point that agents and developers can use for launch, verification, and future automation.

The first implementation only needs headless acceptance/regression commands. It does not need GUI scripting, audio-device automation, packaging, or notarization.

## Problem Statement

The current project is built as a Swift Package executable. It compiles and tests successfully from the CLI, but when launched from Xcode it does not run as a standard macOS app bundle. The executable currently lacks a main app bundle with a stable `CFBundleIdentifier`, which leads to incomplete macOS app behavior and unreliable GUI launch semantics.

This is the wrong runtime shape for the final user-facing product even though it is sufficient for compilation and unit testing.

## Requirements

### Functional

- Users can launch a normal macOS application bundle.
- Developers and agents can build from the CLI.
- Developers and agents can run headless acceptance/regression commands from the CLI.
- A single CLI surface can expose both GUI launch and headless verification entry points.

### Non-Functional

- Shared business logic must remain single-source, not duplicated between app and CLI.
- Headless commands must avoid fragile dependencies on microphone permissions, TTS playback, or active desktop UI.
- Existing `swift build` and `swift test` workflows must continue to work.
- The migration should be incremental and PR-sliced.

## Proposed Architecture

### Module Layout

- `PhoneticsCore`
  - Shared models
  - Shared services
  - Shared view models
  - Shared SwiftUI views where practical
- `PhoneticsMaestroApp`
  - `@main` app entry
  - Scene/window lifecycle
  - App bundle metadata
- `phoneticsctl`
  - Argument parsing
  - `--gui` dispatch
  - `--headless` acceptance/regression commands

### Ownership Boundaries

- `PhoneticsCore` owns app behavior and domain logic.
- `PhoneticsMaestroApp` owns bundle identity, launch experience, and standard macOS app behavior.
- `phoneticsctl` owns automation-oriented command dispatch and machine-readable output.

### Runtime Behavior

- Double-clicking `PhoneticsMaestro.app` launches the standard GUI app.
- Running `phoneticsctl --gui` launches the same GUI app via the app bundle, not via an in-process SwiftUI bootstrap.
- Running `phoneticsctl --headless <command>` executes acceptance/regression commands without creating a user window.

## Headless Command Design

First version supports only three commands:

### `phoneticsctl --headless seed-check`

Purpose:

- Verify bundled seed resources exist.
- Verify database initialization succeeds.
- Verify imported counts are non-zero where expected.

Expected checks:

- Resources load successfully.
- Database file can be created/opened.
- Seed import path completes.
- Pair and sentence counts are both greater than zero.

### `phoneticsctl --headless db-summary`

Purpose:

- Provide a lightweight snapshot for agents and humans.

Expected output:

- Database path
- Pair count
- Sentence count
- Session summary count
- Persisted settings presence/state summary

### `phoneticsctl --headless smoke-test`

Purpose:

- Run a lightweight end-to-end acceptance sweep without UI or audio-device requirements.

Expected checks:

- Initialize local data store.
- Fetch at least one training pair.
- Exercise History query path.
- Exercise Settings fetch path.
- Return pass/fail plus a compact summary.

## Explicit Non-Goals

This design does not include:

- GUI automation
- Headless microphone recording
- Headless TTS playback verification
- DMG generation, notarization, or release packaging
- New product features unrelated to launch shape and verification

## Migration Plan

### Slice 1: App Host

- Introduce a standard macOS app target with bundle metadata.
- Ensure Xcode Run and double-click launch use the app bundle.
- Keep current behavior functionally unchanged.

### Slice 2: Shared Core

- Move shared code into `PhoneticsCore`.
- Make both app and CLI depend on the same core module.
- Preserve existing tests.

### Slice 3: CLI Host

- Add `phoneticsctl`.
- Add `--gui`.
- Add `--headless seed-check`, `db-summary`, and `smoke-test`.

### Slice 4: Documentation

- Update README launch instructions.
- Update AGENTS workflow to include headless verification commands where appropriate.
- Write handoff note after merge completion.

## Validation Strategy

### Automated

- `swift build`
- `swift test`
- `phoneticsctl --headless seed-check`
- `phoneticsctl --headless smoke-test`

### Manual

- Run app from Xcode and confirm a real window appears.
- Launch `.app` directly from Finder and confirm standard app behavior.
- Run `phoneticsctl --gui` and confirm it launches the same app bundle.

## Risks

### Target Restructuring Risk

Moving package code into a shared target may surface import or resource-path issues.

Mitigation:

- Move code incrementally.
- Keep test coverage green after each slice.

### Resource Access Risk

Seed data and app resources may behave differently between app and CLI hosts.

Mitigation:

- Centralize resource-loading behavior in the shared core.
- Add explicit seed-check acceptance coverage.

### Automation Drift Risk

Headless commands may become stale if they are not used in normal development flow.

Mitigation:

- Add them to the standard verification workflow for agent-driven tasks.
