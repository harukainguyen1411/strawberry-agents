# 2026-04-19 V0.6 EU Decimal + Phantom BUY Fix

## Session
PR #40 changes-requested from Senna. Two bugs in T212 CSV parser.

## What Happened

### Bug 1: EU comma-decimal normalization
`parseFloat("1.234,56")` returns `1.234`, not `1234.56`. Fix: `parseDecimal()` helper
uses regex `/^\d{1,3}(\.\d{3})*,\d+$/` to detect EU format before calling `parseFloat`.
Standard format falls through to `parseFloat` with thousands-comma strip.

### Bug 2: Phantom BUYs from non-trade rows
`action.toLowerCase().includes('sell') ? 'SELL' : 'BUY'` — any non-sell action
(Dividend, Deposit, Interest, Fee, etc.) becomes a phantom BUY. Fix: `TRADE_ACTIONS`
allowlist (`market buy`, `market sell`, `limit buy`, `limit sell`); rows with other
actions `continue` before any validation.

## Xfail Split Commit Pattern

Split into two fix commits required care:

1. Xfail commit (both bugs): both A.4.11 + A.4.12 as `it.fails()` — both correctly
   expected to fail (26 pass + 2 expected fail)
2. Fix commit 1 (EU decimal): A.4.11 flipped to `it()`, A.4.12 stays `it.fails()`,
   TRADE_ACTIONS NOT yet added — 27 pass + 1 expected fail
3. Fix commit 2 (phantom BUY): TRADE_ACTIONS added + continue, A.4.12 flipped to
   `it()` — 28 pass

The intermediate state (step 2) must have A.4.12 still as `it.fails()` for the
pre-commit hook to pass. Accidentally flipping A.4.12 in the same edit as A.4.11
will make the intermediate commit red.

## it.fails() with async tests in Vitest 4.1.4

`it.fails()` with async tests works fine in isolation (verified with minimal test).
But if you accidentally flip `it.fails()` → `it()` while the underlying bug is still
present, the test fails immediately as a normal test failure — not "expected fail".
The distinction: `it.fails()` catches the AssertionError and marks it as expected
failure; `it()` exposes the AssertionError as a test failure.

## Diverged Branch

Local branch was ahead by 8 commits vs remote at 65 — parallel histories from prior
sessions. Used `git stash` → `git fetch` → `git merge origin/branch` → `git stash pop`
to reconcile (Rule 11: never rebase). Stash preserved the in-progress xfail edits
through the merge.

## Commit Messages Used
- `test(V0.6): xfail tests for EU decimal parsing and phantom BUY classifier`
- `fix(V0.6): parseFloat handles EU decimal format`
- `fix(V0.6): skip non-trade rows in T212 classifier`
