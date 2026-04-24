# Stale-base contamination on stacked PRs — preflight branch-cut before executor dispatch

**Date:** 2026-04-24
**Severity:** high
**Session:** 84b7ba50 (post-compact round 4)

## What happened

Self-invite T1 was delegated to Seraphine. Her branch was cut from a base that had not been synced after recent unrelated merges landed. The resulting PR (#2108) carried 3 foreign commits — changes from other work streams that had nothing to do with T1. Lucian caught the scope creep in review and returned REQUEST CHANGES.

The entire review cycle (Senna+Lucian dispatch, wait, return, triage) was wasted. The fix is to rebase or cherry-pick the T1 work onto a clean base — another round trip.

## Root cause

The executor agent cut the branch from whatever HEAD was available on the local worktree, which included stale merge state from prior sessions. No preflight check was performed to verify the branch was clean relative to the intended base.

## Fix pattern

Before delegating any executor task that will result in a PR:

1. Verify the intended base branch is up to date: `git fetch origin && git log origin/<base> -1`.
2. Have the executor cut the working branch from the verified-clean base: `git checkout -b <branch> origin/<base>`.
3. After the executor returns, run `gh pr diff --name-only` to verify only expected files are in the diff.
4. If foreign commits are present, stop — do not dispatch reviewers. Rebase or re-cut first.

## Standing rule

Stale-base contamination is a systematic risk on stacked PR workflows. The branch-cut step in every executor task prompt should explicitly name the base SHA or branch ref, not just the branch name. "Cut from `origin/main`" is safer than "cut from `main`".
