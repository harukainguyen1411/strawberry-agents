# 2026-04-19 — PR #34 portfolio_get_snapshot id bug fix

## Context
Senna review finding on PR #34 (V0.4 portfolio-tools): `id: d.data()` in the positions
map set each position's `id` field to the full Firestore data object instead of the
document ID string (`d.id`). Broke v0 read path.

## Fix
- `id: d.data()` → `id: d.id, ...d.data()` in `portfolio_get_snapshot`
- Updated lambda type annotation: `{ data: () => unknown }` → `{ id: string; data: () => unknown }`
- Pattern already correct in `portfolio_get_trades` on line 49 — used that as reference

## xfail-first flow (Rule 12)
1. Committed xfail test with `it.fails()` first (59ecbf9)
2. Merged remote divergence (61 remote commits) with `git merge` — no rebase
3. Applied fix, flipped test to `it()`, confirmed 5/5 green
4. Committed fix (468e01d)

## Assertion pitfall
`expect(pos.id).not.toEqual(expect.objectContaining({}))` failed even when `pos.id`
was a string — Vitest's `objectContaining({})` matcher appears to match primitives.
Replaced with `expect(pos.id).not.toBeTypeOf('object')` which is unambiguous.

## Merge divergence
Local branch had 4 commits, remote had 61 — needed `git fetch` + `git merge origin/...`
before pushing. Must commit any staged work before merging (Rule 1).
