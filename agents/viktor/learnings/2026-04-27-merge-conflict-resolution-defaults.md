---
date: 2026-04-27
author: viktor
tags: [merge, git, conflict-resolution]
---

# Merge conflict resolution: never use `--ours` on add/add conflicts without inspecting both sides

## What happened

PR #105 had an add/add conflict on `tools/retro/__tests__/ingest-real-data.test.mjs` — both the feature branch and main had added the file (main got it from a parallel commit by another agent). I resolved with `git checkout --ours` without reading main's version first, then committed the merge. This clobbered Swain's version of the file that had landed on main (the QA ADR was restored as 2e881944).

## Rule

For add/add conflicts: **always diff both sides before choosing**. `git show origin/main:<path>` vs `git show HEAD:<path>`. Never assume `--ours` is correct just because it contains more recent local changes.

The correct resolution process:
1. `git diff HEAD:path origin/main:path` — read both versions
2. Decide which is canonical, or manually merge content from both
3. Only then `git add` and commit

## When this matters most

Merge operations during active parallel work (multiple agents touching the same area). In a busy repo with parallel PRs, add/add conflicts mean BOTH sides likely have legitimate content — `--ours` discards the other agent's work silently.

## Safer default

When in doubt: `git show origin/main:<path>` and manually produce a union if both sides have distinct correct content, rather than picking one side wholesale.
