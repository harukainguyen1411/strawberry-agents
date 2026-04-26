---
date: 2026-04-26
pr: harukainguyen1411/strawberry-agents#79
verdict: APPROVE
concern: personal
---

# PR #79 — retro-dashboard Phase 2+3 xfail bundle

Bundle: Xayah test-plan extension (`ac9b2a16`) + Rakan TP2/TP3 xfails (`53a738ed`, `e9609f86`).
Plan: `plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md`.

## What I checked

- 12 task IDs declared in plan (TP2.T1–T6 + TP3.T1–T6); 3 documented OQ-K3 splits → 15 files. Counted, mapped, verified ✓.
- Each test header carries task ID + guards + Rule-12 commit-before line + Plan-Ref trailer.
- All suites skip-gated on the impl artefact they guard (per file pattern).
- Plan §Test plan extension mirrors Phase-1 structure: per-task DoD, coverage matrix, slicing summary, determinism guarantees.
- Bats portability headers + grep scan for `\b` / `readarray` / `find -printf` clean.
- No mutation under `tools/retro/{ingest,render,lib,queries,templates}` — xfails-only.

## Trap I almost hit

Local main was 10 commits ahead of PR base SHA, so `git diff main..pr-branch --stat` showed 53 files / -895 lines (scope creep illusion). Re-running `git diff $(git merge-base origin/main pr-branch)..pr-branch` showed the truth: 16 files, +3430, zero deletions. **Always diff vs the merge-base, not against local main, when reviewing PRs against a stale base.**

## Drift note (accepted, disclosed in PR body)

`render-lock-tile.test.mjs:108` declares `function dirname(p) { return require('path').dirname(p); }`, which shadows the `node:path` `dirname` import + reaches for CommonJS `require` from ESM. Unreachable today (suite skip-gated on `render.mjs` lock-tile template absence). Flagged for Viktor's T.P3.2 impl PR.

## Patterns worth carrying

- **xfail-bundle PRs are a fidelity-first review.** When the diff is "tests only that skip", the questions are: are the task IDs covered, is the structure consistent with prior phases, does the skip discipline hold. Don't get drawn into asserting test correctness — that's Senna's lane (and impossible against absent impl).
- **OQ-K3-style splits should be pre-disclosed in the plan body.** This PR did exactly that; verifying "3 splits → 15 files" became a one-line arithmetic check rather than a reverse-engineering exercise.
- **Bats portability headers as self-documenting contracts.** When the file declares "no find -printf, no GNU sed -i '', no readarray" up top, my grep verification step is fast and the contract survives churn.
