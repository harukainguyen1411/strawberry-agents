# Stacked-PR routers forward-reference sibling-PR views

**Date:** 2026-04-19 (S58)

## Pattern

When a feature stack is authored as "develop linearly, ship linearly" but the landing order breaks (PRs land out of order, some close without merging), the `router/index.ts` in each branch can end up statically importing views that only exist in sibling or later PRs. Each PR's standalone build then fails with `ENOENT: no such file or directory` on the missing view.

S58 evidence: the portfolio V0.2–V0.11 stack.
- #32 V0.2 router imported `views/CsvImport.vue` (ships in V0.11)
- #44 V0.10 router imported `views/auth/SignInCallbackView.vue` (ships in V0.2)
- #43 V0.9, #45 V0.11 had similar forward-refs
- Each PR's own CI was red on `Lint + Test + Build (affected)` with the same class of error

## Fix

Dispatch the stack's author (here, Jayce) across ALL branches at once. Have them:

1. Audit each branch's `router/index.ts` against what exists on that branch.
2. Cut routes that reference views not present in the branch + main ancestors.
3. Fix any secondary TS errors (unused imports, default-vs-named import mismatches, strictness regressions) exposed by the build.
4. Push per-branch; each PR drops to REVIEW_REQUIRED but is then independently mergeable.

This is O(1) across the stack when done by the author in a single dispatch, vs O(N) retries if Ekkos keep hitting the same class of bug one PR at a time.

## What NOT to do

- Don't assume an APPROVED + MERGEABLE stacked PR is actually buildable standalone. Run the per-branch build locally or check the Lint+Test+Build CI check before merging.
- Don't try to fix forward-refs from main-side after the fact — the routes need to live per-branch, not on main.
- Don't use dynamic `() => import(...)` as a fallback — Vite/Rollup still resolves the chunk path at build time, so ENOENT still fires.

## Related

- S57 learning `2026-04-19-stacked-pr-base-check.md` — always check `baseRefName` before merging a stacked PR.
- The zero-diff PR pattern (S57 #56 + S58 #43): when a stacked PR's content lands via siblings through main, the PR collapses to zero-diff and should be closed as no-op, not merged.
