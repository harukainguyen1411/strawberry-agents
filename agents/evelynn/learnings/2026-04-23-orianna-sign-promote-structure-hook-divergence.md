# 2026-04-23 — orianna-sign.sh vs plan-promote.sh structure-hook divergence

## What happened

During Orianna v2 plan promotion, `scripts/orianna-sign.sh` returned APPROVE (fact-check passed, Orianna was satisfied). However, `scripts/plan-promote.sh` subsequently blocked on the structure hook (`lib-plan-structure`) with a different validation failure. The two validators do not share state and check orthogonal things: the fact-check agent checks semantic content, the structure hook checks file-shape invariants (frontmatter fields, section presence, etc.).

## The lesson

`orianna-sign.sh` APPROVE is necessary but not sufficient for `plan-promote.sh` to succeed. Structure-hook failures are independent of signature status. When promote blocks despite a valid sign:
1. Read the structure-hook error output carefully — it names the exact missing field or section.
2. Fix the structural deficiency, re-sign, then promote again.
3. If the blocker is mechanical and the semantic approval is genuine, use admin `Orianna-Bypass` trailer after two failed attempts rather than running the re-sign treadmill (per `2026-04-22-orianna-bypass-over-resign-treadmill.md`).

## Why this matters

The memory-flow simplification ADR (`plans/proposed/personal/2026-04-23-memory-flow-simplification.md`) is specifically designed to collapse the plan-lifecycle machinery that produces this divergence. Until that ADR executes, the divergence is a live friction surface on every plan promotion.

## Related

- `agents/evelynn/learnings/2026-04-22-orianna-bypass-over-resign-treadmill.md`
- `agents/evelynn/learnings/2026-04-21-orianna-bypass-sig-only-not-structure.md`
- `plans/approved/personal/2026-04-22-orianna-gate-simplification.md`
