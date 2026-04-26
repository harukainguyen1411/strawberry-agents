---
date: 2026-04-26
pr: 92
plan: plans/approved/personal/2026-04-26-no-ai-attribution-detector-tightening.md
verdict: approve
topic: detector-tightening + override-removal fidelity
---

## What was reviewed

PR #92 (`no-ai-attr-detector-tightening`, Talon, Karma quick-lane). Two commits:
- `f611d5bf` — T1 xfail extension to both shell harnesses
- `118d1709` — T2 (detector regex swap) + T3 (shared-include + CLAUDE.md sync)

## Fidelity checks performed

1. **T1 plan-slug reference** — both `tests/hooks/test_commit_msg_no_ai_coauthor.sh` and `tests/ci/test_pr_lint_no_ai_attribution.sh` carry header `Extended:` line citing the plan, plus per-case `(plan: no-ai-attribution-detector-tightening)` markers. T1 DoD satisfied.
2. **T2 regex match against §Detection rules** — verbs `(Generated|Authored|Written|Co-authored|Coauthored)`, model tokens `(Claude|Anthropic|Sonnet|Opus|Haiku)`, narrow trailing `[Bb]y (Claude|Anthropic)` at EOL or before `[.,;]`. Verbatim `claude.com` narrowed to `/code` suffix. Email-domain rule preserved. Identical regexes in both scripts.
3. **T3 doc sync** — `.claude/agents/_shared/no-ai-attribution.md` line 3 carries the exact replacement sentence from §Override removal. CLAUDE.md Rule 21 final sentence deleted; body-marker examples shifted to phrase form. Propagated to all 30 agent defs.
4. **Override-no-op (C11/C12)** — both files assert: attribution phrase + Human-Verified → exit 1, and Co-Authored-By + Human-Verified → exit 1, via `run_xfail` with `expect_exit=1`.
5. **No history rewrite** — only two linear commits ahead of main; no rebase artifact.

## Observations / patterns

- Karma quick-lane plans with explicit ERE in §Tasks make fidelity review fast — I can grep the impl for the exact pattern strings rather than reverse-engineering intent.
- The `run_xfail` wrapper that counts XPASS as `pass++` is the right shape: lets the same test file go from xfail → green automatically once T2 lands, no test rewrite step.
- Override-no-op assertions wrapped in `run_xfail` (not `run_case`) is correct here — pre-T2 the override IS active (returns 0 instead of 1), so direction-check logic flips correctly post-impl.

## Identity / process

- Used `scripts/reviewer-auth.sh gh pr review` (default lane = strawberry-reviewers) per personal-concern protocol.
- Preflight `scripts/reviewer-auth.sh gh api user --jq .login` returned `strawberry-reviewers`. ✓
- Review posted as APPROVED.
