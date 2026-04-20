---
status: proposed
owner: kayn
date: 2026-04-19
title: Portfolio Tracker v0 — TDD Task Breakdown
parent_adr: plans/approved/2026-04-19-portfolio-tracker.md
design_spec: agents/neeko/learnings/2026-04-19-portfolio-v0-design.md
target_repo: harukainguyen1411/strawberry-app
---

# Portfolio Tracker v0 — TDD Task Breakdown

Executable task list for the **v0 phase** of the Portfolio Tracker
(`plans/approved/2026-04-19-portfolio-tracker.md`, §10 row v0). v0 is the
**CSV-only** skeleton: Firebase project, Auth + allowlist, Firestore schema
(with per-user `baseCurrency`), CSV import, dashboard shell, shared
`portfolio-tools/` handler module stubs, xfail test scaffold per task.
**No broker APIs. No MCP server. No Gemini chat. No sparkline.**

App code lands in `harukainguyen1411/strawberry-app` under
`apps/myapps/portfolio-tracker/` (Vue SPA + functions). This plan stays
in `Duongntd/strawberry`.

---

## Conventions

- **Task IDs:** `V0.<n>` (single-phase plan; sub-letters allowed for
  amendments, e.g. `V0.3a`).
- **TDD sequencing (rule 12):** every implementation task `V0.<n>` is
  preceded on the same branch by an **xfail test commit** carrying the
  exact task ID in its commit body (e.g. `Refs V0.4`). The xfail commit
  is the literal first commit on the branch; the implementation commit
  flips the xfail to passing. The pre-push hook and `tdd-gate.yml`
  enforce.
- **Branches:** one branch per task (`v0/<id>-<slug>`). Squash-merge.
- **No implementer assignments here** (rule plan-writers-no-assignment).
  Team-lead routes tasks to executors.
- **Reviewers** on every PR: one non-author. No self-merge (rule 18).
- **Per-user base currency** is wired in from V0.1 (the Firestore schema
  task). No task may bypass `users/{uid}.baseCurrency`.
- **Acceptance criteria** are inline per task — each is verifiable by
  the matching xfail test flipping to green plus any manual gate noted.
- **<1 day** target per task.

---

## Dependency overview

```
V0.1 (Firebase project bootstrap)
  └── V0.2 (Auth + allowlist)
        └── V0.3 (Firestore schema + Security Rules + emulator harness)
              ├── V0.4 (portfolio-tools/ handler module skeleton)
              │     └── V0.5 (Money type + FX conversion handler)
              │           └── V0.6 (CSV parser — T212)
              │                 └── V0.7 (CSV parser — IB)
              │                       └── V0.8 (import-csv callable + idempotent commit)
              │
              └── V0.9 (Vue app shell + routing + design tokens wiring)
                    ├── V0.10 (BaseCurrencyPicker onboarding modal)
                    ├── V0.11 (CSV Import view — Step 1 + DropZone + PasteArea)
                    │     └── V0.12 (CSV Import view — Step 2 preview + commit)
                    ├── V0.13 (useCurrentAccount — single-account context; AccountSelector deferred v1)
                    ├── V0.14 (SummaryCard + MoneyCell + PlCell)
                    ├── V0.15 (HoldingsTable desktop + HoldingRow mobile)
                    ├── V0.16 (Empty / Loading / Error states)
                    └── V0.17 (DashboardView wire-up)
                          └── V0.18 (E2E Playwright happy path: sign-in → import → render)

V0.19 (CI: tdd-gate workflow scoped to apps/myapps/portfolio-tracker)
V0.20 (Exit-criteria sign-off — Duong)
```

V0.1–V0.3 are strict serial spine. V0.4 → V0.8 (handler/CSV chain) and
V0.9 → V0.17 (UI chain) run as **two parallel windows** after V0.3.
V0.18 joins both. V0.19 can land any time after V0.1. V0.20 is final.

---

## Phase V0 tasks

### V0.1 — Firebase project + monorepo scaffold for `apps/myapps/portfolio-tracker/`

**Goal:** Stand up the Firebase project (Auth + Firestore + Functions +
Hosting), commit `firebase.json` / `.firebaserc` / emulator config, and
scaffold the Vue 3 + Tailwind app at
`apps/myapps/portfolio-tracker/` with the Warm Night design tokens
already loaded in `src/assets/main.css` (per design spec §2).

