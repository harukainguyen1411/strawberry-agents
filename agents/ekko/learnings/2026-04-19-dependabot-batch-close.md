# Dependabot Batch Close — 2026-04-19

## What happened

Closed 16 open Dependabot PRs on `harukainguyen1411/strawberry-app` (numbers: #1, #3–#17) as a queue-hygiene sweep. Reason: all were blocked on review and triggering auto-rebase.yml cascade retriggers on every main merge.

## Technique

Single bash loop: post comment then `gh pr close` per PR. All 16 succeeded with no failures.

## Auth note

Active gh account was harukainguyen1411 at session start. Must switch to Duongntd (`gh auth switch -u Duongntd`) before any close/comment on strawberry-app PRs, since Duongntd has write access and is the intended agent account for triage operations.

## Key command pattern

```bash
gh pr comment $PR --repo "$REPO" --body "$COMMENT"
gh pr close $PR --repo "$REPO"
```

No `--delete-branch` flag — Dependabot branches are left intact for Dependabot to manage.
