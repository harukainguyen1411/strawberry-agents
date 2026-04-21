# PR #11 — Orianna concern-based resolution root flip

**Date:** 2026-04-21
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/11
**Verdict:** APPROVE (clean, 3 non-blocking suggestions)

## What the PR did

Replaced Orianna's work-concern prefix-whitelist model (`apps/`, `dashboards/`,
`.github/workflows/`) with a resolution-root flip: plans declaring
`concern: work` now route every path-shaped token to
`~/Documents/Work/mmp/workspace/` by default. A hard-coded opt-back list keeps
strawberry-agents infra paths (`agents/`, `plans/`, `scripts/`, `assessments/`,
`architecture/`, `.claude/`, `secrets/`, plus exact files `tools/decrypt.sh`,
`tools/encrypt.sh`) resolving against this repo regardless of concern.
Renamed `WORK_CONCERN_REPO` → `WORK_CONCERN_ROOT` with alias kept for
back-compat.

Unknown work-concern paths are now `block` findings (was `info`).

## Review method that worked

Rather than diff-only review, I checked out the branch as a worktree
(`git worktree add --force /tmp/senna-wt-pr11 FETCH_HEAD`) and:

1. Ran both the new and existing test suites to baseline. Both 4/4 green.
2. Wrote eight scratch plans into `/tmp/` with adversarial frontmatter variants
   — quoted `concern: "work"`, trailing whitespace, capitalized `Work`, missing
   field, empty value, no frontmatter, leading-slash absolute path tokens, `..`
   traversal tokens. Ran each through the modified script and inspected the
   generated report.

This probe-driven edge-case method caught three observations the diff alone
would not have:
- Capitalized `concern: Work` falls through (YAML convention is lowercase; not a
  bug, but a subtle foot-gun).
- Absolute-path tokens produce `//` in the anchor (cosmetic, not a path escape).
- `..` traversal tokens evaluate lexically and can produce `info (exists)`
  findings against files outside the declared root. Not new behavior, not
  exploitable in-model, but load-bearing if plan provenance ever widens.

Worth keeping as a playbook for any PR that changes path routing or token
classification in Orianna's stack.

## Surface-alignment verification

The plan required three surfaces to enumerate identical opt-back lists:
- `scripts/fact-check-plan.sh::_is_optback()`
- `agents/orianna/claim-contract.md` §5a
- `agents/orianna/prompts/plan-check.md` Step C

I grep-extracted each list and compared by sorted membership. All three match
and each explicitly notes that bare `tools/` is NOT on the opt-back list. This
is the kind of three-way drift that's easy to introduce and nearly impossible
to catch via narrative review alone — scripting the comparison was worth it.

## Rule 12 handling

Commit order on the branch:
- `1955263` — test added with xfail sentinel + `exit 0` guard
- `e0b7ba8` — implementation + guard removal (test now honest)

The xfail-sentinel-then-remove pattern is now the established convention (same
shape as Talon's earlier work). Scanning the commit messages for `XFAIL` and
verifying the guard flip between commits is a fast Rule-12 audit.

## Lane separation

Posted via `scripts/reviewer-auth.sh --lane senna` (identity:
`strawberry-reviewers-2`). Lucian had already posted his APPROVE from
`strawberry-reviewers` one minute earlier. GitHub preserved both as distinct
review records — exactly what the PR #45 masking-bug fix was designed for.
Confirmed via `gh pr view --json reviews` that both reviews appear with
distinct author logins.

## Non-blocking observations posted

1. `concern: Work` casing — suggest lowercase normalization in the awk parser.
2. Leading-slash tokens — suggest stripping before concatenation (cosmetic).
3. `..` path-traversal tokens — suggest rejection or bound-check if plan
   provenance ever widens beyond trusted agents. Pre-existing behavior.

All three deferred explicitly — none gate this PR. Future work if/when Orianna
consumes untrusted plan input.
