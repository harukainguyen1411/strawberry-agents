# PR #9 — delete auto-rebase.yml review

**Repo:** harukainguyen1411/strawberry-agents
**Verdict:** APPROVED
**Review URL:** https://github.com/harukainguyen1411/strawberry-agents/pull/9

## Summary

Delete-only PR removing `.github/workflows/auto-rebase.yml` (-34/+0). The workflow fired on `push: main`, iterated every open PR, `git rebase origin/main` + `git push --force-with-lease`. Each force-push counted as `pull_request: synchronize`, retriggering every PR-scoped workflow — O(open_PRs × PR_workflows) per merge. Also violated Rule 11 (never rebase).

This is the strawberry-agents mirror of the already-landed strawberry-app PR #51 (reviewed by Jayce/Lucian 2026-04-19). The superseded plan `plans/archived/2026-04-05-main-divergence-fix.md` was archived in that same wave; replacement pattern (on-demand `gh pr update-branch <num>`) is documented in `architecture/git-workflow.md:62`.

## Orphan-audit methodology

For workflow-deletion PRs, the useful scan surfaces are:
- `.github/**` — live workflow/action references → MUST be zero after deletion
- `scripts/**` — CLI/automation calls → MUST be zero
- `docs/` — live documentation → must be updated or non-existent

Everything else (archived plans, assessments, learnings, memory, transcripts) is immutable history and is expected to contain references. A grep hit in those directories is not an orphan; it's a record.

One useful find this pass: `assessments/2026-04-19-test-topology.md:61` still lists "Auto-rebase open PRs" under active `push → main` triggers. Flagged as non-blocking doc-hygiene follow-up — assessments are working docs, not immutable history, so they deserve a `chore:` touch-up post-merge. Chose not to gate the PR on it because the assessment is a descriptive snapshot, not a load-bearing source-of-truth reference.

## Security angle

Removing this workflow shrinks `AGENT_GITHUB_TOKEN` blast radius — previously a leaked token granted force-push-with-lease on every open PR branch; now it doesn't. Previously flagged in `assessments/2026-04-09-delivery-pipeline-security.md` §8.1. Worth mentioning explicitly in the review body so the security improvement is captured in the PR record, not just the deletion of a nuisance.

## Identity

`scripts/reviewer-auth.sh --lane senna gh api user --jq .login` returned `strawberry-reviewers-2` as expected. Approval recorded under the Senna lane, distinct from any Lucian lane activity on the same PR.
