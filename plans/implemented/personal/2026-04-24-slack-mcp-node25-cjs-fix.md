---
title: Slack MCP — Node 25 CJS interop fix for @slack/web-api
slug: 2026-04-24-slack-mcp-node25-cjs-fix
concern: personal
status: implemented
complexity: quick
owner: karma
planner: karma
implementer: talon
created: 2026-04-24
target_repo: Duongntd/strawberry
target_path: mcps/slack/
tests_required: true
orianna_gate_version: 2
---

## Context

The Slack MCP server at `~/Documents/Personal/strawberry/mcps/slack/` fails to boot under Node 25.4.0 + tsx 4.19. Line 11 of `src/server.ts` does `import { WebClient, retryPolicies } from "@slack/web-api"`, but `@slack/web-api@7.15.1` is a pure-CJS package (no `type`, no `module`, no `exports` field in its `package.json`). Node 25's ESM loader cannot statically resolve the named re-exports and throws at runtime: `SyntaxError: The requested module '@slack/web-api' does not provide an export named 'retryPolicies'`.

Ad-hoc source-only fixes (default-import + destructure; `createRequire`) break the test suite: 40 tests across 5 files rely on `vi.mock("@slack/web-api", () => ({ WebClient, retryPolicies }))` — the named-export mock shape. Switching source to read a default export causes `No "default" export is defined on the "@slack/web-api" mock` in 37 tests. Fix must co-update source import strategy AND every `vi.mock` call site + the test harness in one consistent shape.

Chosen strategy: **namespace import** (`import * as slackWebApi from "@slack/web-api"`) in `src/server.ts`, accessing `slackWebApi.WebClient` and `slackWebApi.retryPolicies` at call sites. Namespace imports work reliably with Node 25's CJS→ESM interop (Node wraps CJS `module.exports` as the namespace object). Test mocks stay in named-export factory shape — that shape already produces a compatible namespace when resolved via `import *`. No change needed to `vi.mock` factories; only the source changes. This is the minimal-blast-radius option.

Plan file lives in strawberry-agents (all plans do); implementation happens in `Duongntd/strawberry` repo.

## Tasks

### T1 — xfail runtime smoke test
- kind: test
- estimate_minutes: 15
- files: `mcps/slack/test/runtime-boot.test.ts` (new) <!-- orianna: ok -->
- detail: Add a vitest test that (a) does NOT `vi.mock("@slack/web-api")`, (b) dynamically `await import("../src/server.js")` (or imports `WebClient` from `@slack/web-api` directly with a namespace import) and asserts the module loads + `WebClient` is a constructable function. Mark `it.fails(...)` or `test.fails(...)` referencing this plan slug in the test name. This test must fail today (pre-fix) and pass after T2. Satisfies Rule 12 (xfail-first) for the branch.
- DoD: Test file committed; `pnpm test` (or `npm test`) shows the test in the `expected-to-fail` bucket green; other 40 tests still pass.

### T2 — namespace-import refactor in server.ts
- kind: refactor
- estimate_minutes: 25
- files: `mcps/slack/src/server.ts`
- detail: Replace `import { WebClient, retryPolicies } from "@slack/web-api"` with `import * as slackWebApi from "@slack/web-api"`. Update all in-file references: `new WebClient(...)` becomes `new slackWebApi.WebClient(...)`; `retryPolicies.fiveRetriesInFiveMinutes` (or whichever policy is referenced) becomes `slackWebApi.retryPolicies.fiveRetriesInFiveMinutes`. Preserve the existing typing surface (type-only imports for `WebClient` type, if any, can use `import type { WebClient } from "@slack/web-api"` — Node strips type-only imports at runtime so this is CJS-safe). Update the inline comment on line 81 if its text no longer matches.
- DoD: `src/server.ts` compiles under `tsc --noEmit`; no named-value imports from `@slack/web-api` remain.

