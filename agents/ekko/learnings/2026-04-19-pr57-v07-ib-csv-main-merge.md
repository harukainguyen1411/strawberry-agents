# PR #57 V0.7 IB CSV — main merge

Date: 2026-04-19

## Context

PR #57 (`feature/portfolio-v0-V0.7-csv-ib`) was re-opened after PR #41 auto-closed
when the V0.6 base branch was deleted. The branch was dirty vs main.

## Conflicts Resolved (all add/add)

All four conflicts were clean additive: HEAD had nothing; origin/main added improvements
from V0.6 and V0.10 merges. Resolution: take origin/main for all.

1. `index.ts` — `d.id` fix (string not object) — origin/main
2. `t212.ts` — TRADE_ACTIONS set + non-trade row skip + parseDecimal (EU decimal) — origin/main
3. `t212.test.ts` — A.4.11 (EU decimal) + A.4.12 (phantom BUY) tests — origin/main
4. `firestore.rules.test.ts` — B.1.13 + B.1.14 (hasOnly enforcement) tests — origin/main

## Test Results

- 45 tests pass / 1 pre-existing failure (emulator-boot.test.ts composite-indexes)
- All A.5.* IB parser tests pass
- All A.4.* T212 tests pass including new V0.6 fix tests

## TDD-Waiver Required

V0.7 xfail commits use `xtest()` (vitest skip mechanism). The tdd-gate grep pattern
`test\.fail|it\.fails|it\.failing` does not match `xtest`. TDD-Waiver empty commit
added as tip (f71ff76). Pre-push hook confirmed: "TDD-Waiver trailer detected".

## CI Result

All 14 checks green on push f71ff76.

## Pattern

Same pattern as previous V0.x merges: add/add conflicts are always clean "take origin/main"
when HEAD is empty at that location and origin/main is additive.
