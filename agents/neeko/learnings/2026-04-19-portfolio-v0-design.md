# Portfolio v0 — Dashboard Design Spec

**Author:** Neeko · **Date:** 2026-04-19 · **Phase:** v0 (CSV-only)
**Source ADR:** `plans/proposed/2026-04-19-portfolio-tracker.md`
**Implementer:** Seraphine (T6) · **Target app:** `apps/myapps/portfolio-tracker/` (Vue 3 + Tailwind)

> **Note on Figma:** the canonical Figma file ("Strawberry — Portfolio v0") must be stood up
> manually in Duong's workspace; this spec is the implementation source of truth in the
> meantime and should be mirrored into Figma frame-for-frame for the QA gate (rule 16).

---

## 1. Scope

v0 ships **CSV-only** ingestion. Three screens + four states. No broker APIs, no chat, no
sparkline. Goal: validate schema, auth, security rules, and the dashboard shell with
real data the user pastes in.

In-scope screens:

1. **CSV Import** — upload / paste / parse / commit
2. **Dashboard** — account selector, summary card, holdings table
3. **Empty / Error / Loading states**

Out-of-scope for v0: trade ledger UI (data exists, no view), intents UI, sparkline,
chat panel, FX-override UI, manual refresh button.

---

## 2. Design Tokens (existing — reuse, don't re-define)

Source: `apps/myapps/portfolio-tracker/src/assets/main.css` (Warm Night palette).

| Token | Dark | Use |
|---|---|---|
| `--bg` | `#111110` | page background |
| `--surface` | `#1c1a18` | cards |
| `--surface-hi` | `#272420` | table rows hover, inputs |
| `--border` | `rgba(255,255,255,0.07)` | low-emphasis dividers |
| `--border-hi` | `rgba(255,255,255,0.14)` | inputs, focused borders |
| `--text` | `#f4efe8` | primary text |
| `--muted` | `#9c9188` | labels, secondary |
| `--accent` | `#cc2e2e` | CTAs, active states |
| `--accent-soft` | `#e85555` | hover, gain markers |

**New tokens to propose** (semantic, derive from accent):

| Token | Value | Use |
|---|---|---|
| `--positive` | `#3fb96b` | P/L > 0 |
| `--negative` | `var(--accent)` | P/L < 0 (already coral) |
| `--warn` | `#e0a800` | CSV parse warnings |

Type: `DM Sans` already loaded. Tabular nums for monetary cells: `font-variant-numeric: tabular-nums`.

Spacing scale: Tailwind defaults. Card radius: `16px` (matches `.ds-glass`).

---

## 3. Breakpoints

| Name | Min width | Layout |
|---|---|---|
| `sm` (mobile) | 375px | single column, stacked |
| `lg` (desktop) | 1024px | two-column: left 320px (account/summary), right fluid (holdings) |

Mobile-first per ADR §3 — design at 375px first, expand.

---

## 4. Screen Specs

### 4.1 App Shell (`<AppShell.vue>`)

**Anatomy (top → bottom, mobile):**
```
┌─────────────────────────────────────┐
│  [≡]  Strawberry · Portfolio   [👤] │  ← header, 56px, sticky, --nav-bg
├─────────────────────────────────────┤
│                                     │
│  <router-view />                    │
│                                     │
└─────────────────────────────────────┘
```

- **Header:** `h-14 px-4 flex items-center justify-between` · backdrop-blur · `border-b border-[var(--border)]`
- **Left:** menu icon (mobile only, opens drawer for account selector) + brand "Strawberry · Portfolio"
- **Right:** avatar circle, 32px, initials fallback, click → sign-out menu
- **Desktop (≥lg):** menu icon hidden; account selector lives in left rail (4.3.1) instead of drawer

### 4.2 CSV Import (`/import`, `<CsvImport.vue>`)

Two-step flow: **upload/paste → preview/confirm**.

