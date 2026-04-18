# A3 strawberry-agents push + secrets + branch protection

## Date
2026-04-18

## Task
Phase A3 of the strawberry-agents companion migration: push filtered tree to harukainguyen1411/strawberry-agents, set secrets, apply branch protection.

## What Happened

### Push
- The A2 commit (`f456bae`) was on a detached HEAD in `/tmp/strawberry-agents-migration`, not on `main` branch
- The `main` branch was already tracking origin/main at `e384b22` (more recent commits from other sessions)
- Initial push sent `main` (at `e384b22`) successfully, but the A2 reference-rewrite work wasn't included
- Cherry-picked `f456bae` onto main → new commit `650079a` → pushed to remote
- Final push SHA: `650079a845f18e938d0c28f57eb6530911722d0d`

### Secrets Set
- `AGE_KEY` — piped from `secrets/age-key.txt` via `gh secret set` (no value in context)
- `AGENT_GITHUB_TOKEN` — piped from `secrets/github-triage-pat.txt` via `gh secret set`
- Both confirmed present via `gh secret list`

### Branch Protection — BLOCKED
- GitHub free plan does not support branch protection on private repos
- Error: "Upgrade to GitHub Pro or make this repository public to enable this feature" (HTTP 403)
- The §7.3 minimal profile (no force-push, no delete) **could not be applied**
- Deviation from plan: branch protection step skipped pending GitHub Pro upgrade or repo visibility change

## Key Learnings
- When filter-repo produces a detached HEAD, always explicitly check whether the desired commits are on the `main` branch before pushing
- `gh secret set < file` is the clean way to set secrets without values touching context
- Branch protection on private repos requires GitHub Pro on the free plan — this is a hard limit, not a config issue
- `git log --oneline origin/main` vs `git rev-parse HEAD` mismatch is a red flag for detached HEAD divergence
