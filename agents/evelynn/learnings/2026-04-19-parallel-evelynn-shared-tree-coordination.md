# Parallel Evelynns sharing one checkout will collide — three failure modes

## What happened

Three Evelynn coordinators ran simultaneously against `~/Documents/Personal/strawberry-app/`: deployment pipeline (this session), dashboard, and portfolio. Within one session I hit all three failure modes:

1. **Cross-pollution on a shared branch name.** Ekko's P1.3 branch `chore/p1-3-env-ciphertext` had three Dashboard T3 commits (`b8c2d4a`, `8c2d197`, `0de16d8`) sitting on it before his commit landed — committed by a different Evelynn's executor on the same branch label. Jhin caught it via `gh pr diff 28 --name-only`. Ekko reset to main + cherry-picked + force-pushed.
2. **Force-push race.** After Ekko's reset, the branch tip was `858bf8a`. Then a third parallel session force-pushed `0ab0a2d` over it. Same content survived, but only by luck — could just as easily have stomped Ekko's clean state.
3. **Pre-existing main breakage spilling cross-stream.** Portfolio Evelynn merged `apps/myapps/portfolio-tracker/src/router/index.ts` and `read-tracker/src/router/index.ts` with `@typescript-eslint/no-unused-expressions` errors. My Phase 1 PRs (#25, #26, #28) all touch `apps/myapps/**`, so turbo's `--filter=...[origin/main]` pulls those broken files in and CI goes red on every PR I open. Three approved PRs sitting un-mergeable.

## Why it matters

A single shared checkout gives every parallel coordinator the same branch-namespace, the same uncommitted-state surface area, and the same main-tip dependency. Force-push races and cross-pollution are inevitable, not accidental.

## How to apply

- **Before opening any PR for a Sonnet executor's work**, run `git log origin/<branch> -5` to confirm only the expected commits are on the branch. If unexpected commits appear, treat the branch as contaminated and reset.
- **Before reporting "done" on a shared-tree branch**, executors must `git log origin/main..branch` to enumerate all commits that will appear in the PR diff. Their own commit is necessary but not sufficient.
- **When CI goes red on a shell-only PR**, default-suspect upstream (lockfile drift, lint regressions, infra) before suspecting the branch's diff.
- **If parallel Evelynns are likely**, request per-coordinator worktrees or clones from Duong before spawning. Shared-checkout coordination is not safe at >1 simultaneous coordinator.

## Verify before recommending

- Branch contamination is observable via `gh pr diff <num> --name-only` — always run it before final PR sign-off.
- The portfolio lint regression is at:
  - `apps/myapps/portfolio-tracker/src/router/index.ts:28`
  - `apps/myapps/read-tracker/src/router/index.ts:31`
  Both `@typescript-eslint/no-unused-expressions`. Fix is a 2-line `if (cond) a(); else b();` in place of the ternary-as-statement.
