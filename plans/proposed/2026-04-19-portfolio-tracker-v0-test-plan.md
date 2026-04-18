---
status: proposed
owner: caitlyn
date: 2026-04-19
title: Portfolio Tracker v0 — Test Plan
parent_adr: plans/approved/2026-04-19-portfolio-tracker.md
parent_tasks: plans/proposed/2026-04-19-portfolio-tracker-v0-tasks.md
design_spec: agents/neeko/learnings/2026-04-19-portfolio-v0-design.md
target_repo: harukainguyen1411/strawberry-app
implementer: vi (T7)
---

# Portfolio Tracker v0 — Test Plan

Executable test plan for v0 of the Portfolio Tracker. Test IDs are aligned to Kayn's
implementation tasks `V0.1`–`V0.20`, and every test below is the **xfail-first** commit
that satisfies repo rule 12 (TDD gate). Vi (T7) executes from this file. Each section
specifies: framework, file path, fixtures, inputs, expected outputs, and the commit body
tag.

The plan is grouped by layer: **(A) Unit**, **(B) Integration (emulator)**, **(C) E2E
Playwright**, **(D) Edge cases & negative paths**, **(E) QA gate (rule 16)**.
A final **§F Coverage matrix** maps every V0.x task to its xfail test(s).

---

## Conventions

- **Test runner:** Vitest for unit + Vue Test Utils component tests; Jest only where
  `@firebase/rules-unit-testing` requires it (rules harness, V0.3); Playwright Test for
  E2E (V0.18).
- **Path root:** all test paths are relative to
  `harukainguyen1411/strawberry-app/apps/myapps/portfolio-tracker/`.
- **Fixture root:** `test/fixtures/` under the app.
- **xfail mechanism:**
  - Vitest/Jest: `it.fails(...)` for assertions that are expected to fail until
    implementation lands; flipped to `it(...)` in the implementation commit.
  - Playwright: `test.fixme(...)` until V0.18 implementation; flipped to `test(...)`.
- **Commit body tag:** every xfail commit body MUST contain `Refs V0.<n>` (literal),
  matching the task ID. Pre-push hook + `tdd-gate.yml` check this.
- **Emulator:** Firebase emulators (`auth`, `firestore`, `functions`) are started by the
  test harness via `firebase emulators:exec` — never by ambient `firebase emulators:start`
  in CI; tests that need the emulator declare it.
- **Determinism:** all parser tests use checked-in fixtures; no network. FX rates are
  injected as a static map. `Date.now()` is stubbed where time matters.
- **No mocks at the rules layer.** Rules tests run against the real Firestore emulator —
  this is the rule-13 spirit ("don't mock what you ship") applied preemptively.
- **Two-user data isolation is a first-class invariant.** Every integration test that
  writes data writes as user A and reads as user B and asserts denied; this catches
  regressions in `firestore.rules` more reliably than a single dedicated test.

---

## A. Unit tests

### A.1 — Allowlist guard (`Refs V0.2`)

- **File:** `functions/__tests__/onSignIn.test.ts`
- **Framework:** Vitest
- **Subject:** `functions/onSignIn.ts` `beforeSignIn` blocking trigger.

| # | Input | Expected |
|---|---|---|
| A.1.1 | `event.data.email = "duong@allowed.test"` (in allowlist) | resolves; no throw |
| A.1.2 | `event.data.email = "duong+alias@allowed.test"` (alias of allowlisted) | **denied** — exact match only; throws `HttpsError("permission-denied")` |
| A.1.3 | `event.data.email = "stranger@example.test"` | throws `HttpsError("permission-denied")` |
| A.1.4 | `event.data.email = "DUONG@allowed.test"` (uppercase) | resolves — case-insensitive match (allowlist normalises to lowercase) |
| A.1.5 | `event.data.email` undefined | throws `HttpsError("invalid-argument")` |
| A.1.6 | allowlist file empty (misconfig) | throws `HttpsError("failed-precondition")` — fail closed, never open |

> A.1.2 + A.1.6 are the **must-have** tests. Plus-aliasing is a real attack vector and
> "fail closed on empty allowlist" prevents a broken deploy from opening signup to the
> world.

### A.2 — `Money` + FX `convert` (`Refs V0.5`)

- **File:** `functions/portfolio-tools/__tests__/money.test.ts`
- **Framework:** Vitest
- **Subject:** `functions/portfolio-tools/money.ts` `convert(amount, from, to, fxRates)`.

