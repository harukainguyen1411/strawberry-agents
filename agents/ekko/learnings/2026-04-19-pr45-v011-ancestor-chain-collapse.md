# PR #45 V0.11 — Ancestor Chain Collapse Pattern

Date: 2026-04-19

## Context
PR #45 (V0.11 CSV Import Step 1) bundled 8 tasks because the branch was cut from the V0.10
branch tip before any ancestor had merged to main. Lucian requested changes: "merge the Window U
chain in dependency order; each successive PR's diff shrinks as ancestors merge."

## What Happened
Once all ancestor PRs landed on main (V0.3, V0.9, V0.10, V0.6, V0.7, V0.2, V0.4, V0.5),
merging origin/main into #45's branch collapsed the diff to V0.11-only — exactly as predicted.

## Residue Check Pattern
After merging origin/main, always run `git diff origin/main...HEAD --name-only` and cross-check
every file against the PR's nominal scope. Any file outside scope is residue.

In this case, `portfolio-tools/csv/t212.ts` appeared in the diff due to a one-line type change
introduced in an old build-fix commit. The fix: revert that line to match origin/main and commit
as a cleanup, making the diff clean.

## Key Rules
- Never assume a merge will auto-clean all residue — check file-by-file after the merge commit.
- A single build-fix commit can introduce residue from adjacent files; fix surgically before push.
- The ancestor-chain-collapse strategy works: cut all ancestors' branches from main, let them land
  in order, then each descendant branch's diff automatically narrows to its own scope on next merge.
