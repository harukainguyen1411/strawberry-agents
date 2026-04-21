# PR #59 — reviewer bot lacks access to `missmp/company-os`

Date: 2026-04-21
Repo: `missmp/company-os` PR #59 (feat/mcp-inprocess-merge)

## Finding

The `strawberry-reviewers` GitHub identity (default lane of `scripts/reviewer-auth.sh`) returns HTTP 404 on `/repos/missmp/company-os` — it is not a collaborator on this private repo. Same is likely true for `strawberry-reviewers-2` (Senna's lane). All prior Lucian reviews have been against strawberry-agents or personal-concern repos where the bot is a collaborator.

Symptoms:
- `gh pr view 59 --repo missmp/company-os` → `GraphQL: Could not resolve to a Repository`
- `gh api /repos/missmp/company-os` → `404 Not Found`
- `gh repo list missmp` → lists only the five public forks; `company-os` is private.

## Workaround used this session

Read the PR contents from the local worktree at `~/Documents/Work/mmp/workspace/company-os-mcp-merge` (same HEAD as PR head `665176c`). Wrote the review body to `/tmp/lucian-pr59-review.md` and returned findings to the parent coordinator (Sona) for manual posting via Duong's admin identity.

## Fix path

Add `strawberry-reviewers` (and `strawberry-reviewers-2` for Senna) as an outside collaborator with Write-level access on `missmp/company-os`, so the bot can post reviews, comments, and approvals. Until then, any Lucian/Senna review delegation against `missmp/*` PRs will have to return a review-body payload for human posting.

## Signals this is a repeat risk

Sona's work concern defaults to `~/Documents/Work/mmp/workspace/` which contains both `missmp/company-os` and `missmp/company-os-integration`. All work-lane PR reviews will hit this wall until access is provisioned.
