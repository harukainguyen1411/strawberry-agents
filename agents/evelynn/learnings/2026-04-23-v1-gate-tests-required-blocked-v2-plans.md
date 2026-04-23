# v1 gate `tests_required: true` + no `kind: test` task blocked plan promotions before v2 landed

**Date:** 2026-04-23
**Session:** c4af884e (shard c95a8d3b)

## What happened

Both the memory-flow simplification ADR and the Orianna v2 simplification plan hit a promotion block under the v1 gate: `tests_required: true` was set in frontmatter but no task carried `kind: test`. The v1 structure hook enforced this combination as an error. Both plans promoted cleanly once PR #30 landed and the v2 gate replaced the v1 structure hook.

## Lesson

**The v1 `tests_required: true` + `kind: test` task requirement was a blunt enforcement rule that created catch-22s for infrastructure/meta plans** (which may not have discrete "test" tasks in the traditional sense). The v2 gate removed this rule. When authoring plans under v1 (before PR #30), either include at least one `kind: test` task or omit `tests_required: true`.

Since PR #30 is now merged, this rule is obsolete for new plans. Existing v1 plans in proposed/ may still carry the field; if they surface during promotion, a field edit resolves it.

## References

- PR #30 (`add2027`) — Orianna v2 gate simplification
- `plans/in-progress/personal/2026-04-23-memory-flow-simplification.md`
