# PR #7 re-review: verifying folded-in suggestions

**Date:** 2026-04-21
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/7
**Verdict:** APPROVE (re-review after de66c32)

## What the delta was

Ekko folded in all three of my prior suggestions:
1. `gsub(/^["']|["']$/, "", val)` added to concern-parser awk block so `concern: "work"` strips quotes before the string-equality compare.
2. Three new test cases (I4 quoted-YAML, I5 `dashboards/`, I6 `.github/workflows/`).
3. `trap 'rm -rf ...' EXIT INT TERM` + explicit `trap - EXIT INT TERM` before return in both `run_check` helpers.

## Review technique I want to remember

When re-reviewing a "suggestion-fold-in" delta, the three anti-tautology checks are:

- **Regex safety:** anchored? bounded char class? quantifier-free? What does it do to edge inputs (lone quote, mismatched pair, internal quotes)? What's the downstream consumer's tolerance?
- **Trap/cleanup side-effect masking:** does the cleanup touch the value being returned, or only filesystem state? Is the trap explicitly cleared at happy-path exit? Does `set -euo pipefail` plus outer `$(...)` still propagate a real kill?
- **New test load-bearing:** can the test pass via *any* route other than the one it claims to lock? I ask this by imagining "if the new code change were reverted, would this test still go green?" If yes, tautological. If no, load-bearing. For I4: reverting the quote-strip regex would make `PLAN_CONCERN=='"work"'` != "work", falling through to strawberry-app (which has the missing file), producing a block → test fails. Load-bearing.

## Minor nit I flagged but didn't block on

`GH_TOKEN=".github/workflows/deploy.yml"` as a test-local variable collides with the GitHub CLI env var. Not exported, not passed via the explicit `env "$@"` list, so it doesn't leak. Cosmetic only. Mentioned in review body, did not request changes.

## Local verification

Ran both suites via `git worktree add` against the PR head commit:
- `scripts/test-fact-check-work-concern-routing.sh` → 8 passed / 0 failed
- `scripts/test-fact-check-false-positives.sh` → 4 passed / 0 failed

Matches Ekko's reported numbers exactly. Worth the 30 seconds — catches cases where "it passed in CI" doesn't match local behavior (path resolution, env-var contamination).

## Lane hygiene

Preflight confirmed `strawberry-reviewers-2` identity. Used `--lane senna` on both the identity check and the review submission. No cross-lane collision risk with Lucian's already-posted APPROVED review (PR #45 incident lesson).