**Inputs:**
- ADR §3 architecture diagram, §9 secrets/security expectations.
- Design spec §2 (existing tokens to reuse).

**Outputs:**
- `apps/myapps/portfolio-tracker/` with Vite + Vue 3 + Tailwind boilerplate.
- `firebase.json`, `.firebaserc`, `firestore.rules` (deny-all stub),
  `firestore.indexes.json` (empty), `storage.rules` (deny-all).
- `firebase emulators` configured for auth + firestore + functions.
- README pointing at this plan.

**xfail-first:** test asserting `firebase emulators:exec --only firestore`
boots and a deny-all rule blocks an anonymous read. Commit body: `Refs V0.1`.

**Acceptance criteria:**
- `npm run dev` boots the Vue app at `localhost:5173` with the dark
  Warm Night background visible.
- `firebase emulators:start --only auth,firestore,functions` boots
  cleanly on a developer machine.
- Deny-all Firestore rule blocks all reads in emulator.

---

### V0.2 — Firebase Auth email-link sign-in + single-email allowlist (runtime-configurable)

**Goal:** Implement Firebase Auth email-link sign-in and a server-side
allowlist that rejects any other UID at first sign-in. The allowlist is
**runtime-configurable via Firestore doc `config/auth_allowlist`** (array
field `emails`). v0 ships with one entry (`harukainguyen1411@gmail.com`).
Adding a second email is a Firestore doc edit — no redeploy required.
No public signup surface in the UI.

**Inputs:** ADR §2, V0.1 outputs.

**Outputs:**
- `apps/myapps/portfolio-tracker/src/auth/` with email-link flow.
- `apps/myapps/portfolio-tracker/functions/onSignIn.ts` Cloud Function
  (`beforeSignIn` blocking trigger) reading allowlist from Firestore doc
  `config/auth_allowlist` (field `emails: string[]`), cached per cold
  start, rejecting non-allowlisted emails.
- Sign-in view (minimal) gated in front of `/` and `/import`.

**xfail-first:** unit test on the allowlist function — non-allowlisted
email throws `HttpsError("permission-denied")`; allowlisted email passes
through. Commit body: `Refs V0.2`.

**Acceptance criteria:**
- Allowlisted email completes email-link sign-in against the emulator.
- Non-allowlisted email is rejected at the blocking trigger; UID is not
  created.
- No `signUp` UI; only "send sign-in link" form.
- Allowlist is read from `config/auth_allowlist.emails` in Firestore (not
  hardcoded). Adding a new email requires only a Firestore doc edit.

---

### V0.3 — Firestore schema + per-user Security Rules + emulator harness

**Goal:** Define the v0 subset of the Firestore schema (`users/{uid}`,
`users/{uid}/positions/*`, `users/{uid}/trades/*`, `users/{uid}/cash/*`,
`users/{uid}/meta/fx`, `users/{uid}.baseCurrency`) and ship Security
Rules that enforce per-user isolation. Provide a Jest harness using the
Firebase emulator for rules tests. Rules must also allow the
`beforeSignIn` function to read `config/auth_allowlist` (read-once at
sign-in, cached per cold start).

**Inputs:** ADR §4 data model, ADR §9 rules expectations, V0.2.

**Outputs:**
- `firestore.rules` — per-user subcollection isolation; deny cross-user
  reads/writes; allow `users/{uid}` read+write only when `request.auth.uid == uid`;
  allow server-side (Admin SDK) read of `config/auth_allowlist` (used by
  `beforeSignIn` Cloud Function — not accessible to client).
- `apps/myapps/portfolio-tracker/test/rules/` Jest suite using
  `@firebase/rules-unit-testing`.
- TypeScript types in `apps/myapps/portfolio-tracker/src/types/firestore.ts`
  for `User`, `Position`, `Trade`, `Cash`, `FxMeta`, including the
  `baseCurrency: 'USD' | 'EUR'` field on `User`.
- `firestore.indexes.json` updated for any composite index v0 needs
  (likely just `trades` by `executedAt` desc).

**xfail-first:** rules test `cross-user read of users/{otherUid}/trades is denied`
and `same-user read of users/{uid}/positions is allowed`. Commit body:
`Refs V0.3`.

