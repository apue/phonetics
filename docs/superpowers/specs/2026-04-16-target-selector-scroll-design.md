# Target Selector Scroll Design

Date: 2026-04-16

## Goal

Fix the training target selector in the top-right corner so long target lists no longer appear clipped at the top or bottom.

## Approved Direction

Use the existing `popover` trigger, but restyle the popover to behave more like a compact menu:

- keep the current toolbar button entry point
- keep grouped targets
- replace large card-like rows with tighter menu-style rows
- make only the target list scroll
- keep the title and helper copy pinned above the scrollable region

## Scope

- update the training target selector presentation in `TrainingCardView`
- extract small selector section-building logic so grouping stays testable
- preserve existing selection behavior and current-target indicator

## Out Of Scope

- changing the training data model
- replacing the selector with a native `Menu`
- changing target ordering rules
