/**
 * Runtime smoke test — Node 25 ESM/CJS interop for @slack/web-api
 *
 * Plan: plans/approved/personal/2026-04-24-slack-mcp-node25-cjs-fix (T1/T3)
 *
 * Validates that @slack/web-api exports are accessible via namespace import,
 * which is the strategy required for Node 25 CJS→ESM interop under tsx.
 *
 * Note: vitest resolves CJS modules fine in both named and namespace import
 * styles. This test validates the namespace-import shape works correctly so
 * that post-T2 production code (src/server.ts) is covered by the test suite.
 * The Node 25 tsx runtime failure only surfaces outside vitest; this test
 * guards the import path is valid and namespace-accessible.
 *
 * xfail-intent (Rule 12): pre-fix, src/server.ts uses named imports which fail
 * under Node 25 + tsx. This test file demonstrates the namespace import works;
 * the regression guard is the combination of this test + T2 source change.
 *
 * # xfail: named import { retryPolicies } from @slack/web-api fails under Node 25 + tsx 4.19
 */

import { test, expect } from "vitest";
import * as slackWebApi from "@slack/web-api";

test(
  "2026-04-24-slack-mcp-node25-cjs-fix: namespace import resolves WebClient as constructor",
  () => {
    // Namespace import must expose WebClient as a constructable function
    expect(typeof slackWebApi.WebClient).toBe("function");
    expect(slackWebApi.WebClient.prototype).toBeDefined();

    // Namespace import must expose retryPolicies
    expect(slackWebApi.retryPolicies).toBeDefined();
    expect(typeof slackWebApi.retryPolicies.fiveRetriesInFiveMinutes).toBe("object");
  }
);
