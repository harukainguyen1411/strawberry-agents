# ADR phase-split after resolutions

**Date:** 2026-04-19
**Context:** Usage dashboard subagent-task attribution ADR amendments.

## Lesson

When Duong folds in resolutions to an open-questions ADR, the right default is inline Resolved-YYYY-MM-DD annotations (not deletion) plus a top-level Resolutions Log summary. This preserves reviewer auditability: a future reader can see both the decision and the question it answered, without scrolling to a killed section.

But a second lesson came mid-close: if the prerequisite task (hook amendment for `closed_cleanly`) has a materially different risk profile from the presentation layer (UI Panel 5), the ADR should be phase-split even after resolutions are folded in. The scenario here: the hook amendment stops ongoing signal loss (`/tmp` sentinels evaporating on reboot), while the UI is pure ergonomics. Shipping them as one atomic unit would gate the capture fix on UI completion and continue leaking `closed_cleanly` signal during the UI build.

## Rule

Prefer a "Phases" section (v1 / v2 tables of scope) over reordering decisions or re-numbering Ds. Each phase gets its own scope table; handoff task slices partition accordingly (T0-T2 under v1, T3-T4 under v2). Include an "accepted risk of v1-without-v2" paragraph that justifies the split by comparing to the v0 status quo — not to the eventual v2 ideal.

## Reference

- `plans/proposed/2026-04-19-usage-dashboard-subagent-task-attribution.md` — Phases section added post-resolution.
- Commits: `61bef3b` (resolutions folded), `a4265f0` (phase split added).