| # | Input | Expected |
|---|---|---|
| A.2.1 | `convert(100, 'USD', 'EUR', { 'USD->EUR': 0.92 })` | `{ amount: 92, currency: 'EUR' }` |
| A.2.2 | `convert(100, 'USD', 'USD', {})` | `{ amount: 100, currency: 'USD' }` (identity, no rate lookup) |
| A.2.3 | `convert(100, 'USD', 'EUR', { rates: { 'USD->EUR': 0.92 }, overrides: { 'USD->EUR': 0.93 } })` | `{ amount: 93, currency: 'EUR' }` (override beats base) |
| A.2.4 | `convert(100, 'USD', 'GBP', { 'USD->EUR': 0.92 })` | throws `FxRateMissingError('USD->GBP')` |
| A.2.5 | `convert(0, 'USD', 'EUR', { 'USD->EUR': 0.92 })` | `{ amount: 0, currency: 'EUR' }` |
| A.2.6 | `convert(-100, 'USD', 'EUR', { 'USD->EUR': 0.92 })` | `{ amount: -92, currency: 'EUR' }` (signed amounts allowed — used for losses/debits) |
| A.2.7 | `convert(100.005, 'USD', 'EUR', { 'USD->EUR': 0.92 })` | `{ amount: ≈92.0046, currency: 'EUR' }` — assert with `toBeCloseTo(92.0046, 4)`; document that `Money.amount` is a float at v0 (cent-level precision tolerable per Kayn V0.5 acceptance) |
| A.2.8 | unknown currency code in `to` (e.g. `'XXX'`) | throws `UnknownCurrencyError('XXX')` |

### A.3 — FX loader (`Refs V0.5`)

- **File:** `functions/portfolio-tools/__tests__/fx.test.ts`
- **Framework:** Vitest, `@firebase/rules-unit-testing` for emulator client
- **Subject:** `functions/portfolio-tools/fx.ts` `loadFx(uid)`.

| # | Setup | Expected |
|---|---|---|
| A.3.1 | seed `users/u1/meta/fx = { rates: {...}, overrides: {} }` | `loadFx('u1')` returns `{ rates, overrides: {}, updatedAt }` |
| A.3.2 | seed `users/u1/meta/fx` with both rates + overrides | overrides exposed unmerged; merging is `convert`'s job |
| A.3.3 | no `meta/fx` doc for `u1` | returns seed-default rates from `fxSeed.ts`; logs `console.warn` containing `meta/fx missing` (assert via spy) |
| A.3.4 | `meta/fx` exists but `rates` is missing key | `loadFx` returns whatever is there; `convert` is responsible for the missing-rate error |

### A.4 — T212 CSV parser (`Refs V0.6`)

- **File:** `functions/portfolio-tools/csv/__tests__/t212.test.ts`
- **Framework:** Vitest
- **Fixtures:**
  - `test/fixtures/t212-sample.csv` — real anonymized export (DV0-3). Until DV0-3 lands,
    use `test/fixtures/t212-synthetic.csv` derived from T212 docs schema; flip the
    fixture path in the V0.20 sign-off step.
  - `test/fixtures/t212-bad-headers.csv` — first row missing required columns.
  - `test/fixtures/t212-partial-bad.csv` — 47 rows where row 7 has missing price and
    row 14 has invalid date `2026/13/45`.
  - `test/fixtures/t212-empty.csv` — header row only, zero data rows.
  - `test/fixtures/t212-mixed-currency.csv` — trades in both USD and EUR.
- **Subject:** `parseT212Csv(text): { trades, positions, errors }`.

| # | Input | Expected |
|---|---|---|
| A.4.1 | `t212-sample.csv` (47 rows) | `trades.length === 47`, `positions.length === 12`, `errors.length === 0`. Snapshot first trade. |
| A.4.2 | `t212-bad-headers.csv` | `trades.length === 0`, `positions.length === 0`, `errors[0].kind === 'bad_headers'`, `errors[0].expected` lists required columns, `errors[0].received` lists actual headers |
| A.4.3 | `t212-partial-bad.csv` | `trades.length === 45`, `errors.length === 2`, `errors[0] = { row: 7, kind: 'missing_price' }`, `errors[1] = { row: 14, kind: 'bad_date', value: '2026/13/45' }` |
| A.4.4 | `t212-empty.csv` | `trades.length === 0`, `positions.length === 0`, `errors.length === 0` (empty is not an error) |
| A.4.5 | `t212-mixed-currency.csv` | every `trade.price.currency` is preserved as native (USD or EUR per row); no implicit conversion |
| A.4.6 | re-parse same fixture twice | identical output (deterministic, pure) |
| A.4.7 | trades have stable `id` derived from T212 ID column | given two adjacent fixtures sharing one trade ID, both runs produce the same `trades[i].id` for that trade |
| A.4.8 | CSV with CRLF line endings | parses identically to LF |
| A.4.9 | CSV with BOM prefix | parses identically (BOM stripped) |
| A.4.10 | CSV with quoted fields containing commas (`"Apple, Inc."`) | preserved verbatim in output |

### A.5 — IB CSV parser (`Refs V0.7`)

- **File:** `functions/portfolio-tools/csv/__tests__/ib.test.ts`
- **Framework:** Vitest
- **Fixtures:** `test/fixtures/ib-sample.csv` (DV0-4; synthetic until landed),
  `ib-bad-headers.csv`, `ib-partial-bad.csv`, `ib-empty.csv`,
  `ib-multi-section.csv` (Trades + Open Positions + Cash sections).
