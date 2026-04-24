# Hands-off slow-track means "cleanest option," not "serial"

**Date:** 2026-04-24
**Severity:** high
**last_used:** 2026-04-24

## What happened

Duong set "go hands-off slow track" with an explicit P1→P2→P3 priority order. Initial interpretation was "not in a hurry = work serially." Duong corrected this directly.

## The rule

Slow-track governs **decision quality**, not **throughput**.

- "Cleanest option always" — prefer the tidier architectural path, the safer merge strategy, the better-scoped PR.
- Parallelism preference is **unchanged** — dispatch independent tasks in parallel as usual.
- "Not in a hurry" ≠ "serial." Serial dispatch is an overnight/autonomous-session pattern (see `2026-04-22-serial-dispatch-overnight-sessions.md`), not a slow-track consequence.

## Operationally

When Duong enters hands-off slow-track mode:
1. Run the cleanest option at each decision point, not the fastest.
2. Continue dispatching independent agents in parallel.
3. Escalate only genuine blockers via Slack (attention-only signal).
4. Carry open threads forward; don't rush to close them.

## Source

`agents/memory/duong.md` §Operating Modes — canonical copy. This learning is the behaviorally internalized form.
