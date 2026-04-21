# 2026-04-21 — Stale Dependabot PRs against deleted workflow files

## Context

Evelynn asked me to review + merge two Dependabot PRs against `harukainguyen1411/strawberry-agents`:
- PR #1 — `actions/setup-node` 4.1.0 → 6.3.0
- PR #2 — `actions/checkout` 4.2.2 → 6.0.2

Task expected "approve if clean, halt if concerning." Both were concerning. Halted both.

## What I found

1. **Target files deleted from main.** PR #1 modifies 8 workflows; PR #2 modifies 10 workflows. The current `main` tree contains only one workflow: `tdd-gate.yml`. All other workflows (`ci.yml`, `preview.yml`, `release.yml`, `auto-rebase.yml`, `myapps-*`, `landing-prod-deploy.yml`, `unit-tests.yml`, `validate-scope.yml`) have been removed from main. The PRs are editing files that no longer exist.

2. **Both were CONFLICTING/DIRTY.** Unsurprising given #1. Naive conflict resolution would re-introduce the deleted workflows — a regression.

3. **Required checks RED from 2026-04-19.** Three checks FAILURE: `Lint + Test + Build (affected)`, `Firebase Hosting PR Preview`, `unit-tests`. Rule 18(a) blocks merge regardless of any approval.

4. **Title vs. diff mismatch.** PR titles said `4.x → 6.x`, but the diff showed base is already `@v6` (floating). The actual change was `@v6` → `@v6.3.0` / `@v6.0.2` — a *pin tightening*, not a major bump. If the repo's policy is floating major tags, this is a posture regression (less automatic patch pickup, more Dependabot churn).

## Lesson — always verify target files still exist

When a Dependabot PR is old (these were 2 days stale) and the repo has active restructuring going on (workflows being deleted/renamed is common during consolidation), check that the files the PR modifies still exist on main. If they don't, the PR is obsolete — merging or rebasing would re-introduce deleted code.

Quick check pattern:
```
gh api repos/<owner>/<repo>/contents/.github/workflows --jq '.[].name'
gh pr view <n> --json files -q '.files[].path'
```
Diff the two sets. If the PR touches files not in current main, halt.

## Lesson — PR title alone is not trustworthy

The Dependabot PR titles said `4.1.0 → 6.3.0` but the actual diff was `@v6 → @v6.3.0`. The floating tag had already moved to v6 on base, and the PR was only tightening the pin. Always read the diff, not the title, before judging impact.

## Lesson — red checks + dirty state = halt, no reviewer heroics

Rule 18(a) is explicit: all required checks must be green before merge. I don't try to rerun checks or rebase Dependabot PRs to clear them — that's Dependabot's job (via `@dependabot rebase`) or a human's (close-and-reopen). My lane is review, not maintenance.

## Action taken

Posted `COMMENTED` reviews on both PRs via `scripts/reviewer-auth.sh --lane senna`, explaining the four blockers and recommending close. Did not approve, did not request-changes (Dependabot doesn't action request-changes). Left decision-to-close to Duong.

## Files touched

- `agents/senna/learnings/2026-04-21-dependabot-prs-against-deleted-workflows.md` (this file)

## Cross-refs

- Rule 18 (branch protection + no self-merge)
- `2026-04-21-pr9-auto-rebase-deletion.md` — confirms auto-rebase.yml (in PR #2 diff) was deliberately deleted
- `2026-04-17-dependabot-lockfile-review-patterns.md` — prior Dependabot review approach