**Step 1 — Source:**
```
┌─────────────────────────────────────┐
│  Import trades                      │  H1, text-2xl font-medium
│  Paste a CSV from T212 or IB, or    │  body, --muted
│  drop a file below.                 │
│                                     │
│  ┌───────────────────────────────┐  │
│  │  Source                  [▾]  │  │  Select: "Trading 212" | "Interactive Brokers"
│  └───────────────────────────────┘  │
│                                     │
│  ╔═══════════════════════════════╗  │
│  ║                               ║  │  Drop zone, dashed border-hi,
│  ║   Drop CSV here  or  browse   ║  │  240px tall mobile / 200 desktop,
│  ║                               ║  │  --surface bg, hover → --surface-hi
│  ╚═══════════════════════════════╝  │
│                                     │
│  — or paste —                       │
│                                     │
│  ┌───────────────────────────────┐  │
│  │                               │  │  <textarea> 8 rows, monospace,
│  │                               │  │  --surface-hi bg, --border-hi border
│  │                               │  │
│  └───────────────────────────────┘  │
│                                     │
│  [ Cancel ]      [ Parse → ]        │  ghost + primary
└─────────────────────────────────────┘
```

**Step 2 — Preview:**
```
┌─────────────────────────────────────┐
│  ← Back                             │
│  Preview · 47 trades, 12 positions  │  H2 + count chip
│  Source: Trading 212                │  --muted
│                                     │
│  ⚠ 2 rows skipped — see details     │  warn banner if errors > 0
│                                     │
│  ┌─ Holdings preview ────────────┐  │  collapsed table, max 5 rows
│  │ AAPL  ·  100  ·  $14,850     │  │  + "Show all" link
│  │ MSFT  ·   25  ·  $10,200     │  │
│  │ ...                           │  │
│  └───────────────────────────────┘  │
│                                     │
│  ┌─ Trades preview ──────────────┐  │  collapsed table, max 5 rows
│  │ 2026-04-15  AAPL  BUY  ...    │  │
│  └───────────────────────────────┘  │
│                                     │
│  [ Cancel ]   [ Commit import → ]   │
└─────────────────────────────────────┘
```

**Components introduced:**

- `<DropZone>` — `props: { accept: string, maxSizeMb: number }` · emits `file`, `error` · states: `idle | dragover | error`
- `<CsvPasteArea>` — `v-model: string` · 8-row textarea, monospace, max ~1MB
- `<ImportPreviewTable>` — `props: { rows: object[], columns: ColumnDef[], maxVisible: number }` · "Show all" expander
- `<WarnBanner>` — `props: { count: number, message: string, details?: string[] }` · click expands details list
- `<SourceSelect>` — controlled select; locks parsing strategy

**Validation / errors (see §5 for full state matrix):**

- Empty file/paste → primary CTA disabled, helper text "Add a CSV to continue"
- Parse failure (bad headers) → red banner, list expected vs received headers
- Partial-row failure → warn banner, list row numbers + reason

### 4.3 Dashboard (`/`, `<DashboardView.vue>`)

**Mobile layout (375px):**
```
┌─────────────────────────────────────┐
│  Account: Duong [▾]                 │  AccountSelector chip
│                                     │
│  ┌─ Summary ─────────────────────┐  │  glass card
│  │ Total value                   │  │  --muted, text-xs uppercase
│  │ $ 124,567.89                  │  │  text-3xl font-medium tabular-nums
│  │ ▲ $1,204.50 (+0.97%) today    │  │  --positive, text-sm
│  │                               │  │
│  │ Positions: 12  ·  Cash: $4.2k │  │  --muted, text-xs
│  └───────────────────────────────┘  │
│                                     │
│  Holdings                           │  H2, mb-3
│  ┌─ Holdings ────────────────────┐  │  glass card, no padding
│  │ AAPL                          │  │  HoldingRow stacked layout
│  │ 100  ·  avg $148.50           │  │  on mobile (see 4.3.3)
│  │ $14,850     ▲ +$320 (2.2%)    │  │
│  ├───────────────────────────────┤  │
│  │ MSFT                          │  │
│  │ 25   ·  avg $408.00           │  │
│  │ $10,200     ▼ -$150 (-1.5%)   │  │
│  ├───────────────────────────────┤  │
│  │ ...                           │  │
│  └───────────────────────────────┘  │
│                                     │
│  [ Re-import CSV ]                  │  ghost button, full-width
└─────────────────────────────────────┘
```

