# reviewer-auth.sh fails on cross-repo PRs (missmp/company-os)

**Date:** 2026-04-22
**Session:** 1423e23d-e7aa-41ee-9558-fa5f6deed2b3 (twelfth leg)
**Concern:** work

## Observation

Both Senna and Lucian failed `scripts/reviewer-auth.sh` when trying to post approving reviews on PRs in `missmp/company-os`. The failure is not transient — it is structural. `reviewer-auth.sh` was written for the `strawberry-agents` repo context; it does not carry cross-repo collaborator access for `strawberry-reviewers` on `missmp/company-os`.

## Impact

All PRs in `missmp/company-os` (demo-studio-v3 work, dashboard-split, etc.) can only receive advisory comments (posted under `Duongntd`) — not binding approvals. Rule 18 is unsatisfied until Duong approves via web UI as `harukainguyen1411`.

## Workaround (current)

Reviewer-failure fallback protocol (Sona CLAUDE.md §Reviewer-failure fallback):
1. Senna/Lucian produce verdict body, write to `/tmp/<reviewer>-pr-N-verdict.md`.
2. Yuumi posts as PR comment under `Duongntd`.
3. Duong approves via web UI as `harukainguyen1411`.

## Fix direction

Two options:
- Grant `strawberry-reviewers` collaborator access to `missmp/company-os` (simplest, unblocks Rule 18 immediately).
- Extend `reviewer-auth.sh` to accept a target-repo parameter and authenticate with the correct org scope.

Commission a plan when capacity allows. Until then, every `missmp/company-os` PR requires Duong manual approve.