**Acceptance criteria:**
- All per-collection rules tests pass against emulator.
- `baseCurrency` is a required string on user-create rule (`USD` or `EUR`).
- No `allow read, write: if true` anywhere in `firestore.rules`.

---

### V0.4 — `portfolio-tools/` handler module skeleton + tool-parity scaffolding

**Goal:** Create the shared handler module
`apps/myapps/portfolio-tracker/functions/portfolio-tools/` with stub
exports for the v0 read tools (`portfolio_get_snapshot`,
`portfolio_get_trades`) and the v0 write tools used by CSV import flow
(`portfolio_set_base_currency`, `portfolio_import_csv` as the canonical
handler). All other tools from ADR §7 land as **stub-only** exports that
throw `NotImplementedError` with a `// TODO v1` marker, so the surface
exists but is honest about scope.

**Inputs:** ADR §7 tool surface, V0.3.

**Outputs:**
- `functions/portfolio-tools/index.ts` re-exporting every tool from §7.
- `functions/portfolio-tools/types.ts` with `Money`, `CurrencyCode`,
  `Snapshot`, `Trade`, `Position`, `Holding` (per design spec §6).
- `functions/portfolio-tools/_notImplemented.ts` helper.
- `functions/portfolio-tools/__tests__/surface.test.ts` asserting
  every tool name from ADR §7 is exported.

**xfail-first:** `surface.test.ts` enumerating every tool name from
ADR §7 and asserting `typeof handlers[name] === 'function'`. Commit body:
`Refs V0.4`.

**Acceptance criteria:**
- All tool names from ADR §7 export a function (stub or real).
- v0 in-scope tools have real bodies (or are completed by later tasks
  V0.5–V0.8).
- v1+ tools throw `NotImplementedError("v1")` with no silent fallbacks.
- No HTTPS callable, MCP, or Gemini adapter wiring in v0 — handlers are
  imported directly. Adapter wiring is a v1+ task per ADR §12.

---

### V0.5 — `Money` type + FX conversion handler reading `users/{uid}/meta/fx`

**Goal:** Implement the `Money` value type and a pure conversion
function `convert(amount, from, to, fxRates): Money` plus the handler
that loads `users/{uid}/meta/fx` and resolves overrides. Snapshot
totals later compose with this.

**Inputs:** ADR §3 (per-user base currency), ADR §4 (`meta/fx` shape),
design spec §6, V0.4.

**Outputs:**
- `functions/portfolio-tools/money.ts` — pure converter.
- `functions/portfolio-tools/fx.ts` — Firestore loader for
  `users/{uid}/meta/fx`, applies `overrides` over `rates`.
- Default ECB-rates seed module
  `functions/portfolio-tools/fxSeed.ts` (static map for v0; ECB API
  fetch is a v1 task).

**xfail-first:** unit tests for `convert`:
- USD→EUR with rate 0.92 returns 92 EUR for 100 USD.
- USD→USD returns identity.
- Override beats base rate.
- Unknown pair throws `FxRateMissingError`.
Commit body: `Refs V0.5`.

**Acceptance criteria:**
- `Money.amount` is `number`, no float-precision tests required at v0
  (USD/EUR cents tolerable; reassessed at v1 if reconciliation fails).
- `convert` is pure (no Firestore in `money.ts`).
- FX loader returns `{ rates, overrides, updatedAt }` and logs a
  structured warning when `meta/fx` is missing.

---

### V0.6 — CSV parser: Trading 212 export

**Goal:** Implement `parseT212Csv(text: string): { trades, positions, errors }`
in `functions/portfolio-tools/csv/t212.ts`. Pure function; no Firestore
writes here. Maps T212 export columns to v0 `Trade` and `Position` shapes.

**Inputs:** A real T212 export sample committed under
`apps/myapps/portfolio-tracker/test/fixtures/t212-sample.csv` (Duong to
provide one anonymized sample; if absent, build from T212 docs schema and
flag as a Duong-blocker on the task).

**Outputs:**
- `functions/portfolio-tools/csv/t212.ts` parser.
- Fixture `test/fixtures/t212-sample.csv` (sanitized).
- Per-row error capture (row number + reason) per design spec §5.4.