**Desktop layout (≥1024px):**
```
┌──────────────┬──────────────────────────────────────────┐
│              │  Summary card (full width of right col)  │
│  Account     ├──────────────────────────────────────────┤
│  ──────      │  Holdings (table layout)                 │
│  ⦿ Duong    │  ┌───┬─────┬──────┬──────────┬─────────┐ │
│  ◯ Friend   │  │Tic│ Qty │ Avg  │  Value   │ P/L     │ │
│              │  ├───┼─────┼──────┼──────────┼─────────┤ │
│  Re-import   │  │AAP│ 100 │148.50│ $14,850  │+$320 ▲  │ │
│              │  │MSF│  25 │408.00│ $10,200  │-$150 ▼  │ │
│              │  └───┴─────┴──────┴──────────┴─────────┘ │
└──────────────┴──────────────────────────────────────────┘
   320px                     fluid
```

#### 4.3.1 `<AccountSelector>`

- **Mobile:** chip in dashboard header (`Account: Duong ▾`); tap opens bottom-sheet with radio list.
- **Desktop:** vertical radio list in left rail.
- **Props:** `accounts: { uid, displayName }[]`, `v-model: uid`
- **States:** `idle | open | switching` (skeleton during switch)
- **A11y:** `role="radiogroup"`, each option `role="radio" aria-checked`. Bottom sheet traps focus, Esc closes.

#### 4.3.2 `<SummaryCard>`

- **Anatomy:** `ds-glass` card · padding `p-5` mobile / `p-6` desktop
- **Props:** `totalValue: Money`, `dayChange: Money`, `dayChangePct: number`, `positionsCount: number`, `cashTotal: Money`
- **`Money` type:** `{ amount: number, currency: 'USD' | 'EUR' }` — see §6
- **States:** `loading` (shimmer skeleton on amount), `loaded`, `stale` (small "Last update: 3h ago" --muted footer if data > 1h old)
- **No day change in v0** if no historical snapshot → render `—` placeholder, hide arrow

#### 4.3.3 `<HoldingsTable>` / `<HoldingRow>`

Two presentations of the same data; pick by breakpoint.

**Mobile — `<HoldingRow>` (stacked):**
- Container: `py-4 px-5 border-b border-[var(--border)]`
- Line 1: ticker (text-base font-medium), broker badge right (`T212` / `IB`, --muted, text-xs)
- Line 2: `qty · avg cost` (text-sm --muted)
- Line 3: market value left (text-base tabular-nums), P/L right with arrow + currency-aware value + percent
- Tap → expandable detail (sector, asset class, last-price-at) — v0 nice-to-have, can defer

**Desktop — `<HoldingsTable>` (table):**
- `<table>` with sticky header
- Columns: Ticker · Broker · Qty · Avg cost · Market value · P/L (abs) · P/L (%)
- Sortable by clicking header; default sort: market value desc
- Row hover: `bg-[var(--surface-hi)]`
- All money cells: `tabular-nums text-right`
- P/L cells: color-coded `--positive` / `--negative`; arrow icon ▲ ▼ inline

**Props:**
```ts
interface Holding {
  ticker: string;
  broker: 'T212' | 'IB';
  quantity: number;
  avgCost: Money;          // native currency
  marketValue: Money;      // displayed currency (see §6)
  pl: Money;
  plPct: number;
  sector?: string;
  assetClass?: string;
  lastPriceAt?: Date;
}
```

**States:** `loading` (5 skeleton rows), `empty` (see §5.1), `loaded`, `error`

---

## 5. State Specs

### 5.1 Empty (no CSV imported yet)

Shown on `/` when user has zero positions and zero trades.

```
┌─────────────────────────────────────┐
│            🍓                       │  brand emoji or strawberry SVG, 64px
│                                     │
│      No portfolio data yet          │  H2
│  Import a CSV to get started.       │  body --muted
│                                     │
│        [ Import CSV → ]             │  primary CTA, links /import
└─────────────────────────────────────┘
```

