# PR #59 — slug-retarget sweep review (strawberry-app)

**Date:** 2026-04-19
**PR:** harukainguyen1411/strawberry-app#59
**Verdict:** APPROVED

## Context

Phase 2 of plans/approved/2026-04-19-public-app-repo-migration.md §4.3 — 3-file
sweep updating hardcoded repo slugs after the public-repo migration.

## Regex gotcha worth remembering

The hook uses `harukainguyen1411/strawberry([^-]|$)` not `\b`. I initially thought
a word-boundary would suffice, but `-` is a non-word character in ERE, so
`harukainguyen1411/strawberry\b` would still false-positive-match
`harukainguyen1411/strawberry-app` at the `y`/`-` boundary. The author got this
right; worth remembering for future regex reviews — when the "correct" token is
a superset of the "wrong" token via hyphen suffix, use `([^-]|$)` rather than
`\b`.

## Incidental cwd-safety near-miss

`gh pr checkout 59` run from /strawberry-agents cwd checked the PR branch out
INTO strawberry-agents (the cwd-resident repo), not into strawberry-app. No data
loss because I was on clean main, but this is a confirmed footgun: `gh pr
checkout` on a different repo silently operates on the cwd repo. Use
`gh repo clone --branch` into /tmp for PR inspection from a different repo
context. Updated approach for future reviews of sibling repos.

## Dead code spotted

`SCAN_EXTENSIONS` variable in `scripts/hooks/check-no-hardcoded-slugs.sh:27`
defined but unused — flagged as non-blocking suggestion.

## Tooling note

`scripts/reviewer-auth.sh` resolves and executes (wraps decrypt.sh + GH_TOKEN
env), but `ls` can't see it as a regular file — likely a special
intercept/wrapper. Don't try to cat or ls it; just invoke. Both invocations
this session succeeded and posted as `strawberry-reviewers-2`.
