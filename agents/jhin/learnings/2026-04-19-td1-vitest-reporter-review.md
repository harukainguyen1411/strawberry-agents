---
date: 2026-04-19
topic: TD.1 vitest-reporter-tests-dashboard review
pr: harukainguyen1411/strawberry-app#49
---

# TD.1 Vitest Reporter Review Learnings

## Silent schema-validation skip pattern

When a test guards AJV validation with `if (fs.existsSync(schemaPath))`, the test passes silently
in CI and on any machine without the co-located sibling repo. This is a common false-safety trap —
the test *looks* like it validates but does nothing when the schema is absent.

**Pattern to flag:** `if (fs.existsSync(schemaPath)) { validate(...) }` around AJV blocks.
Should be: fail hard if the schema is expected to exist, OR vendor a copy and assert byte-equality.

## `&&` vs `||` precedence in while-loop exit conditions

In TypeScript/JS, `&&` binds tighter than `||`. A condition like:

```ts
while (a && b.type !== 'suite' || c?.filepath === undefined)
```

evaluates as `(a && b.type !== 'suite') || (c?.filepath === undefined)`, not the likely intended
`(a && b.type !== 'suite') && (c?.filepath === undefined)`. Flag any multi-operator while conditions
without explicit parentheses.

## Absolute-path storage in cross-run registries

Reporters that store `file.filepath` (absolute) in a persistent JSON registry will prune all
historical entries on the next run from a different machine or CWD. Relative paths are more
portable for registry entries that survive across machines.

## OQ-A schema location (TD.2 reminder)

The plan's OQ-A explicitly defers the canonical-schema decision to TD.2. Any cross-repo relative
path chosen in TD.1 is a temporary stand-in. TD.2 must pick option (a) vendor+CI-check or
option (b) relative-path+hard-fail-if-absent, and must update both writer packages.
