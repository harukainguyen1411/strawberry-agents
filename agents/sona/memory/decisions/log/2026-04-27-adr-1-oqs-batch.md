---
decision_id: 2026-04-27-adr-1-oqs-batch
date: 2026-04-27
coordinator: sona
concern: work
axes: [scope-vs-debt, explicit-vs-implicit]
question: Resolve 8 OQs in Swain's ADR-1 (Build progress bar) plan — step-name copy, component placement, dwell time, failed-state dismiss, SSE-blocked polling fallback, indeterminate UX, hand-off to ADR-2, trigger-tool reconciliation lane
options:
  composite_picks: "1a 2a 3a 4a 5b 6a 7a 8c"
  rationale: "Conservative happy-path-v1 picks across the board; all align with Swain's recommended defaults; #5 explicitly defers SSE polling fallback to v2 since single-user happy-path environment doesn't strip SSE; #8 keeps trigger-tool reconciliation in ADR-5's sanity-sweep lane to keep ADR-1 strictly UI-wiring."
coordinator_pick: "1a 2a 3a 4a 5b 6a 7a 8c"
coordinator_confidence: high
duong_pick: hands-off-autodecide
coordinator_autodecided: true
predict: "1a 2a 3a 4a 5b 6a 7a 8c"
match: true
concurred: false
---

## Context

Hands-off mode (default track) per Duong directive 2026-04-27. Duong: "Those are low cost decisions that you can made without me" — explicit autodecide grant for the 8-question OQ batch on ADR-1.

Swain returned the ADR-1 plan with 7 architectural OQs, each carrying his own conservative recommended default. I added an 8th meta-question on trigger-tool reconciliation lane (does the `trigger_factory` agent-tool removal live in ADR-1, ADR-3, or ADR-5). All 8 are low-cost, reversible UI/UX choices except #8 which is purely a project-level lane assignment.

## Why this matters

Hands-off mode means coordinator picks per learned preferences (simple yet clean and works; lean a; only c when debt is cheap to repay later). Picks 1–7 went a (Swain's defaults); 5 went b (defer-to-v2 for the SSE polling fallback — happy-path-v1 doesn't need defensive code without a known failure mode); 8 went c (ADR-5 was sized for exactly this kind of reconciliation; pulling into ADR-1 would inflate the scope of a UI-only ADR).

Followup: messaging Swain in-team to amend the plan with these resolutions. Plan advances proposed → Orianna gate → approved → Aphelios breakdown after amend.
