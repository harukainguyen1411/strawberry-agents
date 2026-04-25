---
date: 2026-04-25
agent: senna
topic: PR #53 no-AI-attribution defense in depth — code-quality review
verdict: advisory LGTM (COMMENTED)
pr: https://github.com/harukainguyen1411/strawberry-agents/pull/53
plan: plans/approved/personal/2026-04-25-no-ai-attribution-defense-in-depth.md
---

## Verdict
Advisory LGTM. Two important findings on regex anchoring scope, three suggestions, no blockers. Universal `Co-Authored-By:` block + verbatim catches + prompt + CI provide enough redundancy that the regex gaps are belt-and-suspenders weaknesses, not load-bearing.

## Top findings

**F1 (important):** `BODY_MARKERS` regex prefix anchoring is narrower than the inline comment claims. Comment says marker may be preceded by `start-of-line, whitespace, (, [, backtick, or :` — implementation only allows `^|[[:space:]]`. Concretely `(Sonnet)`, `[Opus]`, `` `Claude` ``, `:Sonnet`, `/Sonnet`, `"Sonnet"` all slip through Pattern C. Pattern A (universal Co-Authored-By:) and the verbatim catches still cover the most realistic AI-attribution shapes, so this is a defense-in-depth gap, not a hard miss. Two fixes possible — update comment to match impl, or tighten regex with `[[:punct:]]` on the prefix side.

**F2 (important):** Marker glued to a digit not anchored. `Sonnet4.6`, `Opus4`, `Claude4` all slip Pattern C because the postfix `[[:space:]]|[[:punct:]]|$` does not match a digit (alnum). Realistic informal copy ("ran Claude4 over the diff") slips through. Same defense-in-depth caveat applies.

**S1 (suggestion):** Workflow does NOT scan PR review bodies or inline review comments. `issue_comment` GitHub event only fires on main-thread PR comments — not `pull_request_review` (review body) or `pull_request_review_comment` (inline diff comments). A reviewer using `gh pr review --body "🤖 reviewed by Sonnet"` would not be flagged. Plan T6 only required PR body + comments, so this matches contract — surfacing as a coverage gap.

**S2-S5:** minor — claude.com substring match in fabricated words; plan refers to non-existent `_script-only-agents/`; sync script silently discards prose between adjacent markers (not documented in docstring); indented `Co-Authored-By:` not caught (theoretical).

## What I verified

- T1 / T3 / T5 all green (10/10 hook, 5/5 lint, 30/30 agent defs).
- `scripts/sync-shared-rules.sh` synced 30 files; idempotent on second run.
- Multi-marker sync exercised on a synthetic file with two markers + junk between; both blocks replaced correctly, idempotent.
- Historical offender `b2b8944` (Talon's `Co-Authored-By: Claude Sonnet 4.6`) is now caught.
- Workflow YAML parses; permissions are minimal (`pull-requests: read`, `contents: read`).
- Sampled `soraka.md`, `akali.md`, `vi.md`, `seraphine.md` — identical inlined block.

## Reusable patterns / gotchas

- **GitHub event-trigger taxonomy is non-obvious.** `issue_comment` is for main-thread PR comments only. PR review bodies use `pull_request_review`; inline diff comments use `pull_request_review_comment`. Plans / workflows that say "PR comments" need to disambiguate which kind. Worth flagging in any future PR-content-scanning plan.
- **Comment-vs-implementation drift in regex hooks is a recurring issue.** The hook's docstring claimed broader anchoring than the regex actually implements. Always verify regex empirically against an adversarial probe set, especially when the comment uses different vocabulary than the regex character classes.
- **Sandbox probing technique:** when reviewing regex-heavy hooks, write a `probe()` shell function in the worktree and run a battery of edge cases including (a) literal token, (b) token in parens/brackets/backticks/quotes, (c) token glued to a digit, (d) token with surrounding punctuation. Catches anchoring gaps quickly.
- **Multi-marker sync script** (this PR): the state machine in `sync-shared-rules.sh` correctly preserves marker lines and replaces inter-marker content with shared file contents. Worth referencing as a clean example of an idempotent rewriter for future sync-script-shaped work.

## Files reviewed

- `/Users/duongntd99/Documents/Personal/strawberry-agents-no-ai-attribution/scripts/sync-shared-rules.sh`
- `/Users/duongntd99/Documents/Personal/strawberry-agents-no-ai-attribution/scripts/hooks/commit-msg-no-ai-coauthor.sh`
- `/Users/duongntd99/Documents/Personal/strawberry-agents-no-ai-attribution/scripts/ci/pr-lint-no-ai-attribution.sh`
- `/Users/duongntd99/Documents/Personal/strawberry-agents-no-ai-attribution/.github/workflows/pr-lint.yml`
- `/Users/duongntd99/Documents/Personal/strawberry-agents-no-ai-attribution/.claude/agents/_shared/no-ai-attribution.md`
- `/Users/duongntd99/Documents/Personal/strawberry-agents-no-ai-attribution/tests/agents/test_no_ai_attribution_include.sh`
- `/Users/duongntd99/Documents/Personal/strawberry-agents-no-ai-attribution/tests/hooks/test_commit_msg_no_ai_coauthor.sh`
- `/Users/duongntd99/Documents/Personal/strawberry-agents-no-ai-attribution/tests/ci/test_pr_lint_no_ai_attribution.sh`