Centered vertically and horizontally. Card not used — flat on background.

### 5.2 Loading

- App shell renders immediately
- Summary card + holdings card: skeleton shimmer (`animate-pulse` on `--surface-hi` blocks)
- Account selector: render with last-selected account from `localStorage`, no skeleton

### 5.3 Error — CSV malformed (during import preview)

```
┌─ ⚠ Could not parse CSV ────────────┐
│ Expected headers: Ticker, Action,  │
│ No. of shares, Price, Total, ...   │
│                                     │
│ Received: ticker,qty,price          │
│                                     │
│ [ Try again ]   [ Help ]            │
└─────────────────────────────────────┘
```

- Banner color: red, border `--accent`, bg `color-mix(in srgb, var(--accent) 10%, transparent)`
- "Help" link → docs (deferred — link to GH issue tracker for v0)

### 5.4 Error — Partial parse (some rows skipped)

- `<WarnBanner>` at top of preview screen
- Click expands list: `Row 7: missing price`, `Row 14: invalid date "2026/13/45"`
- User can still commit; skipped rows are dropped

### 5.5 Error — Network/Firestore write failure on commit

- Toast at bottom (mobile) / top-right (desktop): "Couldn't save import. Retry?"
- 5s auto-dismiss · button text "Retry" re-runs commit · keeps preview state intact

---

## 6. Currency Handling (RESOLVED — per amended ADR §3-§5, 2026-04-19)

**Per-user base currency** — each user picks USD or EUR at onboarding (`users/{uid}.baseCurrency`). Trades and positions are stored in **native broker currency**; only **derived totals** (summary, P/L, snapshots) are converted to the user's base via `portfolio-tools/` handler reading `users/{uid}/meta/fx`.

**Holdings display rules:**

- **Quantity:** unit count, no currency
- **Avg cost:** **native currency** (per-position) — what the user actually paid
- **Market value:** **base currency** — converted, comparable across positions
- **P/L (abs + %):** **base currency** — comparable, color-coded

This means most rows show **two currencies** (e.g. AAPL: avg cost $148.50 USD, market value €13,650 EUR for a EUR-base user). The currency code is rendered explicitly when it differs from base (e.g. `$148.50` shown subtly with `USD` badge, or styled with light-weight currency symbol).

**Updated `<HoldingsTable>` columns (desktop):**
| Ticker | Broker | Qty | Avg cost (native) | Market value (base) | P/L (base, %) |

**Updated `<HoldingRow>` (mobile):**
- Line 1: ticker · broker badge
- Line 2: `qty · avg $148.50 USD` (--muted, currency suffix when ≠ base)
- Line 3: market value (base) left, P/L (base) right

**Onboarding currency picker:**
First-run modal after sign-in if `baseCurrency` is unset:
```
┌─ Pick your base currency ──────────┐
│  All totals and P/L will be shown  │
│  in this currency.                 │
│                                    │
│   ⦿ USD ($)    ◯ EUR (€)          │
│                                    │
│  You can change this later in      │
│  Settings.                         │
│                                    │
│         [ Continue → ]             │
└────────────────────────────────────┘
```
- Component: `<BaseCurrencyPicker>` · props: `v-model: 'USD' | 'EUR'` · emits `confirm`
- Cannot dismiss until selected (no Esc, no backdrop close) — required field

**`Money` type:**
```ts
type CurrencyCode = 'USD' | 'EUR';
interface Money { amount: number; currency: CurrencyCode; }
```

Formatter: `Intl.NumberFormat(locale, { style: 'currency', currency })` via composable `useMoneyFormat(money)`. Locale: `en-US` for USD, `en-IE` for EUR.

**Visual treatment for native ≠ base:** use a small uppercase currency badge (e.g. `USD`, --muted, text-xs, ml-1) rather than a full `$` symbol overload. Reduces parsing load on rows where multiple currencies appear.

---

## 7. Interaction Flows

### 7.1 First-time user

