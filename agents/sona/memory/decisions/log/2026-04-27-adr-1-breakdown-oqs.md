---
decision_id: 2026-04-27-adr-1-breakdown-oqs
date: 2026-04-27
coordinator: sona
concern: work
axes: [scope-vs-debt, explicit-vs-implicit]
question: Resolve 4 micro-OQs surfaced during Aphelios + Xayah ADR-1 breakdown (translator surface shape, /build-status multi-reload caching, color-shift mechanism, fixture-naming coupling)
options:
  composite_picks: "X1=pre-parsed-event-object | X2=no-cache | X3=classList.replace explicit | K1=defer-to-impl-no-upfront-contract"
  rationale: "All four are micro-architecture edges with clear defaults: cleaner separation (X1), simplicity-first happy-path-v1 (X2), align with existing QA FAIL guard (X3), trust impl-pair to reconcile in-line (K1)."
coordinator_pick: "X1=pre-parsed | X2=no-cache | X3=classList.replace | K1=impl-time"
coordinator_confidence: high
duong_pick: hands-off-autodecide
coordinator_autodecided: true
predict: same
match: true
concurred: false
---

## Context

Hands-off mode default track. Aphelios and Xayah returned ADR-1 breakdown + test plan in parallel. Three Xayah-flagged ambiguities (X1/X2/X3) plus one Aphelios-flagged coupling (K1 / "OQ-K1") all sit at the granularity of a single line in the plan body — no architectural rework, just resolve and bake.

## Resolutions

- **X1 — translator surface shape (D2):** `applyEvent(event)` takes a **pre-parsed event object** (`{type, step?, totalSteps?, name?, error?}`), not a raw SSE string. The frontend EventSource layer parses; the translator transforms. Cleaner separation, easier unit testing.
- **X2 — `/build-status` multi-reload caching (D6):** **No caching.** Two reloads in 5 seconds = two upstream factory calls. Single-user happy-path v1 doesn't need defensive caching. Add a one-line note to D6 making this explicit; defer cache to v2 if real-world traffic justifies it.
- **X3 — color-shift mechanism (T9, QA Plan):** Explicit `classList.replace('progress--build', 'progress--verify')` in T9 detail. Matches the QA Plan FAIL guard which already forbids `replaceChild` on the same DOM node. Hoist the mechanism into T9 so impl pair has it without re-reading QA Plan.
- **K1 — fixture-naming / mock-factory coupling (Aphelios T6/T7 ↔ Xayah TX-*):** **Defer to impl-time.** Both Aphelios and Xayah independently used `TX-` prefix; both reference the same plan §QA Plan. No upfront contract needed; Rakan reads both sections and unifies fixture names inline during xfail authoring. Document expectation in T6 detail.

## Why this matters

These are line-level micro-decisions that would otherwise stall the impl dispatch waiting for Swain or Duong. Hands-off default track explicitly authorizes coordinator to make them. The decision log records each pick so the audit trail survives.
