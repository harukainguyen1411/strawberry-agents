---
name: Vitest it.fails vs it.failing
description: it.failing is Playwright's API; Vitest 4.x uses it.fails — wrong API silently registers 0 tests
type: feedback
---

`it.failing` is Playwright's xfail API. Vitest 4.x uses `it.fails`.

Using `it.failing` in a Vitest test file throws `TypeError: it.failing is not a function` — the file fails to parse and registers **zero tests**. This silently defeats TDD discipline (same pattern as the `exclude: ["**/*.xfail.test.ts"]` anti-pattern found in #151).

**Correct Vitest 4.x xfail pattern:**
```ts
it.fails("xfail: reason", () => {
  throw new Error("not implemented");
});
```

**Why:** Pyke's tdd-workflow-rules plan incorrectly referenced `it.failing`. All xfail files seeded before Vi's #170 correction may use the wrong API.

**How to apply:** When reviewing any `.xfail.test.ts` file, grep for `it.failing` — if present, flag as IMPORTANT before LGTM. Verified correct files use `it.fails`.
