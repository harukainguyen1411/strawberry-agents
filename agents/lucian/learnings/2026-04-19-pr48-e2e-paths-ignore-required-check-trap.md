# 2026-04-19 — PR #48 (strawberry-app): paths-ignore vs required checks

## Context
PR #48 added `paths-ignore: ['apps/myapps/**']` to `e2e.yml` to dedupe Playwright runs on myapps PRs. Author's probe said "no branch protection" so the simple paths-ignore was declared sufficient.

## What I caught
- Branch protection WAS restored earlier the same day via `plans/implemented/2026-04-19-branch-protection-restore.md` (classic protection, `enforce_admins: false`, 5 required contexts including `Playwright E2E`).
- `Duongntd` / `duongntd99` accounts get 404 on `/branches/main/protection` because they lack admin read. Author interpreted 404 as "no protection". In fact the repo-level `branches/main` endpoint still reports `protected: true` — that is the signal to trust when you lack admin scope.
- GitHub does NOT synthesise a success status for workflows skipped via `paths-ignore`. If the workflow name is a required status context, the check stays missing and the PR is unmergeable via non-admin flow.
- The PR body's own "Follow-up" section already described the exact failure mode as a hypothetical — but that hypothetical had already come true earlier the same day. Always reconcile the PR's claimed current-state against the latest implemented plans in `plans/implemented/`.

## Pattern to require
When scoping a workflow out of a path AND the workflow's job name is a required status check, use the always-runs + internal gate pattern already used by `myapps-test.yml` and `myapps-pr-preview.yml` (no paths filter at the `on:` level; gate individual steps on a computed `changed` output). This is the repo's standing convention; new workflows should conform.

## Rule 18 reminder
Duongntd was PR author; GitHub rejected review from the same account. Switched to `duongntd99` to post. Always check PR author before attempting the review call.
