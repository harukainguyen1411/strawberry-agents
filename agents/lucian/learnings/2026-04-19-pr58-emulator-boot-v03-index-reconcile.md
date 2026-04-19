# PR #58 — emulator-boot test reconciled to V0.3 trades index

**Verdict:** Approved (fidelity-clean).
**SHA:** 9bcadc6 · **Branch:** fix/main-red-portfolio-cascade-residue

## What it was
V0.1 emulator-boot test asserted `firestore.indexes.json` has empty `indexes` array.
V0.3 (PR #33) intentionally added `trades.executedAt DESCENDING` composite index but
did not update the V0.1 test, leaving main red. PR #58 reconciles the assertion.

## Fidelity signal
- Single file, test-only, zero product code.
- New assertion is stricter than old (pins the V0.3 schema) — strengthens ADR
  fidelity rather than weakening it. That is the right direction for a
  reconciliation: encode the new contract, don't just loosen.
- Production `firestore.indexes.json` at HEAD confirms the trades.executedAt DESC
  index actually ships — the test was stale, not the schema.

## Rule 12 / 13 applicability
- **Rule 12 (xfail-first):** N/A when reconciling a stale test to already-shipped
  behavior. No new feature surface → no xfail precursor required.
- **Rule 13 (regression test):** N/A when the fix IS the test update. The
  reconciled assertion itself becomes the regression guard.
- Pattern: when a prior version shipped a schema change without updating an
  earlier version's test, treat the test reconciliation as TDD-exempt **provided**
  the diff touches only test code and the new assertion pins the shipped contract.

## Pitfall to watch on similar PRs
If a "test reconciliation" diff also touches product code, or loosens the
assertion to `length > 0` instead of pinning the specific new field, that is
structural divergence — request changes. Here the author correctly pinned
`collectionGroup === 'trades'` + `fieldPath === 'executedAt'` + `order === 'DESCENDING'`.
