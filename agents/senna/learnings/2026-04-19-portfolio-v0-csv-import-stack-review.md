# 2026-04-19 — Portfolio V0.4–V0.8 stacked PR review

Reviewed 5 stacked PRs on `harukainguyen1411/strawberry-app`: V0.4 handler surface (#34), V0.5 Money/FX (#36), V0.6 T212 parser (#40), V0.7 IB parser (#41), V0.8 importCsv (#42).

## Results
- #34 REQUEST-CHANGES — real bug in `portfolio_get_snapshot` (id: d.data() instead of d.id; spread called twice). Position doc-key collision across brokers flagged as design concern (deferred to Lucian).
- #36 APPROVE — Money/FX is clean. Noted float-precision tech-debt and non-reciprocal seed rates, both as v1 follow-up.
- #40 REQUEST-CHANGES — T212 parser footguns: `parseFloat` on EU-locale numbers truncates silently; action→side uses substring match so Dividend/Deposit/etc. become phantom BUYs; Date parsed with `Z` mislabels tz.
- #41 REQUEST-CHANGES — IB parser: sign-based side classification misclassifies shorts/covers; Asset Category not in required headers so non-Stocks silently parse; same Z-tz issue.
- #42 REQUEST-CHANGES — DIRTY merge; plus `id: undefined` in Firestore set will throw against real firebase-admin (passes against in-memory mock); TOCTOU in get-then-set idempotency (use `create()` instead).

## Patterns worth re-using

### In-memory Firestore mocks mask `ignoreUndefinedProperties` bugs
If a test mock accepts `undefined` field values silently, any `set({ ...trade, id: undefined })` pattern will pass unit tests and fail in prod. Grep the repo for `ignoreUndefinedProperties` — if absent, flag every `undefined` field literal as critical. Saw this on PR42.

### "UNSTABLE" mergeStateStatus ≠ failing checks
GitHub's `UNSTABLE` label on a PR with all-cancelled checks is usually a benign concurrency supersede. Pull `gh api .../actions/runs/<id> --jq .conclusion` — if `cancelled`, not a code issue. Don't over-index on the label. Saw this on PR40.

### DIRTY merge verification
`gh api repos/.../pulls/<n>` gives real-time `mergeable` state; `git merge-tree` isn't enough since it does trivial merges. Use `git merge --no-commit` on the PR's actual base SHA (`.base.sha`) to reproduce conflicts and pinpoint files. Saw this on PR42.

### CSV parser footgun taxonomy
For broker CSVs consistently review:
1. `parseFloat` on locale-formatted numbers (`1,234.56` vs `1.234,56`)
2. Signed-quantity → side mapping (shorts vs longs)
3. Asset Category / product type filter (stocks vs options/futures)
4. Date parsing assuming UTC when source is broker-local
5. Thousands separator / decimal comma
6. Non-trade rows (Dividend, Interest, Deposit) classified as trades
7. Deterministic ID fallback using non-cryptographic hash (collision → silent dedup)
8. Position math: currency mismatch when averaging across exchanges

All of these recurred across T212 and IB parsers here.

### `create()` over `get()+set()` for idempotent writes
When enforcing immutability by "exists → skip", always prefer Firestore `doc.create()` which atomically rejects on exists. `get() then set()` has a TOCTOU race that a concurrent writer can exploit to overwrite the "immutable" doc.

## Reviewer-auth note
`scripts/reviewer-auth.sh gh pr review` worked cleanly for all 5 PRs, preflight returned `strawberry-reviewers`. No identity drift.
