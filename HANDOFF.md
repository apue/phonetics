# HANDOFF.md — Agent Handoff Protocol

## Purpose

This document defines the standard handoff format when work transfers between agents (Claude Code ↔ Codex), or when an agent session ends due to rate limits, context exhaustion, or manual interruption.

## When to Generate a Handoff Note

An agent **MUST** generate a handoff note file in the following situations:

1. **Phase completion:** After completing any phase defined in `requirements.md §6`.
2. **Session end:** Before the session ends for any reason (rate limit, context full, user request).
3. **Blocker encountered:** When hitting an issue that requires human decision or a different agent's expertise.

## Handoff Note Format

Create file: `docs/handoff-{YYYY-MM-DD}-{HHmm}-{agent}.md`

Where `{agent}` is `cc` (Claude Code) or `codex`.

```markdown
# Handoff Note — {date} {time}

## Agent
{Claude Code | Codex} — Session #{n}

## Status
{✅ Phase N Complete | 🔶 Phase N In Progress | 🔴 Blocked}

## Completed Work
- [ ] Item 1 (file: path/to/file)
- [ ] Item 2 (file: path/to/file)

## Current State
- Branch: `{branch-name}`
- Last commit: `{hash} — {message}`
- Build status: {✅ Builds | ❌ Build error: description}
- Test status: {✅ All pass | ❌ N failures: description}

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

1. Read this file (`HANDOFF.md`) for the protocol.
2. Read the latest `docs/handoff-*.md` file.
3. Read `AGENTS.md` for project conventions.
4. Run `swift build` to verify current state.
5. Run `swift test` to verify test state.
6. Continue from the "Next Steps" section of the handoff note.

### Resume Prompt Template

```
Read HANDOFF.md, then read the latest handoff note in docs/.
Verify the build and test state. Continue from where the previous agent left off.
```

## Handoff Between Different Agents

When switching between Claude Code and Codex specifically:

- **CC → Codex:** Ensure all changes are committed. Codex runs in a sandbox and needs clean git state.
- **Codex → CC:** Codex may have created a PR or committed to a branch. CC should pull latest and read the handoff note.
- **Both:** The handoff note is the contract. Do not assume context from the previous session beyond what's written in the note.
