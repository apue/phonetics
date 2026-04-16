# Training Target Selector Refresh

**Date:** 2026-04-16

**Goal:** Add the approved training target selector, unify pair-backed and sentence-backed training into one training workspace, refresh the shell semantics to match `Begin / History / Settings`, and add a screen-reading-style verification path on top of deterministic screenshots.

## Context

The approved product contract now has three gaps relative to the running app:

- the training page has no target selector and is still pair-only
- the sidebar still exposes `Training` instead of the approved `Begin` semantics and does not summarize the current target
- screenshot verification exists, but there is no accessibility-style readout of what the rendered UI actually exposes

The repository already has seed sentences, sentence persistence, screenshot rendering, and stable headless commands. What is missing is the domain glue between these layers.

## Approved Product Decisions

### Navigation Semantics

- Keep `NavigationSplitView` as the shell.
- Rename the working destination label from `Training` to `Begin`.
- Keep the one-time onboarding overlay behavior already shipped.
- Add a sidebar summary region that shows:
  - current target summary
  - current session listens/correct
  - current elapsed time

### Unified Training Target Model

- Introduce one selector catalog that drives the training screen regardless of source data.
- The selector exposes three visible groups:
  - `Sound Contrasts`
  - `Linking / Reduction`
  - `Stress / Intonation`
- Every selector row is a concrete training target, not a tier label.

### Pair-Backed Targets

- Pair-backed targets are grouped by `phonemeContrast`.
- Each target summary uses:
  - title: contrast label such as `ʌ-æ`
  - subtitle: first example such as `but / bat`
  - group: `Sound Contrasts`
- Navigating within a pair-backed target moves across the pairs belonging to that contrast only.

### Sentence-Backed Targets

- Sentence-backed targets use the existing sentence seed data and must still fit the current A/B training shell.
- To preserve the same `Perception` and `Practice` interaction without creating a second UI path, sentence targets are materialized as sentence comparison cards:
  - each card still provides left/right labels and optional IPA
  - cards are derived from ordered sentence rows inside a phenomenon group
- Group mapping is:
  - `linking` and `reduction` -> `Linking / Reduction`
  - `stress` and `intonation` -> `Stress / Intonation`
- For the current seed set, each phenomenon has two rows, so the derived comparison card is stable and deterministic.
- This is an explicit product inference used to satisfy the approved selector contract with the data that exists today.

### Training Card Contract

- Keep the current perception/practice split.
- Add a `Target` menu/popover button in the header.
- Switching targets changes only the current data source and resets card navigation to the first card in that target.
- `Prev` and `Next` operate within the selected target’s card list only.
- `Reload` resets to the first card of the selected target.
- Preserve:
  - random test
  - left/right answer buttons
  - record toggle
  - standard playback
  - user-recording playback
  - shared stop
  - A/B looping
  - save/hard tagging
  - keyboard shortcuts

### Sentence Card Display Rules

- Sentence-backed cards still render two targets labeled `A` and `B`.
- The header metadata and target selector summary should name the phenomenon rather than exposing raw storage values.
- If IPA is missing for a side, the view hides the IPA line for that side instead of showing placeholder text.

### Shell Visual Contract

- Sidebar rows become:
  - `Begin`
  - `History`
  - `Settings`
- While `Begin` is selected, the sidebar also shows current target and session summary cards.
- The detail view header aligns:
  - title and explanatory copy on the left
  - `Target`, `Save`, and `Hard` controls on the right

### Playback Controls

- Add explicit A/B speed selection in the practice section:
  - `0.75x`
  - `1.0x`
  - `1.25x`
- The selected speed applies to:
  - standard playback in practice
  - user recording playback in practice
  - A/B loop playback
- Random test remains fixed at normal speed.
- Existing ABAB interval settings remain supported and continue to control the silence duration.

### Persistence Contract

- Save/hard and session stats persist against the currently displayed training card item.
- Pair-backed cards persist with `item_type = 'pair'`.
- Sentence-backed cards persist with `item_type = 'sentence'` and the sentence-backed card’s primary sentence id.
- Recording filenames also use the active item type/id so pair and sentence recordings remain distinct.

## Architecture

### Domain Layer

- Add a selector-summary model for sidebar/header presentation.
- Add a training-card model that normalizes pair-backed and sentence-backed cards into one renderable payload.
- Keep `PhonePair` and `Sentence` as persistence models; do not overload them with selector-only display concerns.

### Data Service Layer

- Extend `TrainingDataServing` with generic training-target APIs:
  - fetch target catalog
  - fetch card list for a target
  - fetch progress/tag state for generic `itemType` + `itemID`
  - update progress/tag state for generic `itemType` + `itemID`
- Keep existing pair APIs only if needed for headless backward compatibility; new training flow should use the generic APIs.

### View Model Layer

- Replace pair-only screen state with:
  - selected target
  - target catalog
  - current card list
  - current card index
- Preserve `PairOption` for left/right selection because the training shell still reasons about A/B targets.
- Add derived values for:
  - current target summary
  - current card payload
  - A/B playback rate

### View Layer

- Refresh the training layout to match the editorial standard more closely:
  - header action cluster
  - emphasized selected target card
  - unified bottom stats strip
  - navigation controls trailing after stats
- Use native SwiftUI controls; no custom drawing framework.

## Verification Contract

### Automated Behavior

- Add tests for:
  - target catalog grouping
  - sentence-backed target materialization
  - target switching resets to the first card in that target
  - prev/next navigation stays inside the selected target
  - generic progress/tag persistence works for sentence-backed items
  - playback rate selection affects practice playback and A/B loop

### Automated UI Output

- Keep `swift run phoneticsctl --headless ui-screenshots` as the deterministic renderer path.
- Update the fixed fixture state so the generated training screenshot reflects the new target selector layout and sidebar summaries.

### Screen-Reading Verification

- Add a deterministic textual readout command derived from the rendered UI screenshots.
- The readout is OCR-based, not accessibility-tree based, because the repo has no UI-test/accessibility harness today.
- The command must emit stable text sections for:
  - onboarding screenshot
  - training screenshot
- Verification checks compare the readout against expected structural phrases such as:
  - `Begin`
  - `Target:`
  - `Perception`
  - `Practice`
  - `LISTENS`
  - `CORRECT`
  - `PRACTICES`
  - `TIME`

## Out Of Scope

- no redesign of `History`
- no redesign of `Settings` beyond preserving existing ABAB interval behavior
- no full native accessibility automation harness
- no new seed data schema
- no network or remote sync
