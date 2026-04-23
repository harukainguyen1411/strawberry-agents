# Reviewer identities lack read on missmp/company-os

**Date:** 2026-04-23
**Context:** Review task for PR missmp/company-os#87 (work concern).

## Symptom

Both reviewer lanes return errors against `missmp/company-os`:

- `--lane senna` (strawberry-reviewers-2): REST `repos/missmp/company-os/pulls/87` → 404.
  GraphQL `pr view` fails on `read:org` scope missing.
- `--lane lucian` (strawberry-reviewers): same 404 / scope errors.

`gh api user` succeeds with the expected login on both, so the token itself is valid —
the accounts simply aren't collaborators on missmp/company-os, and the PATs have only
`repo` + `workflow` scopes, no `read:org`.

## Implication

Senna (and Lucian) cannot submit GitHub-visible reviews on `missmp/*` work-concern
PRs via the current reviewer-auth plumbing. Verdicts must be written to
`/tmp/senna-pr-<N>-verdict.md` and handed back to the coordinator (Sona or Duong)
for a human / authenticated translator to post. The task prompt for PR #87
explicitly anticipated this fallback.

## Follow-up if this is expected to be a recurring state

1. Add `strawberry-reviewers-2` as a read collaborator on `missmp/company-os` and
   bump PAT scopes to include `read:org`, OR
2. Stand up a dedicated work-concern reviewer identity with access to `missmp/*`
   and a matching `--lane sona-reviewers` branch in `scripts/reviewer-auth.sh`, OR
3. Accept the "verdict file + coordinator relay" model and document it as the
   expected flow for `missmp/*` reviews (would be a Rule-18-adjacent invariant).

## Preflight that detects this cleanly

```
scripts/reviewer-auth.sh --lane senna gh api repos/<owner>/<repo>/pulls/<N> \
  --jq '.number' 2>&1 | head -3
```

404 here = access gap, switch to verdict-file flow. Don't burn cycles retrying with
different fields or query shapes.

## Locating the work repo locally when GH access fails

`ls ~/Documents/Work/mmp/workspace/ | grep <feature-slug>` — work-concern worktrees
for each PR live here; `git remote -v` + `git log` get the rest of the context that
`gh pr view` would have returned.
