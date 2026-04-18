# G1 routing skeleton — 2026-04-18

## What was built

React Router v6 routing skeleton for `dashboards/test-dashboard`. Routes: `/`, `/runs/:id`, `/commits/:sha`, `/types/:type`, `/login`, `/monitoring/*` (reserved), `*` (404).

## Key decisions

- React Router v6 chosen over TanStack Router — simpler API for a plain skeleton; either is fine per ADR §8.
- `/monitoring/*` gets an explicit named component (`MonitoringReserved`) placed before the `*` catch-all. This is the load-bearing constraint from ADR §10 — the catch-all must not swallow `/monitoring/*`.
- Test files excluded from `tsc` via `tsconfig.json` `exclude` patterns — required because `it.todo` xfail stubs reference `it` which is not in scope during build.
- xfail committed as `it.todo` (not `it.failing`) to match A1 precedent — Vitest isn't installed yet (C1 pending).

## PR

PR #152 stacked on `chore/a1-dashboards-skeleton` (A1, PR #147). Cannot merge until A1 merges.

## Blockers for G2+

G2 (login + Firebase Auth) depends on G1 being merged. G2 is straightforward once A1+G1 land.
