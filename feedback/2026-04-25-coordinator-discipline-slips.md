---
date: 2026-04-25
time: "07:44"
author: evelynn
concern: personal
category: coordinator-discipline
severity: medium
friction_cost_minutes: 20
related_plan: plans/approved/personal/2026-04-25-coordinator-routing-discipline.md
related_pr:
related_commit:
related_feedback: []
state: open
---

# Coordinator-discipline slips during cornerstone-plan execution chain

**Date:** 2026-04-25
**Author:** Evelynn (self-reported)
**Concern:** personal
**Severity:** medium
**Category:** coordinator-discipline
**Slug:** coordinator-discipline-slips
**State:** open

## What went wrong

Three distinct slips during today's cornerstone-plan execution chain (retrospection-dashboard + agent-feedback-system + coordinator-decision-feedback). All three are the same cognitive shape — fast pattern-match defeating a structural pause that exists for the failure mode.

### Slip 1 — wrong-lane impl dispatch (Talon for Swain plan)

I dispatched Talon (quick-lane, paired with Karma's plans only) to implement Phase 1 of the retrospection-dashboard plan, which is Swain-authored (Opus complex-track ADR). Per `plans/in-progress/2026-04-20-agent-pair-taxonomy.md`, complex-track plans go to Viktor (build) + Rakan (test impl). Caught only when Duong asked "Why Talon? Isn't it Swain lane?" Killed task #67 (`af6a768bbd497758d`) mid-flight; ~5 min of Talon's work discarded.

### Slip 2 — incomplete pair dispatch (Viktor without Rakan)

Course-correcting from Slip 1, I prepared a Viktor dispatch as if Viktor alone covered the impl chain. Per Rule 12 + complex-track pair structure, Rakan ships xfail test code first, Viktor ships impl second, both on same branch. Caught when Duong said "this lane includes Viktor and Rakan. Please do your job more carefully." No agent dispatched yet, so no work discarded.

### Slip 3 — compact-watch missed

After Orianna promoted the routing-discipline plan (`74d6d5c4`), the in-flight queue was at plateau (only Rakan running on a long task). Sona's standing FYI directs me to Slack-ping Duong at clean compact windows BEFORE running `/pre-compact-save`. I instead auto-dispatched Talon for the routing-discipline impl, pushing the window further out. Caught when Duong asked "did you forget about the clean compact window?"

## Suggestion

Three observations:

1. **Pair-taxonomy data is machine-readable** (per Lux's memo `4b0ab6cf` §1) — `tier:`, `pair_mate:`, `role_slot:` on every agent def, `owner:` on every plan. The gap is glue, not data. Karma's plan `e67818a6` (now approved at `74d6d5c4`) ships A+B (cheat-sheet + routing-check primitive) for Slips 1+2. Lux explicitly defers option C (PreToolUse `Agent` hook) to a post-canonical-v1-retro decision — gates it on whether A+B's coordinator-self-discipline approach actually closes the gap.

2. **Slip 3 is a different surface that A+B do NOT cover.** Compact-watch is not a routing decision; it's a queue-state discipline. The structural fix shape would be either (a) a hook that watches in-flight task count + recent dispatch rate and emits a "clean compact window detected" event, or (b) extending the routing-check primitive to include a third pause: "is the in-flight queue at plateau? If yes, has Slack-ping fired and `/pre-compact-save` run before this dispatch?" Both deferred until canonical-v1-retro.

3. **All three slips share root cause: auto-mode + ship-today bias defeating structural pauses.** The deliberation primitive (`_shared/coordinator-intent-check.md`) targets state-mutating tool calls but does not specifically target dispatch decisions or queue-state decisions. The new routing-check primitive (Talon impl in flight as task #72, branch `talon/coordinator-routing-discipline`) targets dispatch routing. Compact-watch remains uncovered.

## Why I'm writing this now

- Today's session has produced three coordinator-discipline slips, more than any prior session. Pattern is real.
- The agent-feedback-system plan is approved + breakdown + test-plan complete (Plan A); not yet implemented. Once T1 of Plan A ships, this file is the canonical migration target for ad-hoc → schema-conformant feedback. Writing it now ensures the evidence persists across the imminent `/compact` boundary.
- The canonical-v1 retro (Saturday post-Phase-2-ship of dashboard) is the reckoning point where A+B's effectiveness will be measured. This entry is the baseline data for that measurement: three slips on the day before retro infrastructure ships.
- Duong's directive: "remember it" (verbatim).

## Related

- `plans/approved/personal/2026-04-25-coordinator-routing-discipline.md` — the structural fix for Slips 1+2 (in-flight Talon impl, task #72)
- `assessments/research/2026-04-25-coordinator-routing-discipline.md` — Lux's memo (`4b0ab6cf`)
- `plans/in-progress/2026-04-20-agent-pair-taxonomy.md` — canonical taxonomy
- `agents/evelynn/inbox/20260425-0744-103099.md` — Sona's earlier inbox warning shape (Akali QA confabulation, similar root-cause shape: distributed knowledge + cognitive shortcut under pressure)
- `feedback/2026-04-22-coordinator-verify-qa-claims.md` — sibling discipline slip from earlier in week
