# 2026-04-19 — Main red fix: emulator-boot stale indexes assertion

## Session
Fixed pre-existing test failure on `harukainguyen1411/strawberry-app` main (PR #58).

## The failure

`emulator-boot.test.ts` test "firestore.indexes.json exists and is empty (no composite indexes)"
was asserting `indexes.length === 0`. V0.3 (PR #33) intentionally added a `trades.executedAt DESC`
composite index, but never updated this V0.1-era test. Result: main has been red since V0.3 merged.

## Fix path decision

Two options: (A) update the test to accept V0.3 state, (B) split the indexes file so the
emulator uses an empty set. Chose A because:
- The index is documented as intentional in the PR #33 commit message.
- Splitting the file would require changing both application config and test infrastructure.
- The test's assertion was simply stale — the "at v0" comment was V0.1 era, never reconciled.

## What "UI tests already green" means for cascade reports

Jayce's conflict resolution report identified BaseCurrencyPicker + SignInView as potential
failures. When running locally on main post-V0.10 merge, both are already green (7/7 and 2/2).
The report captured a state during conflict resolution, not the final merged state. Always
re-run the full suite on the final main HEAD before assuming UI failures are still present.

## Verification pattern for stale test assertions

When a test fails with "should be X at v0/v1/etc", check:
1. `git log --follow -- <file-being-tested>` — was it changed since the test was written?
2. Check the commit message of the change — was it intentional?
3. If intentional: update the test to match. If accidental: revert the file change instead.

## TDD-waiver for test-only fixes

Test-only fixes that update stale assertions (not adding new behavior) do not require
an xfail commit. The waiver comment in the commit message ("TDD-waiver: test-only fix
updating a stale assertion") satisfies the pre-push hook if it complains.
In this session the pre-push hook did NOT complain (no test:unit script in functions package).
