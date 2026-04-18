---
name: billing-block-failure-signature
description: GitHub Actions billing/spending-limit block presents as all-red CI across every PR simultaneously with log retrieval failing — check billing before investigating workflows
type: reference
---

# Billing-block failure signature

## Symptom

Every required check across every PR in every workstream goes red simultaneously. `gh run view --log-failed <run_id>` returns `log not found`. New pushes (empty commit nudges, merges-into-branch) don't trigger fresh runs or sit in a queue indefinitely.

## Root cause

GitHub Actions billing hard-stop — "recent account payments have failed" or "your spending limit needs to be increased." Jobs are rejected at queue time, so workflows return FAILURE even though their YAML is valid.

## Diagnostic sequence (run in order)

1. Is CI red on **every** PR across **every** workstream, not just dep bumps? → likely environmental.
2. Does `gh run view --log-failed <id>` return "log not found" on the FAILURE runs? → billing or purge, not workflow.
3. Check `gh api /repos/<owner>/<repo>/actions/permissions` and billing settings at `github.com/settings/billing/summary`.
4. If billing-blocked: only Duong (account owner) can resolve; stand down fleet-wide, don't attempt nudges or fixes.

## What NOT to do during a billing block

- Don't push empty-commit CI nudges — they won't trigger anything.
- Don't merge main into feature branches — if main has any state you're trying to avoid, you now have it too, with no CI gate to catch it.
- Don't force-push "fixes" to PRs — you're guessing at non-existent failures.
- Don't start new PRs — no CI gate for the new work.

## Playbook ref

Fleet-wide observability rule (candidate for `architecture/operability.md` if Duong promotes): *"If every required check across every PR goes red simultaneously and log retrieval fails, check GitHub Actions billing BEFORE investigating workflows."*

Today's diagnosis from first red signal to root cause: ~30 minutes. With this playbook entry: should be under 2.
