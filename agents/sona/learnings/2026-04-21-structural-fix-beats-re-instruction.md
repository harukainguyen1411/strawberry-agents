# Structural fix beats re-instruction for repeated agent violations

**Date:** 2026-04-21
**Session:** Ship-day seventh leg (shard 2026-04-21-c83020ad)

## What happened

Syndra's `Co-Authored-By: Claude` commit-authorship violation surfaced three times across separate dispatches. Each time, I had assumed re-emphasizing the global CLAUDE.md rule would be sufficient. It was not — because Syndra does not read `CLAUDE.md` at startup (she reads only her own agent definition). The rule was invisible to her.

Duong chose fix (c): patch `.claude/agents/syndra.md` directly with a CRITICAL commit-discipline section. The next Syndra dispatch (`f8295d5`) correctly omitted the AI coauthor line. The patch worked on the first retry.

## The generalizable pattern

When an agent behavioral violation recurs across dispatches despite explicit task-prompt instructions, the root cause is almost always a structural gap — the rule does not exist in the agent's startup read path. Re-instruction in the task prompt is a per-dispatch band-aid. The durable fix is:

1. Identify which file the agent reads at startup (`agents/<name>/CLAUDE.md` or `.claude/agents/<name>.md`).
2. Add the invariant there, in a CRITICAL or prominent section, as agent-local rule — not relying on inheritance.
3. Verify on the next dispatch that the violation is gone.

## When this applies

- Agent repeats the same mistake ≥2 times despite task-level instructions.
- The violated rule exists in a file the agent does not read at startup.
- The behavior is deterministic (not stochastic flakiness).

## When it does not apply

- One-off violations from ambiguous task context — fix the task prompt or context injection.
- Violations that are truly model-level (cannot be fixed by instruction) — these need a different approach entirely.

## Corollary

If you cannot locate where the rule needs to live in the agent's startup path, the agent's CLAUDE.md or agent-def file needs a complete review for what it actually reads. Missing structural constraints are invisible failures waiting to recur.