- **Subject:** `parseIbCsv(text): { trades, positions, errors }`.

| # | Input | Expected |
|---|---|---|
| A.5.1 | happy-path multi-section sample | trades parsed from `Trades` section only; positions from `Open Positions` only |
| A.5.2 | `ib-bad-headers.csv` | `errors[0].kind === 'bad_headers'`, both Trades and Positions sections rejected; partial-section success not allowed (be strict) |
| A.5.3 | sample missing the `Open Positions` section entirely | `positions.length === 0`, no error (legitimate IB statements can omit it) |
| A.5.4 | sample with only the `Open Positions` section (no Trades) | `trades.length === 0`, positions populated, no error |
| A.5.5 | `ib-partial-bad.csv` (one bad row in Trades section) | trades minus 1, error captured with section name in `errors[i].section === 'Trades'` |
| A.5.6 | trades have stable `id` derived from IB trade-ID column | parallel to A.4.7 |
| A.5.7 | unknown section in CSV (e.g. `"Statement Info"`) | silently ignored; no error, no data |
| A.5.8 | section headers in different order (Positions before Trades) | both still parsed correctly |

### A.6 — Tool surface enumeration (`Refs V0.4`)

- **File:** `functions/portfolio-tools/__tests__/surface.test.ts`
- **Framework:** Vitest

| # | Assertion | Why |
|---|---|---|
| A.6.1 | every name from ADR §7 is exported as a function (read-only + write + external lookup) | tool-parity invariant; this is the canary test for accidental removal |
| A.6.2 | every v1+ tool throws `NotImplementedError("v1")` when called with a stub context | "honest scope" — silent fallbacks in v0 would mislead Claude/Gemini in v1 review |
| A.6.3 | v0 in-scope tools (`portfolio_get_snapshot`, `portfolio_get_trades`, `portfolio_set_base_currency`, `portfolio_import_csv`) do **not** throw `NotImplementedError` | confirms scope boundary |
| A.6.4 | tool name list in ADR §7 ↔ exports diff is empty (no extra exports, no missing) | enforced via a checked-in `EXPECTED_TOOLS` constant in the test file |

### A.7 — Component: `<MoneyCell>` (`Refs V0.14`)

- **File:** `src/components/__tests__/MoneyCell.test.ts`
- **Framework:** Vue Test Utils + Vitest

| # | Props | Expected DOM |
|---|---|---|
| A.7.1 | `{ amount: 14850, currency: 'USD' }` | `"$14,850.00"` |
| A.7.2 | `{ amount: 14850.5, currency: 'EUR' }`, locale forced `'en-IE'` | `"€14,850.50"` |
| A.7.3 | `{ amount: 14850, currency: 'USD', showCurrencyBadge: true }`, base = `'EUR'` | renders amount + `<span>USD</span>` (uppercase, --muted class) |
| A.7.4 | `{ amount: 14850, currency: 'USD', showCurrencyBadge: true }`, base = `'USD'` | no badge rendered |
| A.7.5 | `{ amount: 0, currency: 'USD' }` | `"$0.00"` |
| A.7.6 | `{ amount: -150, currency: 'USD' }` | `"-$150.00"` (the cell does not color negatives — that's `<PlCell>`'s job) |
| A.7.7 | computed style includes `font-variant-numeric: tabular-nums` | a11y/visual invariant |

### A.8 — Component: `<PlCell>` (`Refs V0.14`)

- **File:** `src/components/__tests__/PlCell.test.ts`
- **Framework:** Vue Test Utils + Vitest

| # | Props | Expected |
|---|---|---|
| A.8.1 | `{ pl: { amount: 320, currency: 'USD' }, plPct: 0.022 }` | text contains `"+$320.00"` and `"+2.2%"`; class includes `--positive`; arrow `▲` present |
| A.8.2 | `{ pl: { amount: -150, currency: 'USD' }, plPct: -0.015 }` | text contains `"-$150.00"` and `"-1.5%"`; class includes `--negative`; arrow `▼` present |
| A.8.3 | `{ pl: { amount: 0, currency: 'USD' }, plPct: 0 }` | text `"$0.00 (0.00%)"`; no arrow; class is neutral |
| A.8.4 | `{ pl: null, plPct: null }` | renders `"—"`; no arrow; aria-label `"No data"` |

### A.9 — Component: `<SummaryCard>` (`Refs V0.14`)

- **File:** `src/components/__tests__/SummaryCard.test.ts`
- **Framework:** Vue Test Utils

| # | Props | Expected |
|---|---|---|
| A.9.1 | full props with day change | renders total, positions count, cash total, day change with arrow |
| A.9.2 | `dayChange: null, dayChangePct: null` (v0 default — no historical data) | renders `"—"` for day change; positions + cash still render |
| A.9.3 | `loading: true` | shimmer skeleton block; no amount text; `aria-busy="true"` on root |
| A.9.4 | base currency switch (USD → EUR rerender) | text reformats with EUR symbol and `en-IE` grouping |

