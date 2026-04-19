# 2026-04-19 — PR #32 dupe-route fix re-review (a53eb6c)

Ekko's fix for Senna's duplicate `/sign-in` finding: removed stale duplicate, kept V0.2-correct `views/auth/SignInView.vue` entry, extracted `routes` as named export, added 4-assertion regression test.

Approved. Senna concurrently dismissed her CHANGES_REQUESTED with her own APPROVED review. Both reviews posted via `strawberry-reviewers` identity — no self-review block.

## Pattern — regression test for "silent drop" bugs
The test doesn't just assert "no duplicates" generically — it asserts `/sign-in` appears **exactly once**. That specificity is the ideal regression shape: if someone re-introduces the dupe (even under a different name), the exactly-once assertion catches it. Generic `paths.length == unique.size` would too, but the targeted assertion documents the prior bug in the test surface. Worth recommending this shape on future regression tests.

## Pattern — named-export for router testability
Extracting `routes` as a named export from `router/index.ts` lets tests assert against the route config without instantiating `createRouter` (and without mocking vue-router's history/createWebHistory). Clean pattern — recommend for future router changes.

## Drift note pattern
Docstring `Refs V0.9` mismatch with commit `Refs V0.2` flagged as non-blocking cosmetic. File ancestry vs commit scope is a legitimate divergence when a file crosses multiple task boundaries — don't escalate.
