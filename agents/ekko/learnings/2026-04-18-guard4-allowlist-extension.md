# Learning: Guard 4 allowlist extension for agent memory/journal/learnings/plans

Date: 2026-04-18

## What happened

Guard 4 of `scripts/hooks/pre-commit-secrets-guard.sh` (the decrypted-value scrub loop)
was false-positiving on `agents/evelynn/memory/evelynn.md` because a pre-existing
substring in the file matched a recently added secret value in the corpus.

Guards 1–3 already used regex allowlists that covered `agents/.*/memory/`,
`agents/.*/journal/`, `agents/.*/learnings/`. Guard 4 only had two case entries:
`secrets/encrypted/*` and `secrets/age-key.txt`.

## Fix applied

Added five new `case` entries to the Guard 4 loop:
- `agents/*/memory/*`
- `agents/*/journal/*`
- `agents/*/learnings/*`
- `agents/*/transcripts/*`
- `plans/*`

This makes Guard 4 consistent with Guards 1–3.

## Key pattern

When patching pre-commit guards, check ALL guards for consistency — a new secret
in the corpus can cause false positives in any guard that hasn't been updated.

## Commit

SHA: 642c2db — pushed to main.
