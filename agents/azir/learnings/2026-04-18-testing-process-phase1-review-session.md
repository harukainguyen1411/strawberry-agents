# Learning: Stale-view discipline + session-long multi-PR review cadence

**Date:** 2026-04-18
**Context:** Testing-dashboard Phase 1 workstream — 16 PRs reviewed across one session as architecture reviewer alongside Jhin (code/security).

## The stale-view trap

`gh pr view` and `gh api repos/.../pulls/<n>/files` can return cached state that lags the actual branch tip. In this session I posted a review flagging a missing `--service-account` attachment on #180 that was already added at a later commit I hadn't fetched. Cait caught it via ground-truth `git show origin/<branch>:<file>`. Same class hit Jhin on #154/#159 today.

**Discipline:** before ANY re-review, first call:
```
gh api repos/<owner>/<repo>/pulls/<n> --jq '.head.sha'
```
Compare to the SHA your prior review referenced. If it changed, pull the new diff fresh before commenting. If the SHA delta contains only non-architectural changes (build-tool canonicalization, typo fixes, filename renames, comment tweaks), the prior LGTM extends — say so explicitly in a one-line comment rather than re-reviewing from scratch.

## The "LGTM extends" rule

Saves cycles for both sides. Adopted mid-session: architecture LGTM at HEAD X extends to future tip Y absent architectural changes. Architectural surface = routing/auth/data model/IAM/deploy topology/API contract. Everything else (dep manager choice, cosmetic renames, comment additions, test-rename follow-ups) does NOT require new architectural clearance — I note the extension and move on.

## Contamination — three flavors

1. **Insertion (shared-worktree `git add -A`)**: other agents' in-flight memory/learnings files swept into the PR. Fix: explicit-file staging.
2. **Deletion (stale-base merge)**: branch cut before files landed on main, PR diff shows those files as deletions. Fix: `git fetch origin && git merge origin/main`, re-check `git diff origin/main --stat`.
3. **Unrelated plans**: plan files dragged into feature PRs because they were uncommitted on the shared base. Fix: plans go direct to main per rule 4, never via PR.

I flagged all three variants this session; Cait broadcast the `git add -A` one team-wide.

## Self-correcting one's own ADR

When a finding implicates the ADR rather than the implementation, own it and amend. ADR §9 originally listed `roles/firebaseauth.admin` — I had to publish an amendment commit (`3c0dc77`) to remove it AND redact a UID literal that was being re-flagged by the pre-commit secrets guard. Doing this same-day saved downstream PRs from implementing against a broken spec.

Pattern for ADR amendments under the secrets-guard:
- Don't bypass hooks.
- If Guard 4 flags something pre-existing in the file, redact (prefer) or update the hook allowlist (avoid — would weaken defense).
- Commit with clear rationale naming what changed and why, plus an inline "Removed YYYY-MM-DD (Azir)" note in the ADR text.

## What I would do differently

Do the HEAD-SHA check routine *before* posting the review, not after. That removes stale-view false flags from the start. Adopting as standing practice.
