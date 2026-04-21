# Fact-check skips angle-bracket placeholder paths — only concrete paths need markers

## Context

Writing an ADR with many path references like `agents/<coordinator>/memory/decisions/preferences.md`. Nearly went to mark each one with `<!-- orianna: ok -->` for fact-check cleanliness, but noticed the approved memory-consolidation plan uses identical patterns without markers.

## Lesson

`scripts/fact-check-plan.sh` (line 328) auto-skips any extracted token matching `*<*>*` — template placeholders like `<coordinator>`, `<agent>`, `<uuid>`, `<name>`. Also auto-skips `*YYYY*|*MM-DD*|*-XX-*|*-XX.*` date templates.

Concrete implication for ADR authorship: **only add `<!-- orianna: ok -->` markers on prospective paths that are concrete** (no angle brackets in the path itself). Examples:

- `.claude/skills/decision-capture/SKILL.md` — concrete, needs marker
- `scripts/_lib_decision_capture.sh` — concrete, needs marker
- `agents/<coordinator>/memory/decisions/preferences.md` — has placeholder, auto-skipped, NO marker needed
- `agents/evelynn/memory/decisions/axes.md` — concrete, needs marker (or mention that it's T8-bootstrap)
- `last-sessions/<uuid>.md` — has placeholder, auto-skipped

## Generalisation

Before marking every prospective path, check what the fact-checker actually extracts. Over-marking is not free: it adds visual noise and trains the author to reach for the marker reflexively instead of verifying path validity. The fact-checker is friendly to placeholder-heavy documentation; trust it.

## Related

- `scripts/fact-check-plan.sh` §324-331 (placeholder skip rules).
- `scripts/_lib_orianna_gate_implemented.sh` §59-61 (marker suppression for existing paths).
- Prior learning: `2026-04-20-plan-claim-decay.md` covered the inverse — paths that decay because the repo moves. Placeholders are immune to that decay by being non-literal.
