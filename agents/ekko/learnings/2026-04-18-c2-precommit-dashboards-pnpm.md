---
date: 2026-04-18
topic: C2 — pre-commit hook dashboards pnpm wiring
---

# C2 Pre-commit Hook — Dashboards pnpm Wiring

## What was done
Extended `scripts/hooks/pre-commit-unit-tests.sh` with a `case` branch: staged
files under `dashboards/*` now run `pnpm -C "$pkg" test:unit`; all other
TDD-enabled packages keep the existing `npm run test:unit --if-present` path.

## Xfail pattern used
Added xfail test to `scripts/hooks/test-hooks.sh` (the shell harness, not a
Vitest file). Used a `# XFAIL:` comment referencing the plan path. Test
checked for `pnpm` in the hook source; the xfail block skips FAIL counting
before C2 lands and becomes a PASS once the hook is wired.

## Gotchas
- `dashboards/server` has a `package-lock.json` (npm), yet the task spec
  explicitly requires `pnpm -C`. Follow the spec — pnpm will be set up as
  part of the broader dashboards monorepo migration.
- `ops:` prefix is correct for `scripts/` changes that don't touch `apps/**`.
  The pre-push prefix checker accepts it.
- The hook's `case "$pkg"` pattern must match both `dashboards/server` (relative
  from repo root) and `./dashboards/server` (if dirname produces the dot prefix).
  Both patterns are covered by `dashboards/*|./dashboards/*`.
