# PR #58 — emulator-boot stale indexes assertion (approve)

- Repo: harukainguyen1411/strawberry-app, SHA 9bcadc6.
- Single-file test-only fix: `apps/myapps/portfolio-tracker/functions/__tests__/emulator-boot.test.ts`, +13/-3.
- Background: V0.1 asserted `indexes: []`. V0.3 (PR #33) intentionally added `trades.executedAt DESC` composite. Test never updated -> main red.
- Fix flips negative guard ("must be empty") to positive guard (V0.3 index must be present).

## Why I approved

- Assertion verified against live `firestore.indexes.json` at HEAD — structure matches (`collectionGroup: trades`, `fieldPath: executedAt`, `order: DESCENDING`).
- Not over-fit: `.find` with predicates, no array-length or deep-equal. Tolerant of future added indexes.
- `f.fields?.some` null-safe; inline type annotation avoids implicit any.
- TDD exemption legit — test-only, no production/schema change.

## Review heuristic reinforced

When a test is flipped from negative ("should be X") to positive guard ("should contain Y"):

1. Confirm Y actually exists in the production artifact at HEAD (not just the PR body claim).
2. Check the predicate isn't so strict it rejects innocuous future additions (length checks, deep-equal).
3. Check it isn't so loose it accepts the old broken state (e.g. `indexes.length >= 0` — meaningless).

PR #58 passed all three.