### A.10 — Component: `<HoldingsTable>` desktop + `<HoldingRow>` mobile (`Refs V0.15`)

- **File:** `src/components/__tests__/HoldingsTable.test.ts` + `HoldingRow.test.ts`
- **Framework:** Vue Test Utils, viewport stubs via `window.matchMedia` mock

| # | Setup | Expected |
|---|---|---|
| A.10.1 | desktop viewport, 5 holdings | renders 5 `<tr>`; default sort by market value desc; `aria-sort="descending"` on Market value header |
| A.10.2 | click `Ticker` header | re-sorts ascending alphabetical; `aria-sort="ascending"`; second click → descending |
| A.10.3 | mobile viewport, same 5 holdings | renders 5 `<HoldingRow>`; no `<table>` element |
| A.10.4 | holding with `avgCost.currency === 'USD'`, base = `'EUR'` | `<MoneyCell showCurrencyBadge>` renders "USD" badge |
| A.10.5 | holding with `avgCost.currency === 'EUR'`, base = `'EUR'` | no badge |
| A.10.6 | mobile row tap target | computed height + width ≥ 44px (a11y per design spec §8) |
| A.10.7 | empty holdings array | renders zero rows; empty-state is the parent's responsibility, not the table's |
| A.10.8 | sort by `Qty` then by `P/L %` then back to `Market value` | each click resets prior sort; only one column has `aria-sort` set |

### A.11 — Component: `<BaseCurrencyPicker>` (`Refs V0.10`)

- **File:** `src/components/__tests__/BaseCurrencyPicker.test.ts`

| # | Action | Expected |
|---|---|---|
| A.11.1 | mount fresh | Continue button is disabled |
| A.11.2 | click USD radio | Continue becomes enabled; `aria-checked="true"` on USD |
| A.11.3 | press Esc | modal does not close (undismissable per design spec §6) |
| A.11.4 | click backdrop | modal does not close |
| A.11.5 | click Continue with USD selected | emits `confirm` with `'USD'` |
| A.11.6 | guard test: parent renders modal over `<DashboardView>` when `baseCurrency` unset | dashboard is in DOM but covered + `inert` (focus trap on modal) |
| A.11.7 | reload with `baseCurrency` already set | modal does not render |

### A.12 — Component: `<DropZone>` + `<CsvPasteArea>` + `<SourceSelect>` (`Refs V0.11`)

- **File:** `src/components/__tests__/DropZone.test.ts`, `CsvPasteArea.test.ts`,
  `SourceSelect.test.ts`

| # | Subject | Expected |
|---|---|---|
| A.12.1 | DropZone — drop a CSV file | emits `file` with the `File` object |
| A.12.2 | DropZone — drop a `.png` | emits `error` with `kind: 'bad_mime'` |
| A.12.3 | DropZone — drop a 2 MB file (over `maxSizeMb: 1`) | emits `error` with `kind: 'too_large'` |
| A.12.4 | DropZone — keyboard "browse" button is focusable + activatable via Enter |
| A.12.5 | DropZone — drop result announced via `aria-live="polite"` region |
| A.12.6 | CsvPasteArea — `v-model` reflects user input |
| A.12.7 | CsvPasteArea — paste of >1 MB string truncates with a warning |
| A.12.8 | SourceSelect — change emits `update:modelValue` and `change` |
| A.12.9 | CsvImport.vue — `Parse →` disabled when both file and paste empty |
| A.12.10 | CsvImport.vue — source change clears parse state (avoids T212-parsed data being committed as IB) |

### A.13 — Component: `<ImportPreviewTable>` + `<WarnBanner>` + commit button (`Refs V0.12`)

- **File:** `src/views/__tests__/CsvImport.test.ts` + `components/__tests__/WarnBanner.test.ts`

| # | Setup | Expected |
|---|---|---|
| A.13.1 | preview with 12 holdings | renders 5 collapsed rows + "Show all" link; click expands to 12 |
| A.13.2 | parse result with `errors.length === 2` | `<WarnBanner count="2">` rendered above preview; click expands to list of `Row N: reason` |
| A.13.3 | parse result with bad headers | renders `<ErrorBanner>` (red) instead of `<WarnBanner>` (yellow); commit button hidden |
| A.13.4 | commit success (mock callable resolves) | router push to `/`; toast "Imported N trades" |
| A.13.5 | commit network failure (mock callable rejects) | `<Toast>` "Couldn't save import. Retry?" shown; preview state intact (`step === 'step2'`); commit button re-enabled |
| A.13.6 | click Commit while in flight | button disabled; second click no-op |

### A.14 — Component: `<AccountSelector>` (`Refs V0.13`)

- **File:** `src/components/__tests__/AccountSelector.test.ts`

| # | Setup | Expected |
|---|---|---|
| A.14.1 | mobile viewport, click chip | bottom sheet opens with `aria-modal="true"`, focus trapped |
| A.14.2 | press Esc inside sheet | sheet closes; focus returns to chip |
| A.14.3 | desktop viewport | chip not rendered; radio list rendered in left rail |
| A.14.4 | click radio for `friend` UID | emits `update:modelValue` with new UID; switching skeleton appears for 200ms |
| A.14.5 | `aria-checked` reflects `currentUid` exactly once | radiogroup integrity |

