---
date: 2026-04-26
pr: 91
verdict: approved
tags: [agent-defs, lint, regression-tests, assertion-strength, re-review]
---

# PR #91 — re-review, assertion-strength check on regression bats

## Context

Talon addressed my earlier CHANGES_REQUESTED with two commits: `3ebc24f9` (regression bats `tests/scripts/opus-agents-coverage.bats`) and `7e31b8d5` (extend `OPUS_AGENTS` from 10 → 17, drop stale comment, resync rule blocks). Re-review verdict: APPROVE.

## Verification I actually performed (not just trust-the-green)

1. **Set diff vs allowlist** — `grep -rln '^model: opus' .claude/agents/` returned 17 files; `OPUS_AGENTS` line in lint script tokenizes to the same 17 names. Verified set-equality both directions and confirmed every OPUS_AGENTS token resolves to a real `.md` file (no phantoms).

2. **Block-marker check on my own and Lucian's defs** — `grep -n 'OPUS-PLANNER\|SONNET-EXECUTOR\|BEGIN STRAWBERRY-RULES'` confirmed `BEGIN/END CANONICAL OPUS-PLANNER RULES` markers on senna.md (lines 176/184) and lucian.md (lines 146/154). Lint reports 0 drift.

3. **Read the bats source, not just the green count** — opened `opus-agents-coverage.bats` and traced the assertion: it iterates every `.md` in `.claude/agents/`, filters by `^model: opus`, then word-equality-matches against the OPUS_AGENTS token list. If any opus agent is removed from the list, `found` stays 0, name is appended to `missing`, test returns 1 with fail-loud stderr. Real assertion, not a tautology. Inverse test (no sonnet-in-opus-list) is symmetric. Test 4 runs the full lint script and asserts exit 0.

## Pattern — "assertion strength check"

When a reviewer asks "would this test actually catch a regression?", do not trust the green bar. Read the test source and mentally execute the failure path: "if I deleted X from the data, would the assertion logic flag it?" For this PR the answer is yes — the test fails the way you'd want it to.

A common smell I look for: tests that loop over both data sources together and only assert "for each X in source-A, X is in source-A" (tautology). This bats does NOT have that smell — it iterates source-A (files on disk) and checks membership in source-B (OPUS_AGENTS string). Different sources, real cross-check.

## Cosmetic nit I declined to block on

The bats docstring at line 4 says "or be explicitly exempted" but the test has no exemption mechanism. Behavior is stricter than the comment suggests — that's a doc-vs-impl drift, not a correctness bug. Mentioned in review body as non-blocking.

## Residual I acknowledged

Reviewers/coordinators/gatekeepers now carry the OPUS-PLANNER block which is content-partial-wrong for those roles (the block's first bullet says "write plans to proposed/ and stop" — wrong for a reviewer). But it's strictly less wrong than the SONNET-EXECUTOR block they had before. Option B (role-specific blocks) is deferred to a Karma plan; acceptable for this PR's narrow scope.

## What I want to remember

**Three verifications worth doing on every "I added a regression test" PR**:
1. Does the test actually exercise the failure path? (read source, simulate deletion of canonical data)
2. Is the assertion a real cross-check or a tautology? (different data sources, not the same one twice)
3. Does the docstring match the assertion behavior? (drift here = future-reader-confusion, not always blocking)
