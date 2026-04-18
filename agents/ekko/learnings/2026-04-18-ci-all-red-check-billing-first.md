# CI all-red across all PRs → check GitHub Actions billing first

## Symptom

Every required check on every open PR across every workstream shows FAILURE simultaneously. Local test runs pass. Force-push / empty-commit nudges don't help. Log retrieval via `gh run view` returns empty or errors. New PR creation shows red checks instantly.

## Root cause (team-lead diagnosis 2026-04-18)

GitHub Actions is hard-stopped on **billing** — the org's payment failed or spending limit was hit. Every job is rejected at queue time with a billing error message. From the PR checks API it looks identical to a test failure.

## Diagnostic sequence (2 min instead of 30)

1. Pick ANY recent PR. `gh pr checks <n>` — are all required checks red?
2. Cross-check against another PR on a different workstream. Same pattern?
3. Try `gh run list --limit 5`. If results are empty or all show `startup_failure`, billing is the suspect.
4. Visit `https://github.com/settings/billing` (browser) or `gh api /repos/{owner}/{repo}/actions/permissions` — look for billing/quota messages.
5. If confirmed: notify team-lead + Duong. Nothing to do agent-side.

## What NOT to do while billing is blocked

- Don't force-push; the old tip may be unrecoverable, and the new tip won't run CI either.
- Don't merge main into feature branches; wastes merge-commit budget on an already-parked PR.
- Don't `@dependabot rebase`; creates churn.
- Don't create new PRs; they'll land red instantly and confuse state.

## Anti-pattern from today

I pushed two empty-commit CI nudges (b5a4c1d, 9a156cd) on #171 before billing was diagnosed. Both landed on origin but produced no CI runs — the queue itself was rejecting jobs. Empty nudges are only useful when CI is healthy but skipped an individual workflow; when ALL workflows are red, the billing check comes first.

## Why this fools agents

GitHub's required-checks API doesn't distinguish "test failed" from "job refused at queue." Same red dot, same conclusion string. Requires operational context — e.g., "my local test suite passes and I can't get logs" — to suspect infrastructure rather than code.
