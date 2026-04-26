---
date: 2026-04-26
pr: 83
verdict: advisory-lgtm
tags: [pre-commit-hooks, bash, posix, frontmatter-lint, sunset-gate]
---

# PR #83 — Phase B lint hooks (T4-T9) advisory LGTM

## Context

Jayce's plan-of-plans Phase B: two new pre-commit hooks for plan/idea structure
linting, TDD-ordered (xfail commit before impl commit). Auto-wired by the
existing glob dispatcher; install-hooks.sh diff is doc-only.

- `pre-commit-zz-plan-structure.sh` — gates `priority:` (P0|P1|P2|P3) and
  `last_reviewed:` (ISO date) on `plans/proposed/**` only. Narrower than the
  archived v2 structural linter — does not resurrect it.
- `pre-commit-zz-idea-structure.sh` — gates frontmatter (5 fields) and rejects
  forbidden body headers on `ideas/**`. Warning-only until 2026-05-09 sunset.

## What I checked, what I flagged

Six suggestions, all non-blocking:

1. `field_present` missing `local val` (scope leak)
2. Frontmatter values without space-after-colon mis-parse silently
3. Unknown `STRAWBERRY_IDEA_LINT_LEVEL` values silently fall through to error
4. Forbidden-header detection is exact-match — easy to bypass with `### Tasks`
   or trailing whitespace
5. Forbidden headers inside fenced code blocks → false positives
6. Test fixture-mode arg parsing is positional, not validated

Security: clean. No injection vectors. `git show :path` is safe.
Tests: 18/18 green, fixtures exercise actual branches honestly. One missing
case worth flagging: no bats test for warn-mode behavior itself (T9).

## Patterns I want to remember

**The `--fixture-path X --staged-path Y` test interface is a clean pattern**
for hooks that need to validate "this content as if it were staged at this
path". Decouples content-from-disk from path-gating logic without rigging a
real git index. Adopt this pattern for future hook reviews.

**Sunset gates with hardcoded `SUNSET_DATE` constants + env override** are
cleaner than dynamic config files. The auto-resolution `today < SUNSET → warn,
else error` reads naturally and is debuggable with `date +%Y-%m-%d` in shell.
ISO-date string comparison is locale-safe in bash.

**`zz-` prefix for last-running hooks** keeps the dispatcher glob ordering
deterministic without surgery on the dispatcher script itself. Good
convention for new hooks that should run after primary gates.

## Lane discipline

I noted ADR / plan-fidelity questions belong to Lucian and explicitly punted
them in the review body. The two questions I deliberately did NOT assess:
(a) does the schema match plan-of-plans §A2 / §D1, (b) is the sunset date
correct per the plan. Those are Lucian's calls.

## Reviewer-auth

Posted as `strawberry-reviewers-2` via `scripts/reviewer-auth.sh --lane senna`.
Preflight `gh api user --jq .login` confirmed identity before the review call.
No deviation from the personal-concern reviewer-auth playbook.
