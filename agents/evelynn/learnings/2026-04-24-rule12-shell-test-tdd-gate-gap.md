---
date: 2026-04-24
agent: evelynn
topic: Rule 12 TDD gate does not cover shell-only tests
severity: systemic-gap
source: Lucian review on PR #41 (resume-identity fix, Karma→Talon quick lane)
---

# pre-push-tdd.sh does not gate shell-only tests — Rule 12 gap

## What happened

PR #41 landed with T1 (xfail) and T3 (impl) bundled in the same commit. Lucian flagged it as a non-blocking Rule 12 drift: Rule 12 requires xfail-first — an xfail commit must precede any impl commit on the branch. The Talon impl correctly separated the intent, but the pre-push-tdd.sh hook did not catch the bundled landing because the tests involved are shell-only (no Python/JS test runner).

## The gap

`scripts/pre-push-tdd.sh` scans for TDD compliance on packages that have a test runner wired. Shell script tests (bats, bash inline, manual assertions) are not covered. An agent can bundle xfail+impl in a single commit for shell-only work and the hook will not block it.

## Impact

Low today — shell-test features are rarer than app-layer features, and the gap is systemic, not targeted. But it means Rule 12 enforcement is silently weaker for infra/script work than for app work.

## What to do

When commissioning future plans that touch `scripts/` exclusively, remind the builder that the TDD gate won't catch bundled xfail+impl commits for shell tests. Human review (Senna/Lucian) is the enforcement path until the hook is extended.

Commission a follow-up plan (Karma quick-lane) to extend pre-push-tdd.sh to cover shell test files (bats or equivalent) when bandwidth allows. Not urgent.

## Triggering event

- PR #41 (360edeb9) — Lucian non-blocking finding logged.