### A.15 — Component: `<EmptyState>` + `<Toast>` (`Refs V0.16`)

- **File:** `src/components/__tests__/EmptyState.test.ts`, `Toast.test.ts`

| # | Setup | Expected |
|---|---|---|
| A.15.1 | `<EmptyState icon="🍓" title="..." body="..." ctaLabel="Import CSV →" ctaTo="/import" />` | renders all parts; CTA is a `<RouterLink>` to `/import` |
| A.15.2 | `<Toast>` mounted with `duration: 5000`, fake timers | auto-dismisses at t=5000ms |
| A.15.3 | `<Toast>` with `action: { label: 'Retry', handler }` | clicking Retry calls handler; toast remains until handler resolves |

### A.16 — `<AppShell>` (`Refs V0.9`)

- **File:** `src/components/__tests__/AppShell.test.ts`

| # | Setup | Expected |
|---|---|---|
| A.16.1 | mount with stub router-view | header sticky, height 56px, brand text "Strawberry · Portfolio" |
| A.16.2 | desktop viewport (≥1024px) | menu icon hidden |
| A.16.3 | mobile viewport (375px) | menu icon visible |
| A.16.4 | avatar circle initials derived from `useAuth().email` | "duong@allowed.test" → "DA" |

---

## B. Integration tests (Firebase emulator)

Run via `firebase emulators:exec --only auth,firestore,functions "vitest run --testPathPattern integration"`. Each suite resets emulator state in `beforeEach` via the
`@firebase/rules-unit-testing` `clearFirestoreData` helper.

### B.1 — Firestore Security Rules (`Refs V0.3`)

- **File:** `test/rules/firestore.rules.test.ts`
- **Framework:** Jest (required by `@firebase/rules-unit-testing`)

| # | Setup | Expected |
|---|---|---|
| B.1.1 | user A reads `users/A` | allowed |
| B.1.2 | user A reads `users/B` | denied |
| B.1.3 | user A writes `users/A/positions/AAPL` | allowed |
| B.1.4 | user A writes `users/B/positions/AAPL` | denied |
| B.1.5 | user A reads `users/B/trades/...` | denied |
| B.1.6 | unauthenticated read of `users/A/positions/...` | denied |
| B.1.7 | user A creates `users/A` without `baseCurrency` | denied (rule requires it) |
| B.1.8 | user A creates `users/A` with `baseCurrency: 'GBP'` | denied (rule restricts to USD/EUR) |
| B.1.9 | user A creates `users/A` with `baseCurrency: 'USD'` | allowed |
| B.1.10 | user A updates `users/A.baseCurrency` to `'EUR'` | allowed |
| B.1.11 | user A creates `users/A/trades/T1` and tries to update it | update denied (immutability — trades are append-only at the rules level) |
| B.1.12 | search for `allow read, write: if true` in `firestore.rules` | zero matches (regex assertion in test) |

> B.1.11 enforces the ADR §4 invariant ("Trades are immutable") at the rules layer, not
> just by handler convention. Catch handler bugs before they corrupt the ledger.

### B.2 — `importCsv` HTTPS callable (`Refs V0.8`)

- **File:** `functions/__tests__/importCsv.integration.test.ts`
- **Framework:** Vitest with `firebase-functions-test` (offline) wired against Firestore
  emulator for writes.

| # | Setup | Expected |
|---|---|---|
| B.2.1 | call `importCsv` with `{ source: 'T212', csv: <fixture> }` as user A | returns `{ tradesAdded: 47, tradesSkipped: 0, positionsWritten: 12, errors: [] }`; `users/A/trades/*` count = 47 |
| B.2.2 | call again with same fixture | returns `{ tradesAdded: 0, tradesSkipped: 47, positionsWritten: 12, errors: [] }`; `users/A/trades/*` count still 47 (idempotency on broker tradeId) |
| B.2.3 | call with fixture + 1 new trade row | `tradesAdded === 1`; total = 48 |
| B.2.4 | call with mutated existing trade (same ID, different price) | trade is **not** updated; returns `tradesSkipped: 1`. Verifies immutability over re-import. |
| B.2.5 | unauthenticated call (`context.auth` undefined) | throws `HttpsError("unauthenticated")` |
| B.2.6 | call as user A, then call `getTrades` as user B | user B sees zero trades (rules cross-check) |
| B.2.7 | call with `source: 'T212'` but body is IB CSV | parser returns `bad_headers` error; **no Firestore write occurs**; returns `{ tradesAdded: 0, errors: [{ kind: 'bad_headers' }] }` |
| B.2.8 | call with partial-bad fixture (45 good rows, 2 bad) | `tradesAdded: 45, errors.length: 2`; the 45 good rows ARE persisted (graceful partial success per design spec §5.4) |
| B.2.9 | call with `source` other than `'T212' \| 'IB'` | throws `HttpsError("invalid-argument")` |
| B.2.10 | call overwrites `users/A/cash/T212` | post-call cash doc has `amount` from CSV; pre-existing cash for unrelated broker (`IB`) is untouched |
| B.2.11 | call overwrites `users/A/positions/AAPL` (replaces — does not append/merge per ADR §5) | post-call position has new qty; old fields not retained |

