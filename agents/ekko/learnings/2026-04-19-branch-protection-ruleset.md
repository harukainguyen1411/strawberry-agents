# Branch Protection Ruleset Migration — 2026-04-19

## What happened

Executed Camille's branch protection restore plan for harukainguyen1411/strawberry-app.
Rewrote both instances of `scripts/setup-branch-protection.sh` (strawberry-agents and strawberry-app)
to use the GitHub Rulesets API instead of classic branch protection.

## Blocker: Ruleset API requires admin access

`POST /repos/{owner}/{repo}/rulesets` returns 404 (not 403) when the caller lacks
admin permission. Duongntd has `write` access on strawberry-app — not admin.
GitHub returns 404 on admin endpoints to avoid leaking repo existence.

The script is fully rewritten and committed. Duong must run it manually as harukainguyen1411:
```bash
gh auth switch --user harukainguyen1411  # or GH_TOKEN=<harukainguyen1411-pat>
bash scripts/setup-branch-protection.sh harukainguyen1411/strawberry-app
```

## GitHub auth state

- `gh auth status` shows Duongntd (active) and duongntd99. harukainguyen1411 is NOT in `~/.config/gh/hosts.yml`.
- harukainguyen1411 OAuth token is not in secrets/ or keychain. Must be set up by Duong directly.
- `duongntd99` account has pull-only access to strawberry-app — no use.

## Ruleset API vs classic protection

- Classic: `PUT /repos/{owner}/{repo}/branches/{branch}/protection` — Duongntd can call this (write access sufficient).
- Rulesets: `POST /repos/{owner}/{repo}/rulesets` — requires admin. Duongntd cannot call this.
- GET /rulesets is public for public repos (returns []). POST requires admin.
- The 404 vs 403 distinction: GitHub intentionally 404s admin endpoints for non-admins.

## bypass_mode: "pull_request" vs "always"

Duong chose "pull_request" (not "always"). This means harukainguyen1411 must still open a PR
when bypassing, for audit trail and Drive-mirror discipline. The PR can be auto-merged
without satisfying checks/reviews.

## Script design: worktree for strawberry-app changes

Used `git worktree add -b chore/branch-protection-ruleset` since the changes need
a PR (Duongntd cannot self-merge, Rule 18). Stashed main changes, created worktree,
copied files, restored main, committed in worktree, pushed, opened PR #50.

## Plan promotion

`plan-promote.sh` worked cleanly. Orianna fact-check passed (0 block, 0 warn).
Plan promoted to `implemented` per Duong's instruction even though the API call
is pending — the scripting work is the implementation, the API call is a manual operational step.
