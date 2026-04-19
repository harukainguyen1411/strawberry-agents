# GitHub Actions billing block — diagnosis shortcut

**Date:** 2026-04-18
**Context:** dependabot-cleanup workstream; all PRs went red simultaneously mid-session

## Symptom

Every required check across every PR fails at queue time, not at job time. Log retrieval via
`gh run view` returns empty output or errors. The failures happen instantly — no compute
executes. Multiple PRs, multiple branches, unrelated workflows — all red.

## Root cause

GitHub Actions is hard-stopped on billing. Failed payment or spending limit exceeded. Error
message (visible in the Actions tab, not always surfaced by `gh`):

> recent account payments have failed or your spending limit needs to be increased

## Diagnosis shortcut

**Before investigating workflow YAML, caching, or agent-introduced regressions**, check
`https://github.com/<owner>/settings/billing` (for user accounts) or the org billing page.
Rule of thumb:

- Single PR red + logs show job failures → real workflow/test failure.
- Single PR red + logs empty → possibly a workflow YAML syntax error.
- **All PRs red + logs empty + no compute ran → billing. Check first, always.**

Today's diagnosis took ~30 minutes. Next time: 2 minutes if you check billing first.

## What NOT to do when this state is detected

- No force-pushes — they'll re-queue and re-fail.
- No empty-commit nudges — same.
- No `git merge main` into feature branches — same.
- No new PRs — they won't get CI signal.
- Freeze open PRs in place. Green runs that landed before the block remain valid for merge
  decisions.
