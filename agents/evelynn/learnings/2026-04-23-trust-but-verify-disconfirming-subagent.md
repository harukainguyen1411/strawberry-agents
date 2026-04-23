# Trust-but-verify on disconfirming subagent findings

**Date:** 2026-04-23
**Trigger:** Ekko returned a result contradicting the frozen deployed S2 contract, causing unnecessary re-dispatch and confusion.

## Lesson

When a subagent's result contradicts:
- Prior established facts (memory, prior shard state)
- Duong's stated expectation
- A parallel agent's result on the same artifact

Do NOT act on it immediately. Re-verify via a **distinct method** before ruling. A second subagent dispatch using the same method does not count as independent verification — it can produce the same misleading result. Prefer direct probes: curl against deployed URL, Bash inspection of the live artifact, live query against the deployed system.

## Pattern

1. Subagent returns result X.
2. X contradicts established context.
3. **Before acting**: verify via a different probe method.
4. Only after confirmation: act on the finding or override.

## Codified in

`agents/evelynn/CLAUDE.md` and `agents/sona/CLAUDE.md` (commit `f50c173`).

## Related

- `2026-04-20-band-aid-scope-trap.md` — Similar class of "check systemic vs. incident before acting."
- `2026-04-18-empirical-before-ruling-and-standing-auth-trap.md` — Empirical check before ruling.
