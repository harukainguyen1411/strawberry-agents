---
date: 2026-04-18
author: yuumi
topic: pre-commit-secrets-guard skips plans but not assessments — fix applied
---

# Pre-commit hook blocks assessments/ that quote workflow env var names

## What happened

When committing `assessments/2026-04-18-migration-plan-factcheck.md`, the pre-commit secrets guard tripped with "contains a string matching a known decrypted secret value." The report quoted workflow YAML lines like `${{ secrets.DISCORD_RELAY_WEBHOOK_SECRET }}` and secret names from the repo, and one of those substrings matched a decrypted secret value (length ≥ 8).

## Root cause

The hook's skip list included `plans/*` with the rationale "these may contain incidental substrings that collide with secret values." The same rationale applies to `assessments/*` — they quote workflows, secret names, and grep output as documentation. But `assessments/*` was not in the skip list.

## Fix applied

Added `assessments/*) continue ;;` to the skip list in `scripts/hooks/pre-commit-secrets-guard.sh` immediately after the `plans/*` entry. Both paths are documentation-and-analysis files, not secret storage.

## Pattern to remember

When a commit is blocked by the secrets guard on a documentation file (plans/, assessments/, agents/ reports), check whether the file path is in the hook's skip list. The hook skip list is the canonical place to codify "this path class is documentation, not secret storage."