### B.3 — `portfolio_set_base_currency` (`Refs V0.4` + `V0.10`)

- **File:** `functions/portfolio-tools/__tests__/setBaseCurrency.integration.test.ts`

| # | Setup | Expected |
|---|---|---|
| B.3.1 | user A calls handler with `'USD'` | `users/A.baseCurrency === 'USD'` |
| B.3.2 | call with `'GBP'` | throws `InvalidArgument` |
| B.3.3 | unauthenticated call | throws `HttpsError("unauthenticated")` |
| B.3.4 | call as A targeting B's UID | denied (rules layer); handler must not allow superseding `context.auth.uid` |

### B.4 — Dashboard composable `usePortfolio` (`Refs V0.17`)

- **File:** `src/composables/__tests__/usePortfolio.integration.test.ts`
- **Framework:** Vitest + `@firebase/rules-unit-testing` against emulator

| # | Setup | Expected |
|---|---|---|
| B.4.1 | seed user A with 0 positions, baseCurrency USD | composable returns `{ status: 'loaded', positions: [], cash: [], baseCurrency: 'USD', fx }`; downstream renders empty state |
| B.4.2 | seed user A with 12 positions, mixed USD/EUR avg costs, baseCurrency USD | returned `holdings[i].marketValue.currency === 'USD'` for all 12; sum equals manual computation |
| B.4.3 | seed user with baseCurrency EUR | returned `marketValue.currency === 'EUR'` for all; conversion uses `meta/fx` rates |
| B.4.4 | switch user (A → B) mid-session | composable resubscribes; first emission for B is `status: 'loading'`, then `loaded` |
| B.4.5 | flip `users/A.baseCurrency` USD → EUR while subscribed | composable re-emits with EUR-converted values without manual reload |
| B.4.6 | user A's data leak check: while subscribed as B, write a position to A | B's emissions never include A's data |

---

## C. E2E Playwright (`Refs V0.18`)

- **File:** `e2e/v0-happy-path.spec.ts`
- **Framework:** Playwright Test
- **Setup:** Playwright config starts `firebase emulators:exec --only auth,firestore,functions`
  and `vite preview` in parallel; uses Auth emulator's auto-link URL trick to bypass
  email delivery.

### C.1 — Happy path

```
[ test.fixme ] sign-in → pick base currency → import CSV → see dashboard
```

Steps and assertions:

1. Navigate to `/`. Expect redirect to `/sign-in`.
2. Enter email `duong@allowed.test`; click "Send sign-in link".
3. Resolve sign-in by visiting the emulator's link URL (Playwright `request.get`).
4. Expect `<BaseCurrencyPicker>` modal visible. Esc has no effect (assert modal still
   visible after `keyboard.press('Escape')`).
5. Click `USD`; click Continue.
6. Expect redirect to `/`. Expect `<EmptyState>` visible (no data yet).
7. Click "Import CSV →". Expect URL `/import`.
8. Select source "Trading 212". Drop `test/fixtures/t212-sample.csv` via
   `setInputFiles`.
9. Click Parse →. Expect Step 2 preview with "47 trades, 12 positions". Expect zero warn
   banner.
10. Click Commit import →. Expect toast "Imported 47 trades". Expect redirect to `/`.
11. Expect `<SummaryCard>` total visible, in `$` formatting (USD locale).
12. Expect `<HoldingsTable>` (desktop viewport) with 12 rows.
13. Take screenshot per step (5 keyframes minimum: sign-in, modal, empty, preview,
    dashboard) and a video for the entire run. Archive under `e2e/artifacts/v0-happy/`.

Required assertions encoded in the spec:

- C.1.a: `await expect(page.getByRole('table')).toHaveCount(1)`
- C.1.b: `await expect(page.getByRole('row')).toHaveCount(13)` (12 + header)
- C.1.c: visual: `await expect(page).toHaveScreenshot('dashboard-loaded.png')` —
  baseline committed alongside the spec; updated only on intentional UI change.
- C.1.d: console error filter: assert `page.on('console')` captures zero `error`-level
  messages over the whole flow (a11y/code-quality canary).

### C.2 — EUR base path

Same flow, but step 5 picks EUR. Expectations:

- C.2.a: SummaryCard renders `€` and Irish-style grouping (`14.850,00` would be wrong;
  `en-IE` uses `14,850.00` — assert per `Intl.NumberFormat`).
- C.2.b: HoldingsTable rows where avg cost is in USD show the `USD` badge per design
  spec §6.

### C.3 — Two-user data isolation (E2E)

