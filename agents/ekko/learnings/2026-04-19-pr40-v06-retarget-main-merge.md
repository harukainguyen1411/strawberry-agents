# 2026-04-19 — PR #40 V0.6 retarget + main merge

## What happened

PR #40 (V0.6 T212 CSV parser) had base `feature/portfolio-v0-V0.5-money-fx` (dead/closed).

1. Retargeted base to `main` via REST API (`gh pr edit` GraphQL endpoint was flaking; `gh api ... -X PATCH -f base=main` worked reliably).
2. Worktree already existed at `.worktrees/portfolio-v0-V0.6-csv-t212` — no new checkout needed.
3. `git merge origin/main` produced one add/add conflict in `portfolio-tools/index.ts` — trivial: HEAD had `d.data()` as position id (bug), origin/main had `d.id` (correct fix from V0.3). Kept origin/main version.
4. Merge commit used `TDD-Waiver` trailer — pre-push hook respected it, skipped TDD checks.
5. Local build (`vue-tsc --noEmit && vite build`) clean.
6. Vitest run: 33 pass, 1 pre-existing fail (`emulator-boot.test.ts` empty-indexes assertion broken by V0.3 trades index — not introduced here).
7. Push succeeded. All 15 CI checks green.

## Learnings

- `gh pr edit --base` can fail with GraphQL 500 intermittently. Fall back to `gh api repos/.../pulls/40 -X PATCH -f base=main`.
- V0.5 commits (Money type + FX) were already in the V0.6 branch history, so merging main (which has V0.3 + V0.1 only) brought in no duplicates — just the gap between V0.5 and V0.3+V0.1.
- `TDD-Waiver` trailer in merge commit message is sufficient; no separate empty commit needed when the merge commit itself carries the trailer.