### T3 — flip xfail to live and verify suite
- kind: test
- estimate_minutes: 15
- files: `mcps/slack/test/runtime-boot.test.ts`
- detail: Remove the `.fails` marker from the T1 smoke test. Run `npm test` (or `pnpm test`) in `mcps/slack/`. All 41 tests (40 existing + 1 new) must pass. If any existing test now fails due to the namespace refactor changing a mock-dispatch path (unlikely — mocks intercept at module-specifier level and `import *` reads the same intercepted module record), fix by adjusting only the affected test's mock factory to expose a `default` key mirroring the named exports; leave the other files alone. Namespace imports against named-export factories work natively in vitest.
- DoD: `npm test` green; no `.fails` / `it.fails` / `test.fails` markers remain; no `.skip` added.

### T4 — local runtime smoke + PR
- kind: verify
- estimate_minutes: 25
- files: `mcps/slack/scripts/start.sh` (no changes expected; used as-is)
- detail: From `mcps/slack/`, run `bash scripts/start.sh` under Node 25 and confirm the MCP server boots past the previous `SyntaxError` point. If SLACK tokens are present in local secrets, let it connect and log a successful `WebClient` handshake; if absent, confirm the failure is a missing-token error rather than the CJS import error, and include a `QA-Waiver: slack tokens unavailable in local env — runtime-boot test covers import path` line in the PR body. Open PR against `Duongntd/strawberry` main from a worktree branch created via `scripts/safe-checkout.sh`. Commit messages use `fix:` (touches `mcps/**` which is app-adjacent; follow repo's convention — if Duongntd/strawberry treats `mcps/**` outside `apps/**`, use `chore:` instead, per Rule 5).
- DoD: PR opened; CI green; manual `start.sh` run logged in PR description; Duong or a reviewer account approves; merge only after green + approval (Rule 18).

## Test plan

Invariants protected:

1. **Runtime import works under Node 25 + tsx** — T1/T3 `runtime-boot.test.ts` imports `@slack/web-api` without the `vi.mock` intercept and validates `WebClient` is a constructor. This is the regression guard for the exact failure reported.
2. **Existing mock-based tests still exercise the tool-handler logic** — the 40 pre-existing tests across `bot-tools`, `errors`, `from-agent`, `list-shapes`, `user-tools` all continue passing unchanged after T2. Their `vi.mock` factories return named-export shape; namespace-import source resolves against that identically.
3. **No type-only imports leak into runtime** — `tsc --noEmit` passes (T2 DoD) confirms TypeScript elaboration drops any `import type` uses correctly.

Manual verification: T4 boots the server against real Slack API (or fails on missing tokens, which proves the import path is healed).

## References

- Failing symptom: `SyntaxError: The requested module '@slack/web-api' does not provide an export named 'retryPolicies'` at `src/server.ts:11` under Node 25.4.0 + tsx 4.19.
- `@slack/web-api@7.15.1` `package.json` — pure CJS, no `exports` field. Node 25 ESM loader requires namespace-import shape for interop.
- Rule 12 (xfail-first), Rule 5 (commit prefix scoping), Rule 18 (no admin merge bypass), Rule 3 (worktree via safe-checkout).

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has clear owner (karma planner, talon implementer), concrete per-task DoD, explicit xfail-first test in T1 satisfying Rule 12, and cross-references to Rules 3/5/18. Namespace-import strategy is well-justified as minimal-blast-radius and preserves the existing 40-test `vi.mock` surface unchanged. No TBDs, no unresolved decisions. Implementation target (`Duongntd/strawberry`) explicitly noted to avoid concern confusion.

## Orianna approval — approved → implemented

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** approved → implemented
- **Rationale:** Fully shipped in PR #44 (merge commit `80b78802`). Namespace-import refactor in `src/server.ts` plus `resolveRetryPolicies(ns?)` helper with `.default` fallback landed together; test suite is 42/42 green including a new `.default`-fallback unit test beyond the originally planned scope. All four tasks satisfied — runtime-boot xfail test added then flipped, type-check green, manual start.sh smoke documented. Plan carried into PR #44's source branch as part of the consolidated slack work.

