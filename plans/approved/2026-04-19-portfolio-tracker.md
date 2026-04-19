---
status: approved
owner: azir
date: 2026-04-19
title: Portfolio Tracker — live 2-user app replacing the manual xlsx
supersedes: none
target-repo: harukainguyen1411/strawberry-app
---

# Portfolio Tracker — Architecture Decision Record

Replace the manual daily xlsx (`Portfolio tracker (2).xlsx`) with a live-ish, 2-user portfolio tracker. Duong + one friend. CSV-first ingestion for both [Trading212](https://t212public-api-docs.redoc.ly/) and Interactive Brokers; an optional T212 REST adapter may layer on later. Vue SPA dashboard. LLM surfaces (scheduled Claude digest, ad-hoc Gemini chat) deliberately deferred to v1+. Tool-parity between UI and LLM surfaces remains the architectural anchor.

Application code lives in `harukainguyen1411/strawberry-app` (public monorepo). This plan and agent memory stay in `Duongntd/strawberry`.

> **Scope-revision note (2026-04-19, post-approval):** Duong reduced v0 scope. The IB live-API path is removed from the roadmap entirely — IB is CSV-only forever (see §13). The T212 REST adapter is demoted from a v1 requirement to an optional v1 enhancement; CSV is now the primary ingestion path for both brokers. The Claude digest routine and the Gemini chat panel both move **up** from v2/v3 into **v1** (no longer gated behind broker-API work). v0 stays the CSV-only skeleton.

---

## 1. Goal & Scope Summary

The current workflow is: each morning, Duong hand-edits an xlsx with broker balances, positions, trades, and free-text notes about buy/sell intents. It has no live prices, no history, and no second user. We replace it with a system that:

- **Ingests via CSV upload as the primary path** for both Trading212 (T212) and Interactive Brokers (IB). Users export a CSV from the broker UI and upload it to the app.
- **Optionally** layers a T212 REST adapter on top of CSV (v1+ enhancement) for users with API beta activation; this gives 15-minute polling and on-demand refresh on top of the CSV baseline.
- Presents a mobile-first Vue dashboard with summary, positions, ledger, intents, and a sparkline of total-value history.
- Lets the user capture free-text trade intents and reconcile them against executed trades.
- Emits a scheduled Claude digest (morning + weekly) to a private Discord channel — shipped in **v1**.
- Offers an ad-hoc Gemini chat panel with full tool-parity to the UI surface — shipped in **v1**.

**Explicitly out of scope, roadmap-wide:**

- IB live-API integration of any flavour (Client Portal Web API, TWS gateway, ibkr-api-rust, etc.). IB is CSV-only. See §13.
- Executing trades against brokers from the app (Level 4 chat scope). Deferred indefinitely.

**What this means for v0 standalone value:** v0 is a CSV-ingest + dashboard-shell skeleton with no LLM surface and no broker polling. It is deliberately minimal. See §11 for the risk that v0 has limited standalone utility on its own.

---

## 2. Users

Exactly two: Duong + one friend.

- **Auth** — Firebase Auth email-link sign-in, server-side allowlist (two emails). No public signup. New users added by editing the allowlist config and redeploying.
- **Isolation** — each user's data lives under `users/{uid}/...` subcollections. Security Rules enforce per-user read/write; no cross-user reads.
- **Shared LLM quota** — Duong's Claude Max plan powers the scheduled digest for both users. The friend's Claude availability is an open question (see §11).

---

## 3. Architecture

```
                                +------------------+
                                |  CSV upload      |
                                |  (T212 + IB)     |
                                |  — primary path  |
                                +--------+---------+
                                         |
                                         v
+-------------+                 +--------+---------+
|  Trading212 |  (optional,     | Cloud Functions  |     +------------------+
|  REST       +->  v1+)         |  - import-csv    +---->+ Firestore        |
|             |                 |  - poll-t212 (*) |     | (users/{uid}/*)  |
+-------------+                 |  - portfolio-    |     +--------+---------+
                                |    tools/        |              ^
                                |  - mcp-          |              |
                                |    portfolio     |              |
                                |  - gemini-       |              |
                                |    chat-proxy    |              |
                                +---+----------+---+              |
                                    |          |                  |
                          stdio/MCP |          | HTTPS callable   |
                                    v          v                  |
                            +-------+--+    +--+-----------+      |
                            | Claude   |    | Vue SPA      +------+
                            | Code     |    | dashboards/  |
                            | Routine  |    |  portfolio   |
                            | (cron)   |    +--+-----------+
                            +----+-----+       |
                                 |             | (chat)
                                 v             v
                            +----+-----+   +---+---------+
                            | Discord  |   | Gemini 2.5  |
                            | webhook  |   | Flash API   |
                            +----------+   +-------------+

(*) poll-t212 is an optional v1+ add-on behind a per-user feature flag. Not a baseline dependency.
```

Key properties:

- **Single source of truth** is Firestore. Brokers and LLMs are satellites.
- **CSV is the primary ingestion path.** The T212 REST adapter, if/when it ships, writes into the same Firestore contract as CSV import — no parallel data paths.
- **IB is CSV-only, permanently.** There is no IB adapter on the roadmap.
- **Tool-parity** is enforced at the code level: UI callable functions, MCP tool handlers, and Gemini function declarations all delegate to the same handler module (`functions/portfolio-tools/`). No parallel logic paths.
- **Claude runs locally** on Duong's machine via Claude Code Routine with the `mcp-portfolio` server attached over stdio. It is not hosted on GCP. This keeps Claude usage on Duong's Max plan quota rather than per-call API billing.
- **Gemini runs as a Cloud Function proxy** — the API key stays server-side, per-user throttling is enforced, and function-calling lets the model hit the same tool surface.
- **Per-user base currency** — each user picks USD or EUR at onboarding (stored on `users/{uid}.baseCurrency`). All totals, snapshots, sparklines, digests, and chat responses render in that user's chosen base. FX conversion happens at the handler layer in `portfolio-tools/`, reading rates from `users/{uid}/meta/fx`. The two users may run on different bases simultaneously; no shared base assumption anywhere in the stack.

---

## 4. Data Model (Firestore)

```
users/{uid}
  email: string
  displayName: string
  baseCurrency: "USD" | "EUR"   // per-user choice, set at onboarding, mutable via settings
  brokerCredentials: { t212?: {...} }   // KMS-wrapped at rest; only populated if optional T212 API is enabled for this user
  featureFlags: { t212Api?: boolean }   // gates the optional T212 REST poll path
  createdAt, updatedAt

users/{uid}/positions/{ticker}
  ticker, broker, quantity, avgCost, currency,
  lastPrice, lastPriceAt, marketValue, sector, assetClass

users/{uid}/trades/{tradeId}                       // immutable; tradeId = broker-assigned ID (API) or deterministic hash (CSV)
  broker, ticker, side, quantity, price, currency,
  fee, executedAt, source: "csv" | "t212-api",
  rawPayload

users/{uid}/cash/{broker}
  broker, currency, amount, updatedAt

users/{uid}/intents/{intentId}
  rawText, parsed: { ticker?, side?, size?, priceTarget?, rationale? },
  status: "open" | "executed" | "stale",
  matchedTradeId?: string,
  createdAt, updatedAt

users/{uid}/meta/fx
  rates: { "USD->EUR": 0.92, "EUR->USD": 1.087, ... },   // both directions cached
  overrides: { "USD->EUR": 0.93 }?,
  updatedAt

users/{uid}/snapshots/{YYYY-MM-DD}
  baseCurrency: "USD" | "EUR",                  // snapshot of user's base at write-time
  totalValueBase, perBroker: {...}, perAsset: {...}, takenAt

users/{uid}/digests/{YYYY-MM-DD}
  kind: "morning" | "weekly",
  markdown, model, createdAt, discordMessageId?
```

Invariants:

- **Trades are immutable.** For API-sourced trades, `tradeId` is the broker-assigned ID. For CSV-sourced trades, `tradeId` is a deterministic hash over `{broker, executedAt, ticker, side, quantity, price}` — this guarantees idempotent re-uploads of the same CSV.
- **Positions are derived**, overwritten on every import or poll. Treat as a materialized view; trades are the ledger.
- **Intents are mutable** but carry `createdAt` — never deleted silently; status transitions are the audit trail.
- **Snapshots are write-once per date.** A late import on day D only updates snapshot D if no snapshot D+1 exists yet.
- **Base currency is per-user.** Trades and positions are stored in their native broker currency; only derived totals (snapshots, summary card, sparkline, digest amounts) are converted to the user's `baseCurrency`. Snapshots embed the base used at write-time so a later base-currency switch does not silently rewrite history.

---

## 5. Ingestion

Two paths, same write contract. (A third — the optional T212 REST adapter — is described below as a v1+ enhancement.)

1. **CSV import — primary.** HTTPS callable `import-csv`, accepts T212 export CSV and IB Activity Statement CSV. Users export from the broker UI on whatever cadence suits them (daily, weekly, ad-hoc). Deterministic trade-ID hashing means re-uploading the same CSV is a no-op. This is the **only** path for IB, forever.
2. **Manual refresh — CSV-centric.** The dashboard `Refresh` button prompts the user to upload a new CSV if they want updated positions/trades. There is no server-side polling in the baseline.

**Optional v1+ enhancement — T212 REST adapter:**

3. **Scheduled poll (T212 only, optional)** — behind `featureFlags.t212Api`. Cloud Scheduler fires `poll-t212` every 15 minutes for users with the flag on and credentials configured. Pulls positions + cash + trade history window (T212: 30-day rolling), diffs against Firestore, appends new trades keyed by broker ID, overwrites positions + cash. Writes into the same collections as CSV import; `source: "t212-api"` distinguishes the origin.
4. **Manual refresh (T212 API users)** — HTTPS callable `portfolio_trigger_refresh` (throttle: 1 call / user / minute). Invokes the poll handler synchronously.

Diff rules (apply to both CSV and API paths):

- **New trade** — trade ID not already in `trades/` → insert.
- **Existing trade** — trade ID match → skip (immutability).
- **Position drift** — always overwrite `positions/{ticker}` from the latest ingest snapshot.
- **429 / rate limit (API path only)** — exponential backoff with jitter; skip this cycle, log, retry next tick. Never block the scheduler.

---

## 6. LLM Integration (Hybrid)

Two LLM entry points, one shared tool surface. **Both ship in v1.**

### 6.1 Scheduled digest — Claude Code Routine (v1)

- Runs on Duong's machine under Claude Code Routine cron: **morning 08:00** and **weekly Sun 18:00**.
- Attaches `mcp-portfolio` MCP server over stdio. Server is a thin Node process that wraps the shared handlers in `portfolio-tools/` and authenticates to Firestore with a service-account key.
- Claude reads the portfolio via tools, writes a markdown digest, posts it to the private Discord webhook, and archives it to `users/{uid}/digests/{date}`.
- **Quota** — rides Duong's Claude Max plan; friend's digest runs under the same routine unless §11 changes that.
- **Data freshness** — in the CSV-only baseline, the digest reflects whatever the user last uploaded. If the optional T212 adapter is enabled, T212 data is fresh to the last 15-min poll. The digest prompt will disclose the source + timestamp so stale CSV reads are not mistaken for live data.

### 6.2 Ad-hoc chat — Gemini 2.5 Flash proxy (v1)

- Vue chat panel in the dashboard.
- Frontend calls a Cloud Function proxy `gemini-chat-proxy` (HTTPS callable, auth required).
- Proxy calls Gemini 2.5 Flash with function declarations that mirror the MCP tool set 1:1.
- **Free-tier budget**: 15 RPM / 1500 RPD per API key. Per-user throttle enforced in the proxy (token bucket in Firestore).
- API key lives in Firebase secret manager; never reaches the client.

### 6.3 Tool-parity (load-bearing)

Every UI action has a matching MCP tool has a matching Gemini function declaration. UI buttons and chat both call into `functions/portfolio-tools/*.ts`. There is **no parallel logic path** — the tool layer **is** the canonical API surface for the app. This is the architectural anchor of the whole project: it prevents drift, makes the LLM surface trivially testable, and lets us swap Claude/Gemini without rewriting features.

---

## 7. Tool Surface

Shared handler module: `strawberry-app/apps/portfolio/functions/portfolio-tools/`. Each tool is exported once and wired into three adapters: HTTPS callable (UI), MCP tool (Claude), Gemini function declaration (chat proxy).

**Read-only (positions/trades/cash are broker-owned):**

- `portfolio_get_snapshot` — current positions + cash + totals.
- `portfolio_get_trades` — filtered by range (7/30/90/180/all) and optional ticker.
- `portfolio_get_intents` — filter by status.
- `portfolio_get_digests` — paginated by date.
- `portfolio_get_snapshot_history` — for sparkline.

**Write (user-owned surfaces):**

- `portfolio_create_intent` / `_update_intent` / `_delete_intent`.
- `portfolio_set_sizing_rule` — stored under `users/{uid}/meta/sizing`.
- `portfolio_trigger_refresh` — rate-limited 1/min. In CSV-only mode this is a no-op that returns the last-import timestamp; when T212 API is enabled it invokes the poll handler.
- `portfolio_set_fx_override` — manual FX rate override.
- `portfolio_mark_trade_matched` — link a trade to an intent (flips intent to `executed`).

**External lookup:**

- `portfolio_news_for_tickers` — Yahoo Finance RSS or Finnhub free tier.

**Chat scope — Level 3 (intent-writing).** Chat can create/update/delete intents and FX overrides, mark trades matched, and trigger refresh. Chat **cannot** execute trades against brokers. Level 4 is out of scope permanently.

---

## 8. UI

Single Vue SPA, mobile-first responsive, Firebase Hosting. Layout top-to-bottom on mobile; three-column on desktop:

1. **Summary card** — total value in the user's `baseCurrency` (USD or EUR), per-broker breakdown, % day / % YTD. Shows last-import timestamp per broker so stale CSV data is obvious.
2. **Positions table** — sortable columns (ticker, qty, avg cost, last price, P&L %, sector), sector grouping toggle.
3. **Trade ledger** — range picker (7/30/90/180/all), virtualized list (react-virtualized equivalent in Vue, e.g. [`vue-virtual-scroller`](https://github.com/Akryum/vue-virtual-scroller)).
4. **Intents block** — editable cards, status badges (open/executed/stale), quick-create input.
5. **Sparkline** — Chart.js line chart of `snapshots/*.totalValueBase`, last 180 days, rendered in the user's base currency.
6. **CSV upload drawer** — primary ingestion UI. Drag-and-drop a T212 or IB CSV; preview the detected broker + row count before committing the import.
7. **Chat panel (v1)** — slide-in drawer on mobile, right column on desktop. Streaming responses from the Gemini proxy.

Chart.js chosen over D3 for bundle size and the sparkline being the only chart. Reassess if we add heavier analytics.

---

## 9. Non-Functional

- **Secrets** — Gemini API key in Firebase secret manager; optional T212 API tokens KMS-wrapped at rest in Firestore (`users/{uid}.brokerCredentials.t212`). Never in client bundles. IB credentials are **not stored** — IB is CSV-only.
- **Security Rules** — per-user subcollection isolation. No `allow read, write: if true` anywhere. Rules tested with the Firebase emulator in CI.
- **Idempotency** — CSV re-uploads are no-ops via deterministic trade-ID hashing. API-sourced trades use broker-assigned IDs. Re-polling is a no-op on unchanged data.
- **Observability** — Cloud Functions structured logs shipped to Cloud Logging; a private Discord alert channel for error-level events (CSV parse failures, optional-poll failures, rate-limit exhaustion).
- **Rate limits** — optional T212 poll backoffs on 429; Gemini proxy throttles per user (15 RPM / 1500 RPD ceiling shared); refresh 1/min/user hard cap.
- **TDD gate (repo rule 12)** — every implementation task is preceded on the same branch by an xfail test referencing the task ID. Pre-push hook and `tdd-gate.yml` enforce.
- **Regression gate (repo rule 13)** — any bugfix commit must include or be preceded by a regression test.
- **E2E gate (repo rule 15)** — Playwright flow exercises: sign-in → CSV upload → positions load → create intent → sparkline render. Required check on PR.
- **QA gate for UI PRs (repo rule 16)** — a QA agent runs the Playwright flow with video + screenshots and diffs against the Figma design before the PR can merge. Figma file stood up in v0.
- **Deploy smoke tests (repo rule 17)** — post-deploy smokes on stg and prod; prod failure triggers `scripts/deploy/rollback.sh`. <!-- orianna: ok — rollback.sh is a future deliverable, not yet created -->
- **Merge discipline (repo rule 18)** — no self-merge, no `--admin`, one non-author approval required.

---

## 10. Phased Roadmap

| Phase | Scope | Exit criteria |
|---|---|---|
| **v0** | Skeleton: Firebase project, Auth + allowlist, Firestore schema (incl. per-user `baseCurrency`), CSV import for T212 + IB, dashboard shell (summary, positions, trades, intents, sparkline — **no chat panel**), shared `portfolio-tools/` handler module stub, xfail test scaffold per task. No broker APIs. No LLM surfaces. | Both users sign in and pick their base currency; CSV import for both brokers populates `trades/` idempotently; dashboard renders the user's real positions from the uploaded CSV; `portfolio-tools/` module compiles with handler stubs + xfail tests; no T212/IB API code shipped; no Claude or Gemini wiring. |
| **v1** | (a) Claude Code Routine — morning + weekly digest → Discord. `mcp-portfolio` server shipped. (b) Gemini chat panel (Level 3 scope, full tool-parity). (c) Optional T212 REST adapter behind `featureFlags.t212Api` — 15-min poll + manual refresh. IB remains CSV-only. | Daily digest lands in Discord for 7 consecutive mornings, archived to `digests/`. One clean weekly digest. Chat creates/updates intents end-to-end; throttling verified; all tools reachable from chat. For users with `t212Api=true`: 15-min poll green for 7 days; manual refresh works. |
| **v2** | Auto-intent-matching — `portfolio_mark_trade_matched` called by a Firestore trigger when a new trade fuzzy-matches an open intent. | Precision > 0.9 on Duong's historical set. |
| **v3+** | Claude proposes new intents (opt-in), deeper analytics, additional brokers (not IB — see §13). | TBD. |

Each phase is one approved plan of its own — this ADR is the umbrella.

---

## 11. Risks / Open Questions

Known gating questions flagged for Duong (do **not** re-ask in planning; carry into v1 kickoff):

1. **Does the friend have T212 API beta activation enabled?** Only relevant for the optional T212 REST adapter in v1. If not, the friend runs CSV-only indefinitely, which is a fully supported mode.
2. **Does the friend have Claude Code + Max?** If not, his digest runs on Duong's shared quota under Duong's routine, or we skip his digest in v1.

Architectural risks worth tracking:

- **v0 has limited standalone value.** With no broker polling and no LLM surface, v0 is "upload a CSV and look at a dashboard" — strictly an incremental improvement over the xlsx, not a replacement. The replacement narrative only lands when v1 ships (Claude digest + Gemini chat + optional T212 polling). **Mitigation:** keep v0 short and scope-tight; treat it as the schema/rules/UI-shell validation phase, not as a user-facing milestone. Explicitly acknowledged to Duong at scope-reduction time (2026-04-19).
- **CSV-first means ingestion cadence is manual.** In the baseline, data freshness is bounded by how often the user remembers to upload a CSV. Positions drift silently between uploads. **Mitigation:** UI surfaces the last-import timestamp prominently on the summary card and in every digest header; Gemini chat responses include "data as of {timestamp}" in their preamble. The optional T212 adapter closes this gap for T212 accounts in v1; IB users live with the manual cadence.
- **LLM surfaces front-loaded in v1.** Shipping Claude digest + Gemini chat in v1 is more scope than the original v1/v2/v3 split. **Mitigation:** the shared `portfolio-tools/` handler module (built in v0) means both LLM surfaces are thin adapters, not independent implementations. If v1 slips, the optional T212 adapter is the first piece to defer, not the LLM work — LLM surfaces are the scope-reduction's core rationale.
- **Gemini free-tier ceiling** — 1500 RPD across both users is tight if chat becomes primary UX. Mitigation: per-user bucket, hard cap with graceful "try again in N minutes" UI. Paid-tier upgrade is a v1.5 decision.
- **T212 30-day trade-history window (optional adapter only)** — re-polling cannot recover trades older than 30 days. Mitigation: CSV bootstrap at v0 covers history beyond the window; any future gap is a one-time CSV patch. Non-issue for CSV-only users.
- **MCP stdio server auth** — the `mcp-portfolio` server runs on Duong's machine with a service-account key. Key leak risk. Mitigation: key stored in `secrets/` (gitignored), loaded via `tools/decrypt.sh`; key scoped to the two user UIDs only.
- **Intent parsing reliability** — free-text → structured is best-effort. v0 stores `rawText` always; parsing is informational. Do not gate any write on successful parse.
- **Two-user scale assumption** — schema assumes two users forever. If we expand past ~10 users, revisit Firestore indexing, Auth allowlist, and shared-quota model.

Open questions beyond the two above:

3. **Figma file owner** — RESOLVED (v0 kickoff, 2026-04-19): Neeko creates a fresh Figma file in Duong's workspace for the v0 dashboard and returns the file ID. QA gate (rule 16) diffs against that file.
4. **Discord webhook channel** — RESOLVED (v0 kickoff, 2026-04-19): channel does not exist. Ekko stands up `#portfolio-digest` (private) and the webhook in parallel, tracked as a separate task. Required before v1 (previously v2).
5. **FX source** — RESOLVED (v0 kickoff, 2026-04-19): ECB daily reference rates as the default source, with `portfolio_set_fx_override` as the manual escape hatch. No paid API for v1.
6. **Base currency per user** — RESOLVED (v0 kickoff, 2026-04-19): per-user choice between USD and EUR, set at onboarding, stored on `users/{uid}.baseCurrency`. The two users may run on different bases.
7. **T212 CSV schema stability** — NEW (2026-04-19 scope revision): CSV-first means we now depend on T212's exported CSV format being stable. T212 has changed column layouts historically. **Action needed at v0 kickoff:** Duong to provide one real T212 export and one real IB Activity Statement so the parser can be built against actual fixtures, not guessed schemas. Parser must fail loudly (not silently drop rows) on unrecognized columns.
8. **v0 "done" definition** — NEW (2026-04-19 scope revision): with no polling and no LLMs, what's the explicit signal that v0 is "done enough to cut v1"? Proposed: both users have uploaded one real CSV each, positions render correctly, at least one intent is created, and a snapshot has been written to `snapshots/`. Needs Duong sign-off before v0 kickoff.

---

## 12. Handoff Notes

For the task-breakdown agent picking this up after approval:

- **Repo** — all app code lands in `harukainguyen1411/strawberry-app` under `apps/portfolio/` <!-- orianna: ok — proposed future path in strawberry-app --> and `dashboards/portfolio/` <!-- orianna: ok — proposed future path in strawberry-app -->. This plan and any memory entries stay in `Duongntd/strawberry`. See `architecture/cross-repo-workflow.md`.
- **Phased delivery** — v0 and v1 each get their own plan in `plans/proposed/` with a concrete task list. This ADR is the umbrella; do not try to execute it as a single sprint.
- **Tool-parity first** — the shared `portfolio-tools/` handler module is the architectural spine. Build it in v0 (as stubs) before either UI or MCP/Gemini adapters land in v1. Every feature after v0 adds one handler, then wires three adapters.
- **TDD sequencing** — xfail test commit → implementation commit, on the same branch, every task (rule 12). The adapter tests should live alongside the handler tests and share fixtures.
- **CSV-first, permanently for IB.** v0 ships CSV-only intentionally so the schema, rules, and dashboard shell are validated before any broker-API or LLM work. IB never moves off CSV — do not propose an IB adapter in any future plan without explicit Duong sign-off (see §13).
- **v1 is LLM-heavy, API-light.** The v1 plan's centre of gravity is the Claude routine + Gemini chat proxy, not the optional T212 adapter. If v1 scope has to shrink, cut the T212 adapter before cutting LLM work.
- **Do not assign implementers here.** Plan writers never assign executors (repo convention).
- **Open questions §11** — surface items 1–2 to Duong at v1 kickoff; items 3–8 at v0 kickoff. Items 7 and 8 are new in the 2026-04-19 scope revision and are the first things to clear before v0 starts.

---

## 13. Explicitly Out of Scope — Future-Work Notes

These are recorded so future planning agents do not re-propose them without explicit Duong sign-off.

- **Interactive Brokers live API (any flavour).** Removed from the roadmap entirely on 2026-04-19 as part of the post-approval scope reduction. This includes Client Portal Web API (Option β), TWS gateway, IBKR Web API, ibkr-api-rust, and any third-party IB wrapper. IB is **CSV-only forever** unless Duong explicitly reopens this. The 24h session fragility of Client Portal and the operational overhead of TWS were the decisive factors; CSV export from IB's UI is an acceptable manual workflow for a 2-user app.
- **Trade execution from the app (Level 4 chat scope).** Deferred indefinitely. Chat tops out at Level 3 (intent-writing).
- **Additional brokers beyond T212 + IB.** Not on the roadmap. Any addition is a v3+ conversation.
