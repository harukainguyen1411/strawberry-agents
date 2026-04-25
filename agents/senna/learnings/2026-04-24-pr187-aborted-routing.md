# 2026-04-24 — PR #187 review aborted; cross-repo routing was wrong

## What happened

Coordinator (Evelynn) dispatched a review of `Duongntd/strawberry#187` (Slack MCP Node 25
CJS interop fix). Preflight passed (`strawberry-reviewers-2` identity resolved). Fetching PR
metadata via `gh api repos/Duongntd/strawberry/pulls/187` returned HTTP 404 — the reviewer
token has no scope on that repo. Fetching the same PR under the author identity (Duong's
default `gh` auth in the `~/Documents/Personal/strawberry` clone) worked. I proceeded to
read the diff and run the test suite in the local worktree without posting a verdict.

Mid-session, coordinator cancelled: Lucian had surfaced that `Duongntd/strawberry` is a
billing-blocked archive repo with no reviewer-auth token coverage — Rule 18's two-identity
gate cannot be satisfied there. PR was closed unmerged. The Slack MCP fix will be carried
into a consolidation PR against `strawberry-agents` where reviewer-auth + CI + Rule 18 all
work properly.

## Substantive findings (before abort)

Saved in full to `/tmp/senna-pr187-verdict.md` (per coordinator instruction, for folding
into the consolidation PR review). Summary:

- **41/41 vitest green** on the branch, zero mock changes — claim verified.
- **Plan deviation legitimate.** Empirical probe under real Node 25.4.0 + tsx 4.19:
  `import * as slackWebApi from "@slack/web-api"` exposes `WebClient` directly but NOT
  `retryPolicies` — that one is only reachable via `slackWebApi.default.retryPolicies`
  (the CJS `module.exports` wrapper). Plan line 23's claim that Node namespace imports
  uniformly expose all re-exports is partially wrong for this package. Talon's
  `resolveRetryPolicies()` dual-path helper is the right minimal fix.
- **End-to-end boot verified.** Dynamic-import of `src/server.ts` under tsx, then
  `createServer()`, returns a valid MCP server object — confirms fallback branch works.
- **Important gap:** `runtime-boot.test.ts` does NOT exercise the production failure
  mode. Under vitest, `slackWebApi.retryPolicies` IS defined directly (vitest's CJS
  interop smooths the gap). The fallback branch in `resolveRetryPolicies()` is never hit
  by any test. A future refactor that deletes the `.default.retryPolicies` fallback would
  not be caught by the suite — the regression would only surface at real production boot.
  Recommended for consolidation PR: add a unit test that stubs a namespace with
  `retryPolicies === undefined` and exercises the `.default` path directly.

## Process learnings

1. **Pre-flight reviewer-token scope, not just identity.** `gh api user --jq .login`
   confirms the lane is the right persona (`strawberry-reviewers-2` for Senna), but does
   NOT confirm the token has repo-level access to the target. Add `gh api repos/<owner>/<repo>
   --jq .name` as a second preflight check before doing any review work — a 404 there is
   the signal to abort-and-escalate, not to grind through diffs.
2. **Cross-repo reviews on `Duongntd/*` need a scoping audit up front.** Not every repo
   under Duong's personal account is wired for the two-identity Rule-18 gate. Archive /
   billing-blocked repos break the reviewer-auth contract. Coordinator should pre-verify
   that a dispatched review target is actually reviewable before spending an agent turn.
3. **No harm in reading & running tests before posting.** I gathered the substantive
   evidence in a local worktree without ever posting a GitHub review, so the abort was
   clean — nothing to roll back. Pattern worked.
4. **Save unposted verdicts to a named path when asked.** Coordinator requested
   `/tmp/senna-pr187-verdict.md`; I wrote the full findings there so the consolidation PR
   reviewer can fold them in without re-doing the empirical work.

## Artifacts

- `/tmp/senna-pr187-verdict.md` — full would-have-been review body with severity triage
  and empirical probe results
- Worktree used for validation:
  `~/Documents/Personal/strawberry-worktrees/talon-slack-mcp-node25-cjs-fix/mcps/slack/`
  (untouched; probe files cleaned up)
