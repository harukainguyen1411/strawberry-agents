/**
 * Unit test: resolveRetryPolicies() .default fallback path
 *
 * Senna gap identified 2026-04-24: under vitest, slackWebApi.retryPolicies is
 * smoothed to the namespace mock so the `.default` fallback branch is never
 * exercised. This test passes a stub namespace where retryPolicies === undefined
 * and verifies resolveRetryPolicies() reaches the CJS .default wrapper path.
 *
 * No vi.mock needed — resolveRetryPolicies accepts an optional ns parameter
 * for unit testability without triggering vitest's mock-export validation.
 *
 * Plan: plans/approved/personal/2026-04-24-slack-mcp-node25-cjs-fix
 *       plans/approved/personal/2026-04-24-mcp-consolidation-strawberry-to-strawberry-agents.md
 *
 * xfail marker (Rule 12): pre-implementation commit — will be flipped to live
 * after server.ts is updated to accept the ns parameter.
 */

import { test, expect } from "vitest";
import { resolveRetryPolicies } from "../src/server.js";

test(
  "2026-04-24-mcp-consolidation: resolveRetryPolicies() falls back to .default.retryPolicies when namespace retryPolicies is undefined",
  () => {
    const fakeRetryPolicies = { fiveRetriesInFiveMinutes: { retries: 5 } };

    // Stub: namespace has no top-level retryPolicies, but .default.retryPolicies exists
    // (simulates Node 25 CJS real runtime where module.exports wraps into .default)
    const stubNamespace = {
      WebClient: class MockWebClient {},
      retryPolicies: undefined,
      default: { retryPolicies: fakeRetryPolicies },
    };

    const result = resolveRetryPolicies(stubNamespace);
    expect(result).toBeDefined();
    expect(result.fiveRetriesInFiveMinutes).toBeDefined();
  }
);