**xfail-first:** unit tests:
- happy-path: 47-row fixture → 47 trades, 12 positions, 0 errors.
- malformed header → `errors[0].kind === 'bad_headers'`, no trades.
- partial bad row → 46 trades + 1 error with row number.
Commit body: `Refs V0.6`.

**Acceptance criteria:**
- Pure function; deterministic on fixture.
- Trade `id` derived from broker-assigned T212 ID for idempotency
  (ADR §9 invariant). If T212 export has no ID column, document the
  derivation rule in code comment and confirm with Duong.
- All money values carry their **native** currency (per design spec §6).

---

### V0.7 — CSV parser: Interactive Brokers Activity Statement

**Goal:** Implement `parseIbCsv(text: string): { trades, positions, errors }`
in `functions/portfolio-tools/csv/ib.ts`. Mirrors V0.6 contract.

**Inputs:** IB Activity Statement sample fixture
`test/fixtures/ib-sample.csv` (Duong to provide; flag as Duong-blocker
if absent — IB schema is multi-section so a real sample is high-value).

**Outputs:**
- `functions/portfolio-tools/csv/ib.ts` parser.
- `test/fixtures/ib-sample.csv` (sanitized).

**xfail-first:** unit tests parallel to V0.6 (happy / bad-headers /
partial-row). Commit body: `Refs V0.7`.

**Acceptance criteria:**
- Same return shape as V0.6 — UI does not need to branch on source past
  the parser layer.
- IB section parsing handles the multi-section Activity Statement
  format (Trades section vs. Open Positions section).
- Trade `id` derived from IB-assigned trade ID.

---

### V0.8 — `import-csv` HTTPS callable + idempotent Firestore commit

**Goal:** Wire the `portfolio_import_csv` handler from V0.4 to (a) call
the right parser based on `source`, (b) write trades idempotently
(`tradeId` as Firestore doc ID — ADR §5 diff rules), (c) overwrite
positions, (d) overwrite `users/{uid}/cash/{broker}`. Expose as an
HTTPS callable. No raw HTTP — callable only (auth required).

**Inputs:** V0.5–V0.7 outputs; ADR §5 diff rules.

**Outputs:**
- `functions/index.ts` exporting `importCsv` HTTPS callable.
- `functions/portfolio-tools/import.ts` orchestration.
- Re-import idempotency: re-running the same CSV is a no-op on `trades`,
  overwrites positions/cash.

**xfail-first:** integration test against the Firestore emulator:
- import T212 fixture → assert N trades written.
- import same fixture again → assert N trades (no duplicates).
- import fixture with one new trade → assert N+1 trades.
- import as user A then read as user B → permission denied (rules
  cross-check).
Commit body: `Refs V0.8`.

**Acceptance criteria:**
- Idempotent on broker-assigned trade ID.
- Positions and cash overwritten, never appended.
- Returns `{ tradesAdded, tradesSkipped, positionsWritten, errors }`.
- Throws `HttpsError("unauthenticated")` if `context.auth` is missing.

---

### V0.9 — Vue app shell + router + design tokens wiring

