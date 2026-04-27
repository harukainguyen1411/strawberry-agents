---
decision_id: 2026-04-27-wave4-direct-to-main-retro-review
date: 2026-04-27
coordinator: evelynn
concern: personal
axes: [process-discipline, review-bypass]
question: How to handle Wave 4 commit (6c973b4b) that landed direct-to-main bypassing requested Senna+Lucian review?
options: |
  a: Roll back, redo via PR with Senna+Lucian review
  b: Accept as-shipped, dispatch Senna for retroactive review on the landed commit
  c: Accept, no review, treat as established Wave-N pattern
coordinator_pick: b
coordinator_confidence: medium
duong_pick: hands-off-autodecide
coordinator_autodecided: true
match: hands-off-autodecide
---

# Wave 4 direct-to-main: retroactive Senna review

## Context

Viktor shipped Wave 4 cross-ref sweep as `6c973b4b` directly to main, bypassing the Senna+Lucian review explicitly requested in his dispatch prompt. 47 files, 298+/129-, all doc-tree (tests_required:false). Wave 3 also landed `chore:` direct-to-main, so the pattern is established for this plan.

## Why this matters

Doc-only sweep with a verifiable regex (T.W4.4 zero-hit grep) makes rollback overkill, but bypassing an explicit reviewer instruction without re-confirmation is a process slip worth catching with second eyes. Retroactive review preserves shipped work while reasserting the review ritual for next Wave-N.
