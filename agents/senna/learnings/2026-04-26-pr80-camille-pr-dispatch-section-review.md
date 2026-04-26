---
date: 2026-04-26
agent: senna
session_topic: PR #80 review — camille PR-dispatch section (T5/D6b/D6c)
pr: https://github.com/harukainguyen1411/strawberry-agents/pull/80
verdict: REQUEST CHANGES
review_url: https://github.com/harukainguyen1411/strawberry-agents/pull/80#pullrequestreview-4176722651
---

# PR #80 — camille PR-dispatch section review

## TL;DR

Small agent-def amendment per plan T5/D9.3. Substance is correct (AC4 fully satisfied). Two real findings:

1. **CI BLOCKER** — `No AI attribution (Layer 3)` job fails on the PR body because every reference to `.claude/agents/camille.md` matches the regex `(^|[[:punct:]])(claude|...)` — `.` is `[[:punct:]]`, `claude` is the literal. The override (`Human-Verified: yes`) exists for exactly this case.
2. **IMPORTANT** — Plan D6b literal lists three named boundaries: `reviewer-auth, gh-auth-guard, plan-lifecycle-guard`. The PR's Agent-identity boundary bullet has reviewer-auth + plan-lifecycle-guard but not gh-auth-guard.

## Mechanics learned

- The `pr-lint-no-ai-attribution.sh` regex has a known false-positive shape: any `.claude/...` reference triggers it because the leading `.` matches `[[:punct:]]` and the body matches the `claude` alternation. Future PRs touching files under `.claude/` should either use `Human-Verified: yes` or scope path mentions to body sections that avoid the punct+claude+punct adjacency. This is structurally unavoidable on agent-def-touching PRs unless the regex is loosened or the override is normalized.

- pr-lint workflow scans `pull_request` (body) and `issue_comment` (PR comments) but NOT `pull_request_review` events. Review bodies can discuss the tokens that would otherwise trip the lint without breaking CI.

- `scripts/reviewer-auth.sh --lane senna` worked first try on this session. Identity preflight returned `strawberry-reviewers-2` correctly; review posted under that account; CHANGES_REQUESTED state confirmed via `/reviews` endpoint.

## Spec-fidelity check pattern

When reviewing an agent-def amendment driven by a specific plan task, the discipline is:
1. Find the plan's literal task text (T5 here, plus the D-references it cites — D6b and D6c).
2. Diff the literal D-text against the amendment's content. Look for additions (expansion), omissions (drift), and reorderings.
3. Expansion is usually OK if it's a reasonable interpretation; omissions are the real fidelity gaps.

In this PR, the auth-code and secret-handling bullets expanded D6b's literal text in defensible ways, but the agent-identity bullet silently dropped one of the three named boundaries (`gh-auth-guard`). That's the pattern to flag — drops, not additions.

## What I'd do differently

- Should have run the lint script locally on the PR body BEFORE drafting the review, instead of discovering the failing CI check first and then back-tracing. Adding to my checklist: on every PR that touches `.claude/`, run `gh pr view N --json body --jq .body | bash scripts/ci/pr-lint-no-ai-attribution.sh` as part of the standing pre-review walk.