```
sign-in (Firebase email link)
       → BaseCurrencyPicker modal (USD or EUR) → confirm
       → /  (empty state) → tap "Import CSV"
       → /import (Step 1) → drop file
       → parse client-side → /import (Step 2 preview)
       → tap "Commit import" → loading → toast "Imported 47 trades"
       → redirect /  (loaded state, all totals in chosen base)
```

### 7.2 Account switch

```
mobile: tap account chip → bottom sheet
desktop: click radio in left rail
       → switching state (skeleton holdings)
       → fetch new uid's positions + cash
       → loaded
```

### 7.3 Re-import

```
/  → "Re-import CSV" button → /import?mode=replace
   → Step 2 preview shows diff: "+5 new trades, 0 modified, 0 removed"
   → commit → merge into existing trades collection (idempotent on broker tradeId per ADR §5)
```

---

## 8. Accessibility

- All interactive elements ≥44×44px hit area (mobile)
- Focus ring: `outline: 2px solid var(--accent-soft); outline-offset: 2px`
- Color contrast: verify `--text` on `--bg` ≥ 7:1 (it is — `#f4efe8` on `#111110` ≈ 16:1); `--muted` on `--bg` ≥ 4.5:1 (verified ≈ 6.8:1)
- P/L color is **not** the sole signal — always pair with ▲/▼ icon and `+`/`-` sign in the number
- `<DropZone>`: keyboard-accessible "browse" button as fallback; announces drop result via `aria-live="polite"`
- `<AccountSelector>` bottom sheet: focus trap, `aria-modal="true"`, Esc to close
- Tables: `<th scope="col">`, sortable headers announce sort state via `aria-sort`
- Skeleton loaders: `aria-busy="true"` on parent, `aria-label="Loading"` on first skeleton

---

## 9. Component Inventory (handoff to Seraphine)

New components to build (all in `apps/myapps/portfolio-tracker/src/components/`):

| Component | Files | Notes |
|---|---|---|
| `AppShell.vue` | new | header + slot; uses existing `--nav-bg` |
| `AccountSelector.vue` | new | mobile bottom-sheet + desktop radio list variants |
| `SummaryCard.vue` | new | `ds-glass` based |
| `HoldingsTable.vue` | new | desktop table |
| `HoldingRow.vue` | new | mobile stacked row |
| `CsvImport.vue` | new (view) | two-step state machine |
| `DropZone.vue` | new | drag/drop primitive |
| `CsvPasteArea.vue` | new | textarea wrapper |
| `ImportPreviewTable.vue` | new | collapsed/expanded list |
| `WarnBanner.vue` | new | warn variant |
| `ErrorBanner.vue` | new | error variant |
| `EmptyState.vue` | new | reusable, props: `icon, title, body, ctaLabel, ctaTo` |
| `MoneyCell.vue` | new | wraps `Intl.NumberFormat`; props: `Money`, optional `showCurrencyBadge` for native≠base |
| `PlCell.vue` | new | formats P/L abs + pct + arrow + color (base currency only) |
| `BaseCurrencyPicker.vue` | new | onboarding modal, undismissable until selected |

Composables:

- `useMoneyFormat(money: Money, locale?: string): string`
- `useAccountSwitcher()` — exposes `currentUid`, `accounts`, `switchTo(uid)`
- `useCsvParser(source: 'T212' | 'IB', text: string)` — returns `{ trades, positions, errors }`

Existing tokens/utilities to reuse: `.ds-glass`, `.ds-btn-primary`, `.ds-btn-ghost` already in `main.css`.

---

## 10. Open Items for Duong / Team

1. **Figma file standup** (Duong-only) — needed before T7/T8 (QA gate rule 16). Mirror this spec into "Strawberry — Portfolio v0" frame-by-frame.
2. **Currency model** — RESOLVED per amended ADR (see §6); native cost + base totals.
3. **Sector / asset class display** — schema has them (ADR §4); v0 spec hides them on mobile to keep rows scannable. Confirm OK to defer to v1.
4. **Re-import diff calculation** — spec assumes idempotent merge (per ADR §5); if swain wants explicit "replace all" path, add a confirm dialog.
5. **Empty-state imagery** — using strawberry emoji as placeholder; consider commissioning a small SVG illustration matching landing page style.
