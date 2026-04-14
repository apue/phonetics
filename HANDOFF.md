# HANDOFF.md — Agent Handoff Protocol

## Purpose

This document defines the standard handoff format when work transfers between agents, or when an agent session ends due to rate limits, context exhaustion, or manual interruption.

Use this protocol for deltas. For the baseline repository description, read `docs/current-state.md`.

## When to Generate a Handoff Note

An agent **MUST** generate a handoff note file in the following situations:

1. **Session end:** Before the session ends for any reason.
2. **Blocker encountered:** When hitting an issue that requires human decision or a different agent's expertise.
3. **Multi-step task pause:** When work is intentionally paused between implementation slices, PRs, or review cycles.
4. **Meaningful project milestone:** When a task materially changes runtime structure, workflow, or the user-visible baseline.

## Handoff Note Format

Create file: `docs/handoff-{YYYY-MM-DD}-{HHmm}-{agent}.md`

Where `{agent}` is `cc` (Claude Code) or `codex`.

```markdown
# Handoff Note — {date} {time}

## Agent
{Claude Code | Codex} — Session #{n}

## Status
{✅ Complete | 🔶 In Progress | 🔴 Blocked}

## Completed Work
- [ ] Item 1 (file: path/to/file)
- [ ] Item 2 (file: path/to/file)

## Current State
- Branch: `{branch-name}`
- Last commit: `{hash} — {message}`
- Build status: {✅ Builds | ❌ Build error: description}
- Test status: {✅ All pass | ❌ N failures: description}
- Verification status: {✅ Headless acceptance passes | ❌ command failure: description}

## In Progress (Incomplete)
- What was being worked on when session ended
- Current file being edited: `{path}`
- What remains to finish this item

## Known Issues
- Issue 1: description + file:line if applicable
- Issue 2: description

## Blockers (Needs Human Decision)
- Decision needed: {description}
- Options considered: A) ... B) ...

## Next Steps (For Receiving Agent)
1. First thing to do
2. Second thing to do
3. ...

## Files Modified This Session
```
git diff --name-only {start-commit}..HEAD
```
```

## How to Resume From a Handoff

When starting a new session and a handoff note exists, the receiving agent should:

1. Read `AGENTS.md`.
2. Read `docs/current-state.md`.
3. Read this file (`HANDOFF.md`) for the protocol.
4. Read the latest relevant `docs/handoff-*.md` file.
5. Run the standard verification chain:
   - `swift build`
   - `swift test`
   - `swift run phoneticsctl --headless seed-check`
   - `swift run phoneticsctl --headless smoke-test`
6. Continue from the "Next Steps" section of the handoff note.

### Resume Prompt Template

```text
Read AGENTS.md, docs/current-state.md, HANDOFF.md, and the latest relevant handoff note in docs/.
Run the standard verification chain.
Continue from the recorded next steps.
```

## Handoff Between Different Agents

- Ensure the receiving agent can see the latest verified repo state.
- If there is an open PR, record the PR number and whether checks/review are pending.
- If there are local-only changes, state that explicitly.
- The handoff note is the delta contract. Do not rely on unwritten conversational context from the previous session.
