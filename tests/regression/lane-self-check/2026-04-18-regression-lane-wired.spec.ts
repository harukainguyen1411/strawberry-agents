// Regression: J1 — regression lane scaffold (plans/approved/2026-04-17-test-dashboard-phase1-tasks.md)
// Proves tests/regression/ exists as a durable home for future regression tests.

import { existsSync } from "fs";
import { resolve } from "path";
import { it, expect, describe } from "vitest";

describe("regression lane", () => {
  it("tests/regression/ directory exists in the repo", () => {
    const regressionDir = resolve(__dirname, "../../../");
    expect(existsSync(resolve(regressionDir, "tests/regression"))).toBe(true);
  });
});
