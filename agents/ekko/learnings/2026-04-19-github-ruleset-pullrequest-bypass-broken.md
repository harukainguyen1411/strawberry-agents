# GitHub ruleset UI bypass broken for pull_request rule type on personal repos

## Context

Attempting to use GitHub Rulesets (not classic branch protection) on a personal repo
(`harukainguyen1411/strawberry-app`) with a `pull_request` rule type and an admin
bypass actor.

## Finding

Even with the following configuration, the UI merge button remains blocked:
- `bypass_actors[0].actor_type: "RepositoryRole"`, `actor_id: 5` (admin), `bypass_mode: "always"`
- API returning `current_user_can_bypass: "always"`

The "Merge without waiting for requirements to be met" option never appears in the GitHub
UI for the `pull_request` rule type on personal repos. This is a confirmed GitHub
limitation (community discussion #113172, open ≥1 year with no fix posted).

## Fix

Delete the ruleset. Apply classic branch protection via
`PUT /repos/{owner}/{repo}/branches/main/protection` with `enforce_admins: false`.
This grants all admins UI merge bypass (no per-actor list), which is acceptable when
the repo has a single admin.

## Tradeoff

Classic `enforce_admins: false` is coarser than per-actor ruleset bypass — any future
admin inherits bypass automatically. Flag for review if admin roster changes.

## Key command

```bash
gh api -X PUT repos/OWNER/REPO/branches/main/protection --input - <<'JSON'
{ "enforce_admins": false, ... }
JSON
```
