# PR #30 — Orianna v2 simplification: plan fidelity review

**Date:** 2026-04-23
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/30
**Plan:** `plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md`
**Verdict:** APPROVE

## What I learned

### Archive-don't-delete verification technique
`git diff --name-status main..HEAD | grep -E '^(D|R)'` cleanly separates renames (R100) from pure deletions. For archive-mandate tasks, R100 is the structural proof that history follows. Pure D entries need case-by-case justification.

### Don't trust working-tree grep for branch sweep verification
Initial grep for `orianna_gate_version` hit my local working tree and flagged `plans/_template.md` + a work-scope-reviewer plan as sweep misses. Both were clean on the actual branch tip — the dirty local state was unrelated uncommitted work. Always `git show <branch>:<file>` for branch-content assertions.

### Rule 12 (xfail-first) verification shortcut
`git log --oneline main..HEAD` in task-labeled commit order: the T<N> xfail test task's commit must appear *before* any implementation task's commit. On this PR: 7248c94 (T8 xfail) → then all T1/T2/T3/T4/T5/T6/T7 impl commits. Clean pattern.

### Merge-base drift vs scope creep
The PR's `gh pr view --json files` showed unrelated file deletions (ekko learnings, residuals-and-risks files) that were NOT in any of the branch's own commits. These come from sibling branches merged to main after this branch was cut. Use `git log --oneline <base>..<branch> -- <path>` to distinguish: if the branch never touched the file, it's merge-base drift, non-blocking.

## Review body structure that worked
- Per-task PASS/FAIL with one-line evidence (commit SHA or grep result)
- Separate "Notes (non-blocking)" section for drift I want logged
- Sign with `-- reviewer (Lucian, plan & ADR fidelity)` — generic role tag compatible with work-scope anonymity habits even though this is personal concern
