# CLAUDE.md — Phonetics Maestro (Claude Code Config)

## Project Conventions
@AGENTS.md

## Full Requirements
@requirements.md

## Architecture Reference
@ARCHITECTURE.md

## Handoff Protocol
@HANDOFF.md

## Claude Code Specific Rules

### Working Style
- **Discuss before implement.** For any architectural decision not covered in ARCHITECTURE.md, explain your plan and wait for approval before writing code.
- **Incremental commits.** Commit after each logical unit of work. Do not accumulate large uncommitted changes.
- **Test as you go.** After implementing a service method, write a test before moving to the next method.

### Context Management
- When compacting, preserve: current phase, list of modified files, any open issues, and the ABAB audio state machine specification.
- If context exceeds 50%, run `/compact` proactively with focus on the current phase's remaining tasks.

### Handoff
- Before ending a session, ALWAYS generate a handoff note per `HANDOFF.md`.
- If you sense approaching rate limits (slower responses, repeated compaction), generate the handoff note immediately rather than risk losing state.

### Audio Code Safety
- IMPORTANT: Never call `AVAudioEngine.start()` or `AVAudioSession` methods outside of `AudioService`. All audio operations must go through the actor.
- When testing audio code, always check for simulator vs real device — the simulator has limited audio support.
