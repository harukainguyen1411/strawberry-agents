# PR58 — coordinator routing discipline: advisory LGTM

**Date:** 2026-04-25
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/58
**Branch:** `talon/coordinator-routing-discipline`
**Verdict:** LGTM (advisory) — review posted as `--comment` per Rule 18 (cannot self-approve since author is `duongntd99`, reviewer is `strawberry-reviewers-2` — Duong handles the structural approval gate via `harukainguyen1411`).

## Scope

Pure-additive surface — bats fixture (4 cases) + 1 include file + 1 cheat-sheet markdown + include wiring into Evelynn/Sona defs. Total +156/-0 of real change (the apparent -50 was a stale-base artifact, see findings).

## Verifications I ran

1. **xfail authenticity at T1 (`a195d961`)** — clean clone, checkout T1, `bats tests/agents/coordinator-routing-check-wired.bats`. All 4 cases failed at T1; all 4 green at HEAD `2f97a2ea`. Genuine pre-impl red-then-green. **Pattern: when the PR claims xfail-first, verify by actually checking out the xfail commit and running.** This is the strongest signal of TDD honesty.

2. **Sync idempotency** — `scripts/sync-shared-rules.sh` post-HEAD: `synced=30 skipped=0 errors=0`, all 30 files reported "up-to-date", `git diff` empty post-run. Sync is idempotent.

3. **Mental walkthrough of both error scenarios** against the include's 4-step block — both Error 1 (Talon vs Swain plan, lane mismatch) and Error 2 (Viktor solo without Rakan xfail commit, pair-set incomplete) terminate cleanly at steps 3 and 4 respectively. The include's framing distinguishes the two error shapes correctly.

## Key finding — stale-base diff trap

The PR diff showed `assessments/research/2026-04-25-coordinator-discipline-slips.md | 50 ----------------------`. Initially looked like a 50-line deletion. Investigation:

- Merge base: `74d6d5c4` (plan-promotion commit on main).
- After merge base, main received `1ca2d341` which **added** the slips file.
- PR branch never touched the file.
- `git diff main..branch` thus reports the file as -50/+0 — but it's stale-base, not a real deletion.

**Reasoning:** with merge-commit strategy (Rule 11 forbids rebase, Strawberry uses merge commits — verified via `git log --merges main`), 3-way merge sees "branch did not delete or modify; main added" → file preserved on post-merge main. **Not a data-loss risk for merge-commit, but would silently delete the file under squash-or-rebase merge.**

Flagged as Important-tier with the recommendation to `git merge main` into the branch before merging, which makes the diff true 0/0 against the slips file and removes the trap.

**Reusable lesson:** when reviewing a PR diff that shows file deletions the PR body doesn't mention, check the merge base. `git log <merge-base>..main -- <deleted-file>` will reveal stale-base additions. Don't assume the PR author maliciously or accidentally deleted files; check structurally.

## Cosmetic suggestions (not blockers)

- Missing `<!-- canonical source: ... -->` breadcrumb above the new include marker. Pattern is intent-check-only across the repo (other includes — no-ai-attribution — also omit it); no defect, just noted.
- No blank line between adjacent expanded include blocks at L89→L90 and L115→L116 in evelynn.md/sona.md. Cosmetic; sync script handles either form.

## Pattern bank update

- **Always run xfail tests at the actual xfail commit, not just at HEAD.** Read claims about "all 4 fail pre-impl" and verify by running. This caught nothing here (claim was honest), but the protocol is what makes the verification credible.
- **Stale-base diffs masquerade as deletions.** Compute merge-base, scan main's commits since merge-base for additions to the "deleted" path, before drafting any "data loss" finding.
- **Include-machinery PRs are low security surface but high coordination surface.** No code paths, no env handling, no auth — the only risk vectors are (a) drift between sourced agents (catch via wiring bats), (b) sync script idempotency regressions (catch via `sync && git diff`). Both verified clean here.
