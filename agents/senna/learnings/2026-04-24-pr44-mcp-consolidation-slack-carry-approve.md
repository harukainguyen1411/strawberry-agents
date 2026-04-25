# PR #44 — MCP consolidation + Slack Node 25 carry — APPROVE

**Date:** 2026-04-24
**PR:** `harukainguyen1411/strawberry-agents#44`
**Branch:** `talon/mcp-consolidation-plus-slack-carry`
**Verdict:** APPROVE (two non-blocking suggestions)

## What this PR is

Consolidation + carry of the aborted PR #187 fix (Duongntd/strawberry → strawberry-agents canonical). Repoints all 5 MCPs in `.mcp.json` (evelynn, discord, gcp, slack, cloudflare) from archive `strawberry/` paths to `strawberry-agents/` paths, and carries the Node 25 ESM/CJS interop fix for `@slack/web-api` that had been blocked on PR #187.

## What I verified hard

1. **Namespace-import + fallback helper shipped correctly.** `server.ts` L19 `import * as slackWebApi`, L32–45 `resolveRetryPolicies(ns = slackWebApi)` with dual-path. No regression to broken named-import form.

2. **The coverage gap I flagged on PR #187 is closed.** New `test/resolve-retry-policies.test.ts` passes a stub `{ retryPolicies: undefined, default: { retryPolicies: fake } }` and asserts result shape that only the `.default` branch can produce. Tracing confirms the fallback branch is executed. A regression removing the `.default` path would fail the test — genuine regression guard, no longer dead-under-vitest.

3. **Five-MCP `.mcp.json` repoint is complete.** 7 path deletions, 7 matching additions. No stray `strawberry/` paths in active config.

4. **T5 (strawberry/ deletion) NOT in this PR.** Correct gating per plan.

5. **No secrets.** Only `xoxb-test` / `xoxp-test-user-token` placeholders in diff.

## Suggestion I gave (non-blocking)

- `scripts/start.sh.bak-dual` (+41 lines) committed as `.bak`. Suggest deleting or renaming with header — committed .bak files rot.
- Import ordering: `zod`/`loadTokens` imports sit *after* `resolveRetryPolicies` fn definition. ESM hoists so functionally fine, but breaks `import/first` lint convention. Carried forward from PR #187.

## Reviewer-auth lane

Posted via `scripts/reviewer-auth.sh --lane senna` → identity `strawberry-reviewers-2`. Lucian's prior APPROVE from `strawberry-reviewers` coexists cleanly. Both reviews visible in `gh pr view 44 --json reviews`.

## Lesson reinforced

The "unit-test-the-helper-with-injected-ns" pattern I suggested on PR #187 (Option A) is what Talon implemented. It is strictly cheaper and more reliable than child_process spawn tests for this kind of vitest-vs-runtime resolution divergence. Default-parameter pattern (`ns: any = slackWebApi`) keeps the production call-site unchanged while opening a test seam — clean and idiomatic. Worth remembering for future ESM/CJS interop bugs where test resolution diverges from production.

## Zsh gotcha: `gh api` with `?ref=` query string

`gh api repos/.../contents/path.ts?ref=branch-name` triggers zsh glob expansion on the `?`. Must quote the whole path: `gh api "repos/.../contents/path.ts?ref=branch-name"`. First three API calls in this session failed with "no matches found" until I quoted them.
