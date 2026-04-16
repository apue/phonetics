# Onboarding And Training UI Contract

**Date:** 2026-04-16

**Goal:** Replace the persistent welcome destination with one-time onboarding, refresh the training layout to match the approved native-editorial direction, and add deterministic screenshot verification so AI and humans can validate UI structure from generated images instead of inference.

## Context

The current app treats `Welcome` as a normal screen in the sidebar and defaults `AppViewModel.selectedScreen` to `.welcome`. This no longer matches the approved information architecture:

- `Training` is the persistent working area.
- onboarding is a transient state, not a permanent navigation destination.
- the training layout should express semantic relationships explicitly instead of relying on visual suggestion alone.

The current training card also has two layout problems that should be corrected:

- `CORRECT` duplicates information already encoded in `LISTENS` when rendered as `9/12`.
- practice hint text competes with controls instead of reading as tertiary guidance.

## Approved Product Decisions

### Navigation

- Remove the persistent `Welcome` destination from sidebar navigation.
- Default initialized sessions to `Training`.
- Show onboarding only when the user has not dismissed it yet.
- Keep `History` and `Settings` as persistent sidebar destinations.

### Onboarding Semantics

- Onboarding is a first-run overlay or modal-style detail state inside the app shell.
- Onboarding must not appear as a sidebar row.
- Dismissing onboarding once is persisted locally and future launches enter `Training`.
- If initialization is still running, onboarding content must not replace the existing initialization progress indication.

### Training Semantics

- The selected target controls practice context.
- Changing the selected target updates:
  - target highlight
  - selected target label
  - standard playback target
  - A/B loop target
  - practice contextual copy
- `Perception` and `Practice` remain sibling panels inside the current training card; neither panel owns global navigation.

### Information Hierarchy

- Primary actions:
  - `Random Test`
  - `Record` / `Stop Record`
  - `Next Card`
- Secondary actions:
  - `Standard`
  - `Me`
  - `Stop`
  - `A/B`
  - `Previous Card`
  - `Reload`
  - `Save`
  - `Hard`
- Tertiary information:
  - onboarding explanatory copy
  - training hint text
  - explanatory status copy beneath controls

### Stats Rules

- `LISTENS` and `CORRECT` must be separate absolute counts.
- The UI must not encode the same ratio twice.
- If accuracy is shown in the future, it must use a dedicated label such as `ACCURACY`.

## View Contract

### Root Shell

- The app continues using `NavigationSplitView`.
- Sidebar rows become:
  - `Training`
  - `History`
  - `Settings`
- The detail column shows:
  - onboarding overlay when `shouldShowOnboarding == true`
  - the selected destination content underneath

### Onboarding View

- Create a dedicated onboarding view rather than reusing the previous welcome view.
- The view contains:
  - one primary CTA to begin training
  - one secondary dismissal action
  - explanatory copy that explicitly says training is the default workspace after first run
- The view must feel like a transient introduction layered over the real app workspace.

### Training Layout

- Top region:
  - title and contrast metadata
  - `Save` and `Hard` actions aligned with the title block
  - two target cards with selected-target emphasis
- Middle region:
  - `Perception` panel on the left
  - `Practice` panel on the right
- Bottom region:
  - stats strip with `LISTENS`, `CORRECT`, `PRACTICES`, `TIME`
  - card navigation controls aligned after the stats strip
- Practice hint text:
  - below the control row
  - lighter than action labels
  - never on the same row as `Stop`

## Persistence Contract

- Persist onboarding dismissal in local app settings.
- Extend `AppSettings` with a Boolean flag for onboarding dismissal state.
- Existing settings defaults remain backward-compatible.
- Existing database rows must migrate without data loss.

## Verification Contract

### Automated Behavior

- Add tests proving:
  - initialized sessions default to `Training`
  - onboarding visibility depends on the persisted dismissal flag
  - dismissing onboarding updates persisted state
  - target selection still drives practice playback state

### Automated Visual Output

- Add a deterministic screenshot generation path driven by fixed UI fixtures.
- The renderer must generate at least:
  - onboarding screenshot
  - training screenshot
- Rendering requirements:
  - fixed window size
  - fixed seed data
  - fixed app state
  - stable output path

### Human/AI Review Loop

- Generated PNGs are part of verification output.
- AI review uses these PNGs plus the spec rules above, not screenshot-only intuition.
- Layout regressions should be discussed against the contract:
  - view role
  - control priority
  - dependency relationships
  - stats deduplication

## Out Of Scope

- no redesign of `History`
- no redesign of `Settings`
- no network sync
- no generalized design-token system
- no full snapshot-diff framework with image-baseline approval tooling
