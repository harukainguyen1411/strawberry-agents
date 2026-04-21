# Phase Discipline: `approved/` vs `in-progress/`

**Date:** 2026-04-21
**Reporter:** Sona (self-critique; surfaced by Duong's challenge)
**Severity:** Process sloppiness, not a rule violation — but user-facing confusion worth fixing.

## What happened

Three work ADRs (MAD, MAL, BD) were Orianna-signed at the `approved` phase and lived in `plans/approved/work/`. I dispatched implementation work — Vi xfail tests, Jayce + Viktor + Seraphine impl — against them while they were still in `approved/`. The `approved → in-progress` phase flip never ran until Duong asked why the folder was wrong.

## Why this was confusing

From Duong's view, "in-progress" is the label that announces "work is actively happening." Seeing plans sit in `approved/` while impl is landing on branches looks like work-without-approval. Even though the rule allows it, the signal is mixed.

## What the rule actually says

`agents/sona/CLAUDE.md#rule-sona-sonnet-needs-plan`:

> ensure there is an approved plan in `plans/approved/work/` **or** `plans/in-progress/work/` covering the work

Both phases are valid. `approved/` is the source of truth that "this is greenlit to implement." `in-progress/` is the operational state that "we are implementing it right now." Implementation against `approved/` does not violate the rule — but it does create a phase-vs-reality drift.

## The norm I should enforce going forward

**When I dispatch the first implementation-track agent (xfail tester, builder, errand runner) against an approved ADR, I flip that ADR to `in-progress/` in the same coordinator turn.** Not after the first agent reports back — at dispatch time. The phase should lead or match reality, never lag.

Mechanically:

1. Dispatch Yuumi (or run the promotion myself if policy allows) with `scripts/plan-promote.sh <plan>` before or immediately alongside the first implementation dispatch.
2. If the `approved → in_progress` Orianna signing surfaces findings, pause dispatches on that ADR and resolve them first — this is exactly the gate the lifecycle exists for.
3. Task-track the promotion as its own step.

## Why this slipped today

Momentum. "Make use of time" + hands-off mode pushed me to dispatch the next parallel agent on every notification. Phase-discipline is a coordinator bookkeeping step, not a value-generating one in the moment, so it got skipped. That's the failure mode — bookkeeping is invisible until it breaks.

## Mitigation ideas

- **Checklist on first implementation dispatch per ADR:** before spawning an impl agent, confirm the ADR is in `in-progress/`; if not, promote first.
- **Hook:** a coordinator-side PreToolUse hook could check that any Agent dispatch referencing a plan path in `plans/approved/` triggers a reminder to promote.
- **Convention tightening:** add one line to `#rule-sona-sonnet-needs-plan` noting that `approved/` is valid to reference but should be promoted at first implementation dispatch, and `in-progress/` is the correct phase for active work.

## My call (hands-off)

Adopt the "flip at first-impl-dispatch" norm immediately. I won't touch `CLAUDE.md` or hooks right now — memory-level discipline plus this feedback doc is enough signal. If the same mistake recurs, it earns a hook.
