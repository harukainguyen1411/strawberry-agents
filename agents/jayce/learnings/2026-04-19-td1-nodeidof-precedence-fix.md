# 2026-04-19 — TD.1 nodeIdOf precedence fix (Jhin PR #49 finding #2)

## What happened

Fixed a operator-precedence bug in `nodeIdOf` in `packages/vitest-reporter-tests-dashboard/src/index.ts`.

## The bug

```ts
// Buggy: evaluates as (A && B) || C
while (current && current.type !== 'suite' || (current as Suite)?.filepath === undefined)

// Fixed: A && (B || C) — "walk up while not at a suite with a filepath"
while (current && (current.type !== 'suite' || (current as Suite).filepath === undefined))
```

`&&` binds tighter than `||`, so without grouping the C arm (`filepath === undefined`) was always true for Task nodes (which have no `.filepath`), making the loop condition nearly always true regardless of the first half.

## Analysis note

For well-formed Vitest task trees with the existing `if (!parent) break` guard, the bug doesn't produce observable wrong output — both expressions produce the same traversal. The divergence only occurs when `current` becomes falsy (A=false) while C is true, which the break guard prevents. So in practice this is a "works by accident" situation. The fix is still correct and necessary; the regression test pins the intended traversal for nested describe blocks.

## Regression test approach

Built a full nested suite chain with explicit `.suite` back-references (File → Describe → Task) and asserted `nodeId === filepath::describe_name::test_name`. This exercises the traversal path and pins correct behavior even though both buggy and fixed code happen to produce the same output for well-formed trees.

## Rule 13 application

Bug fix committed with regression test on same branch — correct per Rule 13. Regression test commit preceded the fix commit.

## Commit SHAs

- `bba5e62` — regression test
- `c63ddf7` — fix

## Deferred scope

Jhin findings #1 (schema validation silent-skip) and #3 (absolute-path registry) deferred to TD.2 per Duong.
