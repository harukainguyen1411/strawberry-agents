# Shared-account invariant-#18 structural blocker

**Date:** 2026-04-18
**Context:** dependabot-cleanup workstream (b4b/b11/b12/b13/b14/b15/b16 PR stream)

## The failure mode

Every agent session operates under a single GitHub account (`harukainguyen1411` — Duong's
personal account). Every PR is authored under that same account. Result:

- `gh pr review --approve` fails with `GraphQL: Review Can not approve your own pull request`.
- CLAUDE.md invariant #18 independently forbids "merge a PR they authored," which extends to any
  reviewer whose GitHub identity equals the PR author.
- This isn't a per-PR issue — it blocks *every* PR in a multi-agent workstream where agents review
  each other's work.

## Why it's easy to miss at plan time

Plans that say "every PR needs reviewer A + reviewer B" implicitly assume distinct GitHub
identities behind the names. The agent-routing layer (who's Ekko vs Jhin vs Camille) is purely in
the agent memory system; GitHub only sees one account.

## Interim workaround

Post review findings as a PR comment (`gh pr comment`) rather than `gh pr review --approve`.
Prefix the comment with "**Advisory LGTM (cannot formally approve per invariant #18)**" and list
the verifications performed, so the signal is captured in the PR conversation even though the
approval count stays at 0. Escalate to team-lead/Duong for the merge path — they're the only
party with a distinct identity.

## Durable fixes (future work)

1. Dedicated bot GitHub account with review permissions — one-time setup, solves the problem
   cleanly.
2. Amend invariant #18 to specify "distinct GitHub identity from author" explicitly, and document
   the shared-account regime as an operational reality.
3. Model review-approval as advisory-by-agent + final-approval-by-human, with a durable PR
   comment template.

## Diagnostic shortcut

If `gh pr review --approve` fails with "Can not approve your own pull request" and you know you
didn't author the PR (different agent name), check the GH login — it's the account that matters,
not the agent identity.
