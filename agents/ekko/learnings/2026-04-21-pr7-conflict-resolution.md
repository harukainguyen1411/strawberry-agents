# PR #7 Merge Conflict Resolution — 2026-04-21

## Context

PR #7 (`orianna-work-repo-routing`) became CONFLICTING after PR #10 merged into main.
PR #10 deleted 4 vestigial workflows including `ci.yml` and `preview.yml`. PR #7 had
modified both of those files (commit `34ee43d` added paths filters as a workaround
for billing-block failures).

## Conflicts

Two modify/delete conflicts:
- `.github/workflows/ci.yml` — modified in branch, deleted in main
- `.github/workflows/preview.yml` — same

## Resolution

Accepted the deletion for both files. The paths-filter workaround in PR #7 was added
to prevent billing-block failures on infra PRs; once the workflows themselves are
deleted by PR #10, the workaround is moot. `git rm` both files to accept main's
deletion, then committed the merge.

## Outcome

- Merge commit: `be3c261`
- Push: fast-forward to `origin/orianna-work-repo-routing`
- Post-push PR state: `mergeable: MERGEABLE`, `mergeStateStatus: CLEAN`
- All 4 TDD Gate checks: SUCCESS

## Pattern

When a feature branch modifies a file that main deletes, `git merge` surfaces it as
a modify/delete conflict. If the deletion is intentional on main, resolve by
`git rm <file>` (accept the deletion). Do NOT try to resurrect the file.