Two browser contexts (`contextA`, `contextB`) signed in as different allowlisted
emails. Run in parallel:

- C.3.a: A imports the T212 fixture. B's dashboard simultaneously polls and shows
  empty state throughout — never sees A's positions. Assert via screenshot diff at
  3 timestamps over 10s.
- C.3.b: B imports a different fixture (IB). A's dashboard does not gain B's positions.

This is the rule-15-aligned analog of the rules-layer test B.2.6 — proves data
isolation end-to-end through the UI, not just at the rules boundary.

---

## D. Edge cases & negative paths

These do not own a V0.x task individually, but are folded into the unit/integration
suites referenced in parentheses. Listed here to make the matrix obvious.

| Edge | Where covered | Rationale |
|---|---|---|
| Malformed CSV — bad headers | A.4.2, A.5.2, B.2.7, A.13.3 | parser must fail closed; handler must not write |
| Partial-bad CSV — some rows skipped | A.4.3, A.5.5, B.2.8, A.13.2 | partial success is design intent (§5.4); test it explicitly |
| Empty CSV (header only) | A.4.4 | empty is not an error |
| CSV CRLF line endings | A.4.8 | Windows export compatibility |
| CSV with BOM | A.4.9 | Excel-saved CSVs have BOMs |
| CSV with quoted commas | A.4.10 | "Apple, Inc." style names |
| CSV `>` 1 MB pasted | A.12.7 | client-side guardrail |
| Currency mismatch (avg cost in USD, base in EUR) | A.10.4, B.4.2, C.2.b | currency badge + conversion path |
| FX override beats base rate | A.2.3 | required for manual FX correction |
| Unknown FX pair | A.2.4 | fail loud |
| `meta/fx` document missing | A.3.3 | warn + fall back to seed; no crash |
| Empty portfolio (zero positions) | A.10.7, B.4.1, C.1 step 6 | empty state UI must render |
| Two-user data isolation (rules) | B.1.2/4/5/6, B.2.6, B.4.6 | first-class invariant |
| Two-user data isolation (E2E) | C.3 | proves end-to-end through UI |
| Idempotent re-import | B.2.2, B.2.4 | broker tradeId immutability |
| Source mismatch (T212 source, IB body) | B.2.7 | parse fails before write |
| Network failure on commit | A.13.5 | retry toast keeps preview state |
| Allowlist plus-aliasing attack | A.1.2 | exact-match required |
| Empty allowlist file | A.1.6 | fail closed |
| Dashboard re-render on baseCurrency switch | B.4.5 | no manual reload |
| Trades update attempt at rules layer | B.1.11 | enforces immutability invariant |
| Storage rule deny-all (V0.1) | A.1.7 not applicable; covered by V0.1 deny-all xfail | see V0.1 acceptance |

---

## E. QA gate — rule 16 (Akali Playwright + Figma diff)

Owner at PR time: **Akali** (or any agent with the `qa` label). Runs after V0.18
implementation lands.

### E.1 — Required artifacts in PR body

PR body must link to:

1. Playwright report URL (CI-uploaded HTML report).
2. Video of the full happy path (C.1).
3. Screenshots per the 5 keyframes (sign-in, BaseCurrencyPicker, empty, preview,
   dashboard).
4. Figma diff: side-by-side image of the Figma frame ("Strawberry — Portfolio v0",
   T4b) vs the corresponding Playwright screenshot, for **each** keyframe. Diffs hosted
   at `assessments/qa-reports/2026-04-DD-portfolio-v0/`. <!-- orianna: ok -->

### E.2 — Diff acceptance criteria

For each keyframe, compare Figma frame (T4b) vs Playwright screenshot (C.1):

| Aspect | Threshold | Tooling |
|---|---|---|
| Layout (positions of major elements) | within 8px tolerance | manual visual inspection or `pixelmatch` overlay |
| Colors (background, text, accent) | exact hex match per design spec §2 tokens | sample 5 points per screen via image picker |
| Type sizes / weights | exact per spec §2 (DM Sans, sizes documented inline) | inspect computed style via Playwright `page.evaluate` |
| P/L color paired with arrow + sign | always present (a11y per spec §8) | inspect `<PlCell>` DOM in the screenshot's source HTML capture |
| Tabular nums on monetary cells | computed style match | Playwright `page.evaluate(() => getComputedStyle(...))` |
| Empty state CTA links to `/import` | exact URL match | Playwright `getByRole('link').getAttribute('href')` |
| BaseCurrencyPicker is undismissable | Esc / backdrop / Tab-out have no effect | scripted in C.1 step 4 |

### E.3 — QA report shape

`assessments/qa-reports/2026-04-DD-portfolio-v0/report.md`: <!-- orianna: ok -->

```markdown
# Portfolio v0 — QA Gate Report
- PR: <link>
- Akali run: <CI run URL>
- Verdict: PASS / FAIL

## Keyframe diffs
1. Sign-in — PASS [figma.png] [playwright.png] [diff.png]
2. BaseCurrencyPicker — PASS ...
3. EmptyState — PASS ...
4. ImportPreview — PASS ...
5. Dashboard loaded — PASS ...

## Findings
- ...
```

