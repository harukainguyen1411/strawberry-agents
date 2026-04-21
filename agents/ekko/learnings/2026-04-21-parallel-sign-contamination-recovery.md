# 2026-04-21 — Parallel Orianna sign contamination and recovery

## Problem

When multiple Ekko sessions run concurrently and both invoke `orianna-sign.sh` near the same time, two failure modes occur:

1. **git index.lock collision** — the sign script runs `git add` + `git commit`. If another git process holds the lock at commit time, the commit fails after the signature is already written to the file. The plan file on disk has the signature but no corresponding commit.

2. **Multi-file signing commit** — if another session's staged files are in the index when the sign commit runs, the `orianna-sig-guard` hook rejects the commit because it expects exactly 1 staged file. The signature gets written but the commit fails.

3. **Swept-file contamination** — the sign script may stage the target plan file, but another parallel commit sweeps the file into a different commit (e.g. a "remove stale signature" cleanup commit). The signature commits with a different commit message than expected, and `orianna-verify-signature.sh` cannot find the valid signing commit.

## Recovery pattern

1. Check `git diff HEAD -- <plan.md>` — if the signature is committed but under a bad commit, remove the signature from the file and commit the removal as `chore: strip stale <phase> signature`.
2. Check `git diff --cached --name-only` — if other agents have staged files, `git reset HEAD <those-files>` to clear them. Their working tree changes survive; they'll re-stage when they resume.
3. Re-run `orianna-sign.sh` on the clean index.
4. Then run `plan-promote.sh` normally.

## Prevention

Before calling `orianna-sign.sh`, always run `git diff --cached --name-only` and unstage any extra files. This is the parallel-safe pattern.

## Key constraint

`orianna-sig-guard` pre-commit hook: signing commit must touch exactly 1 file (§D1.2). Any extra staged files from parallel sessions will block the commit.
