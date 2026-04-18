---
date: 2026-04-18
topic: Vitest 4.x xfail API change + xfail seed cluster execution
---

# Vitest 4.x: it.failing removed, replaced by it.fails

## Finding

`it.failing` was removed in Vitest 4.x. The correct API is `it.fails`.

```typescript
// WRONG — throws TypeError: it.failing is not a function (Vitest 4.x)
it.failing("test name", async () => { ... });

// CORRECT
it.fails("test name", async () => { ... });
```

`it.todo` is still available for bodyless placeholders.

**Impact:** PRs #153 (F1/F2 auth) and #154 (B3 signed-urls) both use `it.failing` in their xfail
tests. These tests will throw TypeError when Vitest runs them. Must be fixed before those PRs merge.

## it.fails with no body throws

Unlike Jest, Vitest's `it.fails` requires a callable body. Bodyless calls (even with `it.failing`)
throw a TypeError at test collection time (not just at runtime). Always provide a body.

## Correct xfail pattern for unimplemented modules

For modules not yet on main, the cleanest xfail body is a dynamic import that will fail:

```typescript
it.fails("description", async () => {
  const { fn } = await import("../path/to/not-yet-existing-module.js");
  // ... assertions
});
```

The import throws MODULE_NOT_FOUND → test fails → it.fails records it as expected-failure.
No need for explicit `throw new Error("not implemented")` — the import failure is clean and
self-documenting.

## Vitest 4.x exit code on it.fails

Vitest exits 0 when all `it.fails` tests fail as expected (they're "passing" from the suite
perspective). Exit code 1 only if an `it.fails` test unexpectedly passes.

## Health test: it.todo placeholder vs regular test

When the implementation already exists (health endpoint), the correct action is:
- Rename from `health.xfail.test.ts` → `health.test.ts`
- Use regular `it(...)` not `it.fails`
- Add supertest to devDependencies

## Supertest in Vitest workspace

Vitest and supertest must be hoisted to root node_modules in the npm workspace.
Running `npm install` from the workspace root installs both. Running from a
subdirectory or a worktree requires running `npm install` from the worktree root.

## PR #170 duplication

A `chore/health-xfail-flip` branch (PR #170) already existed with overlapping changes
(health flip + B1 fix). Always check existing open PRs before starting similar work.
`gh pr list --state all | grep <topic>` before branching.