PR body linter (rule 16) enforces the artifact links. Any FAIL row blocks merge.

---

## F. Coverage matrix — V0.x → tests

Every implementation task has at least one xfail-first test landed before its
implementation commit. **Vi: this is your worklist.**

| Task | xfail commits to land first | Notes |
|---|---|---|
| V0.1 | V0.1 acceptance has the deny-all rule + emulator boot test (`functions/__tests__/emulator-boot.test.ts`). One assertion per acceptance bullet. | Use `firebase emulators:exec` in the test command, not ambient. |
| V0.2 | A.1 (`onSignIn.test.ts`) — all six rows | Allowlist file fixture: `functions/config/__fixtures__/allowlist.test.ts` |
| V0.3 | B.1 (`firestore.rules.test.ts`) — all twelve rows | First test to require Jest. |
| V0.4 | A.6 (`surface.test.ts`) | EXPECTED_TOOLS constant pulled from ADR §7. |
| V0.5 | A.2 + A.3 | A.3 needs emulator. |
| V0.6 | A.4 | Synthetic fixtures OK until DV0-3 lands; replace before V0.20. |
| V0.7 | A.5 | Same caveat for DV0-4. |
| V0.8 | B.2 | Integration test; flushes emulator between cases. |
| V0.9 | A.16 | |
| V0.10 | A.11 + B.3 | Component + handler integration both. |
| V0.11 | A.12 | |
| V0.12 | A.13 | |
| V0.13 | A.14 | |
| V0.14 | A.7 + A.8 + A.9 | Three sibling component suites. |
| V0.15 | A.10 | |
| V0.16 | A.15 | |
| V0.17 | B.4 | Integration via emulator. |
| V0.18 | C.1 (+ C.2 + C.3) | C.1 is the must-have happy path. C.2 + C.3 land in same commit. |
| V0.19 | E2E + tdd-gate self-test (`scripts/test-tdd-gate.sh` produces a synthetic two-commit branch and asserts CI verdict). <!-- orianna: ok --> | Documented in V0.19 acceptance already. |
| V0.20 | None — exit sign-off; checks the matrix above is fully green. | Manual + Duong sign-off. |

---

## G. Out-of-scope (explicit)

Not in this test plan; these are v1+ surface area and would creep scope:

- T212/IB REST adapter tests (v1)
- MCP server tests (v2)
- Gemini chat proxy tests (v3)
- Sparkline rendering tests (v1)
- Trade ledger UI tests (v1)
- Intents UI tests (v1)
- FX-override UI tests (v1)
- Manual refresh button tests (v1)
- Auto-intent matching tests (v4)

If Vi finds a v0 task drifting into any of the above, halt and escalate before adding
tests.

---

## H. Handoff to Vi (T7)

1. Land xfail commits in this exact order to keep CI green at every step:
   `V0.1 → V0.2 → V0.3 → V0.4 → V0.5 → V0.6 → V0.7 → V0.8 → V0.9 → V0.10 → V0.11 →
   V0.12 → V0.13 → V0.14 → V0.15 → V0.16 → V0.17 → V0.18 → V0.19`. Within each task,
   the xfail-test commit is the literal first commit on the branch; the implementation
   commit (Seraphine T6 / chosen executor) flips xfail → real.
2. Use `it.fails(...)` (Vitest), `xit(...)` or `it.todo(...)` won't satisfy the gate —
   the test must run and fail visibly.
3. Commit body must contain `Refs V0.<n>`. Pre-push hook will reject otherwise.
4. Fixtures: stub synthetic CSV fixtures into `test/fixtures/` immediately so
   parser tests don't block on DV0-3 / DV0-4. Mark them `// TODO replace with real
   anonymized export at V0.20`.
5. Edge cases in §D are not separate xfail commits — they are extra rows in the
   already-listed test files. Add them in the same xfail commit as the parent test.
6. After V0.18 lands, hand off to Akali for the QA gate (§E). Do not open the PR for
   merge until Akali's report.md exists and verdict is PASS.
7. Vi: do not write any production code. Tests only. Production code is Seraphine's
   (T6).

---

## I. Open items for Caitlyn / Duong

1. **Akali presence on team `portfolio-v0`** — confirm the QA agent is rostered
   before V0.18 lands; otherwise §E gate cannot run.
2. **Real anonymized CSV fixtures (DV0-3 / DV0-4)** — synthetic fixtures will pass v0
   tests but the V0.20 sign-off requires the real samples. Track as a Duong-blocker.
3. **Visual baseline screenshots (C.1.c)** — first run will create them; reviewer
   should eyeball before approving the baseline commit. Subsequent PRs only re-baseline
   on intentional UI changes (call out in PR body).
4. **`firebase emulators:exec` performance in CI** — if cold-start is too slow, switch
   to a long-lived emulator container. Decision deferred to V0.19 implementer.