**Goal:** Build `<AppShell.vue>` per design spec §4.1 with routes `/`
(dashboard) and `/import` (CSV import). Wire Pinia (or composables — per
Seraphine's call) for `useAuth()` exposing the current Firebase user.

**Inputs:** Design spec §4.1, V0.1.

**Outputs:**
- `src/App.vue` mounting `<AppShell>` and `<RouterView>`.
- `src/components/AppShell.vue`.
- `src/router/index.ts` with `/` and `/import`; redirect to `/sign-in`
  when unauthenticated.
- `src/composables/useAuth.ts`.

**xfail-first:** Vue Test Utils — render `<AppShell>` and assert header
text, sticky positioning class, and router-view slot. Commit body:
`Refs V0.9`.

**Acceptance criteria:**
- Header sticky, 56px, Warm Night palette applied.
- Avatar circle renders initials from `useAuth().email`.
- Mobile (375px) shows menu icon; desktop (≥1024px) does not.

---

### V0.10 — `BaseCurrencyPicker` onboarding modal

**Goal:** Per design spec §6, render an undismissable modal on first
sign-in if `users/{uid}.baseCurrency` is unset. On confirm, write
`baseCurrency` to Firestore via the `portfolio_set_base_currency`
handler from V0.4.

**Inputs:** Design spec §6, V0.4 (`portfolio_set_base_currency`),
V0.9.

**Outputs:**
- `src/components/BaseCurrencyPicker.vue` — radio USD/EUR, no Esc, no
  backdrop close.
- `src/composables/useBaseCurrency.ts` reading the Firestore field.
- App-level guard: if signed in and `baseCurrency` unset → render modal,
  block underlying view interaction.

**xfail-first:** Vue Test Utils — mount `<BaseCurrencyPicker>`, assert
Continue is disabled until a radio is checked; assert Esc keypress does
not close. Plus a guard test: mock unset baseCurrency → modal renders
over `<DashboardView>`. Commit body: `Refs V0.10`.

**Acceptance criteria:**
- Modal cannot be dismissed without a selection.
- After confirm, `users/{uid}.baseCurrency` equals the picked value.
- Reload of the app with `baseCurrency` set does not re-render the modal.

---

### V0.11 — CSV Import view, Step 1 (`DropZone` + `CsvPasteArea` + `SourceSelect`)

**Goal:** Implement `<CsvImport.vue>` Step 1 per design spec §4.2:
source select, drop zone, paste area, primary "Parse →" CTA.

**Inputs:** Design spec §4.2 + §5.3, V0.6 + V0.7 (parsers), V0.9.

**Outputs:**
- `src/views/CsvImport.vue` (state machine: `step1 | step2`).
- `src/components/DropZone.vue`.
- `src/components/CsvPasteArea.vue`.
- `src/components/SourceSelect.vue`.

**xfail-first:** Vue Test Utils:
- "Parse →" disabled when both file and paste are empty.
- Drop event with non-CSV file emits `error`.
- Source change clears parse state.
Commit body: `Refs V0.11`.

**Acceptance criteria:**
- Drop or paste triggers parser invocation; Step 1 transitions to Step 2
  with parse result in component state.
- Bad-header parse failure renders the error banner from §5.3 (not the
  warn banner).
- Keyboard-accessible "browse" fallback in the drop zone.

---

### V0.12 — CSV Import view, Step 2 (preview + commit) + `WarnBanner` + `ErrorBanner` + `ImportPreviewTable`

**Goal:** Step 2 of the import flow per design spec §4.2: preview
holdings + trades, partial-row warn banner if `errors.length > 0`,
"Commit import →" calls the `importCsv` callable from V0.8 and routes
to `/` on success.

**Inputs:** Design spec §4.2, §5.4, §5.5; V0.8 callable; V0.11.

**Outputs:**
- `<ImportPreviewTable>`, `<WarnBanner>`, `<ErrorBanner>`, `<Toast>`
  components.
- Commit handler in `<CsvImport.vue>`.

**xfail-first:** Vue Test Utils:
- preview renders 5 collapsed rows + "Show all" expander.
- WarnBanner click expands details list of skipped rows.
- Successful commit triggers redirect to `/`.
- Network failure shows retry toast (per §5.5).
Commit body: `Refs V0.12`.

**Acceptance criteria:**
- Preview shows holdings count + trades count + source (per §4.2 Step 2
  layout).
- Commit disables the button until callable resolves.
- Failure path keeps preview state intact (does not reset to Step 1).

---

### V0.13 — Single-account v0 (AccountSelector deferred to v1)

**Goal:** Wire the signed-in user as the sole account context for the
v0 dashboard. No AccountSelector UI is shipped. `useAccountSwitcher`
is replaced by a minimal `useCurrentAccount` composable that exposes
`currentUid` as the signed-in user's UID — read-only, no switching.

**Inputs:** V0.9, V0.3 Security Rules (per-user isolation).

**Outputs:**
- `src/composables/useCurrentAccount.ts` exposing `currentUid`
  (derived from `useAuth().uid`). No `accounts` array, no `switchTo`.
- Remove any reference to `AccountSelector.vue` or
  `useAccountSwitcher.ts` from the codebase.

**xfail-first:** Vue Test Utils:
- `useCurrentAccount()` returns the UID of the signed-in user.
- Attempting to import `AccountSelector` from the components barrel
  throws (component does not exist).
Commit body: `Refs V0.13`.

**Acceptance criteria:**
- Dashboard loads positions for the signed-in user only.
- No multi-account affordance appears anywhere in the v0 UI.
- `useCurrentAccount.currentUid` is reactive to auth state changes
  (sign-out sets it to `null`).

---

### V0.14 — `SummaryCard` + `MoneyCell` + `PlCell` + `useMoneyFormat`

**Goal:** Per design spec §4.3.2 + §6: render total value (base
currency), positions count, cash total, day-change placeholder (`—` in
v0, no historical snapshot to compute against).

**Inputs:** Design spec §4.3.2, §6; V0.5 (Money/FX); V0.9.

**Outputs:**
- `src/components/SummaryCard.vue`.
- `src/components/MoneyCell.vue` (base + native badge variants).
- `src/components/PlCell.vue`.
- `src/composables/useMoneyFormat.ts` wrapping `Intl.NumberFormat`
  (locale `en-US` for USD, `en-IE` for EUR per spec §6).

**xfail-first:** Vue Test Utils:
- `MoneyCell({amount: 14850, currency: 'USD'})` → `$14,850.00`.
- `MoneyCell` with `showCurrencyBadge` and base ≠ native → renders
  uppercase `USD` badge.
- `PlCell` positive → `--positive` color + ▲ + `+` sign.
- `PlCell` negative → `--negative` color + ▼ + `-` sign.
- `SummaryCard` with no historical data renders `—` for day change.
Commit body: `Refs V0.14`.

**Acceptance criteria:**
- Tabular nums on every monetary cell.
- P/L color is paired with arrow + sign (a11y per spec §8).
- Locale switch works (USD vs EUR formatting differs).

---

### V0.15 — `HoldingsTable` (desktop) + `HoldingRow` (mobile)

**Goal:** Per design spec §4.3.3 + §6: desktop table sortable, mobile
stacked rows. Native-currency avg cost + base-currency market value/PL
side by side (currency badge for native ≠ base).

**Inputs:** Design spec §4.3.3, §6; V0.14 cells; V0.5 conversion; V0.9.

**Outputs:**
- `src/components/HoldingsTable.vue` (desktop).
- `src/components/HoldingRow.vue` (mobile).
- Sort logic: default market-value desc; click header toggles direction;
  `aria-sort` reflects state.

**xfail-first:** Vue Test Utils:
- 5-row holdings array → desktop renders 5 `<tr>`, default sort
  market-value desc.
- Click "Ticker" header → ascending alphabetical, `aria-sort="ascending"`.
- Mobile breakpoint renders `<HoldingRow>` instead of `<table>`.
- Avg cost in row shows native currency badge when `avgCost.currency !==
  baseCurrency`.
Commit body: `Refs V0.15`.

**Acceptance criteria:**
- Sort works on every column.
- All money cells use `<MoneyCell>` and `<PlCell>` (no inline
  `Intl.NumberFormat`).
- Mobile row tap-target ≥ 44×44px (a11y per spec §8).

---

### V0.16 — Empty / Loading / Error states (`EmptyState`, skeleton, toast)

**Goal:** Per design spec §5.1, §5.2, §5.5: empty state on `/` when
positions+trades are zero; skeleton shimmer for summary + holdings;
network-failure toast.

**Inputs:** Design spec §5; V0.9.

**Outputs:**
- `src/components/EmptyState.vue` (reusable: `icon, title, body, ctaLabel,
  ctaTo`).
- `src/components/Toast.vue` (global, 5s auto-dismiss).
- Skeleton classes added to `<SummaryCard>` and `<HoldingsTable>` via
  `loading` prop (no new component — extend the existing ones).

**xfail-first:** Vue Test Utils:
- `<EmptyState>` renders icon + title + body + CTA linking to `/import`.
- `<Toast>` auto-dismisses after 5s (use fake timers).
- `<SummaryCard loading>` renders shimmer block, no amount.
Commit body: `Refs V0.16`.

**Acceptance criteria:**
- Empty state appears on `/` when Firestore returns zero positions.
- Skeleton has `aria-busy="true"` on parent (a11y per spec §8).
- Toast keeps preview state intact when triggered from V0.12 commit
  failure.

---

### V0.17 — `DashboardView` wire-up: data loading + base-currency rendering

**Goal:** `<DashboardView.vue>` at `/`: load
`users/{uid}/positions/*`, `users/{uid}/cash/*`, `users/{uid}.baseCurrency`,
and FX rates; convert positions to display Holdings; pass to
`<SummaryCard>` + `<HoldingsTable>` / `<HoldingRow>`. Empty state when
zero positions.

**Inputs:** V0.13–V0.16; V0.5 FX loader; V0.10 baseCurrency; V0.3 schema.

**Outputs:**
- `src/views/DashboardView.vue`.
- `src/composables/usePortfolio.ts` — Firestore subscription returning
  `{ positions, cash, baseCurrency, fx, status }`.

**xfail-first:** Vue Test Utils + Firestore-emulator integration:
- mount with seeded zero-state user → empty state renders.
- mount with seeded 12-position user (USD base) → summary total matches
  sum of converted market values; holdings table renders 12 rows.
- switching to a EUR-base user re-renders all totals in EUR.
Commit body: `Refs V0.17`.

**Acceptance criteria:**
- Zero-position user sees empty state with "Import CSV →" CTA.
- Re-import button (full-width ghost on mobile) navigates to
  `/import?mode=replace`.
- Base-currency change triggers re-render (no manual reload).

---

### V0.18 — Playwright E2E happy path: sign-in → import → render

**Goal:** Single Playwright spec exercising the v0 golden path against
the emulator: email-link sign-in (use Firebase Auth emulator's auto-link
URL), pick base currency, import the T212 fixture, see the summary card
+ holdings render, take screenshots and a video.

**Inputs:** All prior V0 tasks; design spec §4 + §5.

**Outputs:**
- `apps/myapps/portfolio-tracker/e2e/v0-happy-path.spec.ts`.
- Playwright config wired to start emulator + dev server.
- Screenshots + video archived to `apps/myapps/portfolio-tracker/e2e/artifacts/`.

**xfail-first:** spec marked `.fixme()` initially; flips to active in
the implementation commit. Commit body: `Refs V0.18`.

**Acceptance criteria:**
- Spec runs green locally via `npm run test:e2e`.
- Spec runs green in CI via `e2e.yml` (rule 15 — required check on PR).
- Video + screenshots produced for the QA gate (rule 16).

---

### V0.19 — CI: scope `tdd-gate.yml` + `e2e.yml` + pre-commit hooks to `apps/myapps/portfolio-tracker/`

**Goal:** Ensure rule 12 / 14 / 15 enforcement covers the new app path.
The `tdd-gate.yml` workflow must inspect commits on PRs touching
`apps/myapps/portfolio-tracker/**` and require an xfail-test commit
preceding each implementation commit. The pre-commit unit-test hook
(rule 14) must run the portfolio tracker's `vitest` (or chosen runner)
suite when files in that path change.

**Inputs:** Existing `.github/workflows/tdd-gate.yml`,
`scripts/install-hooks.sh` (rule 14).

**Outputs:**
- Updated `.github/workflows/tdd-gate.yml` path filter.
- Updated `.github/workflows/e2e.yml` path filter.
- Pre-commit hook update to detect changed files under
  `apps/myapps/portfolio-tracker/**` and run the right test command.

**xfail-first:** a CI smoke test asserting that a commit touching
`apps/myapps/portfolio-tracker/src/foo.ts` *without* a paired xfail
commit fails the `tdd-gate` job. Commit body: `Refs V0.19`.

**Acceptance criteria:**
- Test PR with implementation-only commit → tdd-gate fails.
- Test PR with xfail+impl commits → tdd-gate passes.
- Pre-commit hook runs portfolio tests on a touched file.

---

### V0.20 — v0 exit-criteria sign-off (Duong-blocking)

**Goal:** Verify ADR §10 v0 exit criteria against the live emulator
build, archive a one-page sign-off note, promote this plan from
`in-progress/` → `implemented/` via `scripts/plan-promote.sh`
(rule 7).

**Inputs:** V0.1–V0.19 all merged.

**Outputs:**
- `assessments/2026-04-DD-portfolio-v0-exit-signoff.md` — one page:
  each ADR §10 v0 exit bullet checked off with evidence link
  (commit SHA, screenshot, or test run URL).
- Plan promoted to `plans/implemented/`.

**Acceptance criteria (mirroring ADR §10 v0 row exactly):**
- [ ] Both users can sign in (allowlist allows two emails).
- [ ] Both users can pick their base currency (modal works for USD and EUR).
- [ ] CSV import populates `users/{uid}/trades/*` for at least one user.
- [ ] Dashboard renders zero-state in the user's chosen base currency.
- [ ] `portfolio-tools/` module compiles with handler stubs +
      xfail tests (V0.4 done; non-v0 tools throw `NotImplementedError`).
- [ ] No T212/IB API code shipped (CSV-only).

**Duong-blocking:** Duong runs the happy path end-to-end on his own
machine and signs off in the assessment file. No agent may close
this task autonomously.

---

## Duong-blocking prerequisites (summary)

| ID | Item | Needed for | Notes |
|----|------|-----------|-------|
| **DV0-1** | Firebase project ID + provisioning | V0.1 | **RESOLVED** — reuse `myapps-b31ea` (prod) + `myapps-b31ea-staging` (staging). No new project. |
| **DV0-2** | Allowlisted email address(es) | V0.2 | **RESOLVED** — v0 single-email allowlist: `harukainguyen1411@gmail.com`. Stored as `config/auth_allowlist.emails` array in Firestore (runtime-configurable). Friend's email added later via Firestore doc edit, no redeploy. |
| **DV0-3** | Anonymized T212 export CSV sample | V0.6 | Real export from Duong's T212 account, scrubbed of PII. |
| **DV0-4** | Anonymized IB Activity Statement CSV sample | V0.7 | Multi-section sample. |
| **DV0-5** | Discord channel `#portfolio-digest` | (out of scope here — tracked under T9 / Ekko) | Not required for v0 ship, but mentioned for cross-team awareness. |
| **DV0-6** | Figma file "Strawberry — Portfolio v0" | V0.18 QA gate (rule 16) | Tracked under T4b / Neeko. |
| **DV0-7** | Sign-off run | V0.20 | Duong runs the v0 happy path and signs the exit note. |

DV0-3 and DV0-4 may slip without blocking everything: V0.6/V0.7 can
develop against synthetic fixtures derived from broker docs, but those
fixtures must be replaced with the real anonymized samples before V0.20
sign-off.

---

## Dispatch — critical path + parallel windows

**Strict serial spine:**
`V0.1 → V0.2 → V0.3 → (fan out) → V0.18 → V0.20`

**Parallel windows after V0.3:**

- **Window H (Handlers + CSV):** `V0.4 → V0.5 → V0.6 → V0.7 → V0.8`
- **Window U (UI):** `V0.9 → (V0.10, V0.13, V0.14 in parallel) → V0.11 → V0.12 → V0.15 → V0.16 → V0.17`

  Note: V0.13 is now a minimal composable task (no AccountSelector UI) — it can be unblocked by V0.9 alone (no dependency on V0.2 allowlist).

**Independent (any time after V0.1):** `V0.19` (CI scoping).

**Join point:** `V0.18` (E2E) requires the last commit of both windows.

**Final:** `V0.20` requires V0.18 + V0.19 green and Duong sign-off.

---

## Out-of-scope confirmations (for reviewer reference)

Per ADR §10 v0 row + §12 handoff notes, the following are explicitly
**not** in this plan and must not creep in:

- T212 REST adapter (v1).
- IB Client Portal adapter (v1.5).
- `mcp-portfolio` MCP server (v2).
- Claude Code Routine + scheduled digest (v2).
- Gemini chat panel + `gemini-chat-proxy` (v3).
- Auto-intent matching (v4).
- Sparkline / `snapshots` rendering (v1 — schema lands at v0 in V0.3
  but no UI consumes it yet).
- Trade ledger UI, intents UI, FX-override UI, manual refresh button
  (per design spec §1 out-of-scope list).
- Multi-account view / `AccountSelector` (deferred to v1 — Security Rules enforce per-user isolation and cross-user data access is not permitted at v0).
- Adding a second allowlisted email for a friend — the `config/auth_allowlist` Firestore doc is designed as a runtime-editable array; adding a friend's email requires only a Firestore doc edit, no code change or redeploy.

If a reviewer spots any of the above sneaking into a V0.x task spec,
that task should be rejected and re-scoped before implementation begins.
