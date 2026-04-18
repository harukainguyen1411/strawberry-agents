// xfail: J1 — regression lane scaffold (plans/approved/2026-04-17-test-dashboard-phase1-tasks.md)
// Self-referential proof: this file fails before the lane exists, passes once it does.
// Bug reproduced: regression/ directory missing → no durable home for future regression tests.

import { existsSync } from "fs";
import { resolve } from "path";
import { it, expect, describe } from "vitest";

describe("regression lane", () => {
  it.failing("tests/regression/ directory exists in the repo", () => {
    // This test is seeded as xfail. It will flip to passing once the lane scaffold
    // (tests/regression/.gitkeep) is committed on this branch, at which point the
    // it.failing marker is removed.
    const regressionDir = resolve(__dirname, "../../../");
    expect(existsSync(resolve(regressionDir, "tests/regression"))).toBe(true);
  });
});
