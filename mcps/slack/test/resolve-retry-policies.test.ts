/**
 * Unit test: resolveRetryPolicies() .default fallback path
 *
 * Senna gap identified 2026-04-24: under vitest, slackWebApi.retryPolicies is
 * smoothed to the namespace mock so the `.default` fallback branch is never
 * exercised. This test stubs a namespace where retryPolicies === undefined
 * and verifies resolveRetryPolicies() reaches the CJS .default wrapper path.
 *
 * Plan: plans/approved/personal/2026-04-24-slack-mcp-node25-cjs-fix
 *       plans/approved/personal/2026-04-24-mcp-consolidation-strawberry-to-strawberry-agents.md
 *
 * xfail marker: pre-flip — resolveRetryPolicies is exported from server.ts but we need
 * to verify the .default fallback path is exercised. This test.fails will be flipped to
 * a live test once we confirm the mock shape correctly isolates the fallback branch.
 */

import { test, expect, vi } from "vitest";

// Mock @slack/web-api so the namespace has retryPolicies === undefined
// but .default.retryPolicies is defined — simulating Node 25 CJS real runtime
vi.mock("@slack/web-api", () => {
  const fakeRetryPolicies = {
    fiveRetriesInFiveMinutes: { retries: 5 },
  };
  return {
    // retryPolicies absent from top-level namespace (undefined by omission)
    WebClient: class MockWebClient {},
    default: {
      retryPolicies: fakeRetryPolicies,
    },
  };
});

// Static import — vitest hoists vi.mock above imports so the mock is active
// when server.ts module is resolved. resolveRetryPolicies is exported for testability.
import { resolveRetryPolicies } from "../src/server.js";

test.fails(
  "2026-04-24-mcp-consolidation: resolveRetryPolicies() falls back to .default.retryPolicies when namespace retryPolicies is undefined",
  () => {
    const result = resolveRetryPolicies();
    expect(result).toBeDefined();
    expect(result.fiveRetriesInFiveMinutes).toBeDefined();
  }
);
