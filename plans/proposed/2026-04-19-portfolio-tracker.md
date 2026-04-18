---
status: proposed
owner: azir
date: 2026-04-19
title: Portfolio Tracker — live 2-user app replacing the manual xlsx
supersedes: none
target-repo: harukainguyen1411/strawberry-app
---

# Portfolio Tracker — Architecture Decision Record

Replace the manual daily xlsx (`Portfolio tracker (2).xlsx`) with a live, near-realtime, 2-user portfolio tracker. Duong + one friend. Trading212 + Interactive Brokers ingestion, Vue SPA dashboard, scheduled Claude digest, ad-hoc Gemini chat panel. Tool-parity between UI and LLM surfaces is load-bearing.

Application code lives in `harukainguyen1411/strawberry-app` (public monorepo). This plan and agent memory stay in `Duongntd/strawberry`.

---

## 1. Goal

The current workflow is: each morning, Duong hand-edits an xlsx with broker balances, positions, trades, and free-text notes about buy/sell intents. It has no live prices, no history, and no second user. We replace it with a live system that:

- Ingests positions/trades/cash from Trading212 (T212) and Interactive Brokers (IB) on a 15-minute schedule plus on-demand refresh.
- Presents a mobile-first Vue dashboard with summary, positions, ledger, intents, and a sparkline of total-value history.
- Lets the user capture free-text trade intents and reconcile them against executed trades.
- Emits a scheduled Claude digest (morning + weekly) to a private Discord channel.
- Offers an ad-hoc Gemini chat panel with full tool-parity to the UI surface.

Non-goals: executing trades against brokers from the app (Level 4). That is explicitly out of scope for v1/v2/v3.

---

## 2. Users

Exactly two: Duong + one friend.

- **Auth** — Firebase Auth email-link sign-in, server-side allowlist (two emails). No public signup. New users added by editing the allowlist config and redeploying.
- **Isolation** — each user's data lives under `users/{uid}/...` subcollections. Security Rules enforce per-user read/write; no cross-user reads.
- **Shared LLM quota** — Duong's Claude Max plan powers the scheduled digest for both users. The friend's Claude availability is an open question (see §11).

---

## 3. Architecture

```
                 +---------------------+
                 |  Trading212 REST    |
                 +----------+----------+
                            |
                            |   (poll 15m, refresh on demand)
                            v
+-------------+     +-------+-------+     +------------------+
|  IB Client  +---->+ Cloud         +---->+ Firestore        |
|  Portal API |     | Functions     |     | (users/{uid}/*)  |
+-------------+     |  - poll-t212  |     +--------+---------+
                    |  - poll-ib    |              ^
+-------------+     |  - import-csv |              |
|  CSV upload +---->+               |              |
+-------------+     |  - portfolio- |              |
                    |    tools/     |              |
                    |  - mcp-       |              |
                    |    portfolio  |              |
                    |  - gemini-    |              |
                    |    chat-proxy |              |
                    +---+--------+--+              |
                        |        |                 |
              stdio/MCP |        | HTTPS callable  |
                        v        v                 |
              +---------+--+  +--+-----------+     |
              | Claude     |  | Vue SPA      +-----+
              | Code       |  | dashboards/  |
              | Routine    |  |  portfolio   |
              | (cron)     |  +--+-----------+
              +-----+------+     |
                    |            | (chat)
                    v            v
              +-----+-----+   +--+----------+
              | Discord   |   | Gemini 2.5  |
              | webhook   |   | Flash API   |
              +-----------+   +-------------+
```

Key properties:

- **Single source of truth** is Firestore. Brokers and LLMs are satellites.
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
  brokerCredentials: { t212: {...}, ib: {...} }   // KMS-wrapped at rest
  createdAt, updatedAt

users/{uid}/positions/{ticker}
  ticker, broker, quantity, avgCost, currency,
  lastPrice, lastPriceAt, marketValue, sector, assetClass

users/{uid}/trades/{tradeId}                       // immutable; tradeId = broker-assigned ID
  broker, ticker, side, quantity, price, currency,
  fee, executedAt, rawPayload

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

- **Trades are immutable.** `tradeId` is the broker-assigned ID — guarantees idempotent upserts on re-poll.
- **Positions are derived**, overwritten on every poll. Treat as a materialized view; trades are the ledger.
- **Intents are mutable** but carry `createdAt` — never deleted silently; status transitions are the audit trail.
- **Snapshots are write-once per date.** A late poll on day D only updates snapshot D if no snapshot D+1 exists yet.
- **Base currency is per-user.** Trades and positions are stored in their native broker currency; only derived totals (snapshots, summary card, sparkline, digest amounts) are converted to the user's `baseCurrency`. Snapshots embed the base used at write-time so a later base-currency switch does not silently rewrite history.

---

## 5. Ingestion

Three paths, same write contract:

1. **Scheduled poll** — Cloud Scheduler fires `poll-t212` and `poll-ib` every 15 minutes per user. Each function pulls positions + cash + trade history window (T212: 30-day rolling; IB: session-bounded), diffs against Firestore, appends new trades keyed by broker ID, overwrites positions + cash.
2. **Manual refresh** — HTTPS callable `portfolio_trigger_refresh` (throttle: 1 call / user / minute). Invokes the same poll handler synchronously.
3. **CSV import** — HTTPS callable `import-csv`, accepts T212 export CSV and IB Activity Statement CSV. Primary bootstrap path for users without API access yet, and fallback if an adapter breaks.

Diff rules:

- **New trade** — broker ID not already in `trades/` → insert.
- **Existing trade** — broker ID match → skip (immutability).
- **Position drift** — always overwrite `positions/{ticker}` from poll snapshot.
- **429 / rate limit** — exponential backoff with jitter; skip this cycle, log, retry next tick. Never block the scheduler.

IB specifically (Option β — Client Portal Web API): requires a 24h-renewable browser session. v1.5 will ship a human-in-the-loop re-auth flow (email link to Duong when the session expires). TWS gateway is deferred to v2+ if Option β proves too fragile.

---

## 6. LLM Integration (Hybrid)

Two LLM entry points, one shared tool surface.

### 6.1 Scheduled digest — Claude Code Routine

- Runs on Duong's machine under Claude Code Routine cron: **morning 08:00** and **weekly Sun 18:00**.
- Attaches `mcp-portfolio` MCP server over stdio. Server is a thin Node process that wraps the shared handlers in `portfolio-tools/` and authenticates to Firestore with a service-account key.
- Claude reads the portfolio via tools, writes a markdown digest, posts it to the private Discord webhook, and archives it to `users/{uid}/digests/{date}`.
- **Quota** — rides Duong's Claude Max plan; friend's digest runs under the same routine unless §11 changes that.

### 6.2 Ad-hoc chat — Gemini 2.5 Flash proxy

- Vue chat panel in the dashboard (ships v3).
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
- `portfolio_trigger_refresh` — rate-limited 1/min.
- `portfolio_set_fx_override` — manual FX rate override.
- `portfolio_mark_trade_matched` — link a trade to an intent (flips intent to `executed`).

**External lookup:**

- `portfolio_news_for_tickers` — Yahoo Finance RSS or Finnhub free tier.

**Chat scope — Level 3 (intent-writing).** Chat can create/update/delete intents and FX overrides, mark trades matched, and trigger refresh. Chat **cannot** execute trades against brokers. Level 4 is out of scope for v1/v2/v3.

---

## 8. UI

Single Vue SPA, mobile-first responsive, Firebase Hosting. Layout top-to-bottom on mobile; three-column on desktop:

1. **Summary card** — total value in the user's `baseCurrency` (USD or EUR), per-broker breakdown, % day / % YTD.
2. **Positions table** — sortable columns (ticker, qty, avg cost, last price, P&L %, sector), sector grouping toggle.
3. **Trade ledger** — range picker (7/30/90/180/all), virtualized list (react-virtualized equivalent in Vue, e.g. `vue-virtual-scroller`).
4. **Intents block** — editable cards, status badges (open/executed/stale), quick-create input.
5. **Sparkline** — Chart.js line chart of `snapshots/*.totalValueBase`, last 180 days, rendered in the user's base currency.
6. **Chat panel (v3)** — slide-in drawer on mobile, right column on desktop. Streaming responses from the Gemini proxy.

Chart.js chosen over D3 for bundle size and the sparkline being the only chart. Reassess if we add heavier analytics.

---

## 9. Non-Functional

- **Secrets** — broker credentials and Gemini API key in Firebase secret manager; broker tokens additionally KMS-wrapped at rest in Firestore (`users/{uid}.brokerCredentials`). Never in client bundles.
- **Security Rules** — per-user subcollection isolation. No `allow read, write: if true` anywhere. Rules tested with the Firebase emulator in CI.
- **Idempotency** — broker-assigned trade ID as Firestore doc ID in `trades/`. Re-polling is a no-op on unchanged data.
- **Observability** — Cloud Functions structured logs shipped to Cloud Logging; a private Discord alert channel for error-level events (poll failures, rate-limit exhaustion, IB re-auth needed).
- **Rate limits** — poll functions backoff on 429; Gemini proxy throttles per user (15 RPM / 1500 RPD ceiling shared); refresh 1/min/user hard cap.
- **TDD gate (repo rule 12)** — every implementation task is preceded on the same branch by an xfail test referencing the task ID. Pre-push hook and `tdd-gate.yml` enforce.
- **Regression gate (repo rule 13)** — any bugfix commit must include or be preceded by a regression test.
- **E2E gate (repo rule 15)** — Playwright flow exercises: sign-in → positions load → create intent → refresh → sparkline render. Required check on PR.
- **QA gate for UI PRs (repo rule 16)** — a QA agent runs the Playwright flow with video + screenshots and diffs against the Figma design before the PR can merge. Figma file to be stood up in v0.
- **Deploy smoke tests (repo rule 17)** — post-deploy smokes on stg and prod; prod failure triggers `scripts/deploy/rollback.sh`.
- **Merge discipline (repo rule 18)** — no self-merge, no `--admin`, one non-author approval required.

---

## 10. Phased Roadmap

| Phase | Scope | Exit criteria |
|---|---|---|
| **v0** | Skeleton: Firebase project, Auth + allowlist, Firestore schema (incl. per-user `baseCurrency`), CSV import, empty dashboard shell, shared `portfolio-tools/` handler module stub, xfail test scaffold per task. No broker APIs. | Both users sign in and pick their base currency; CSV import populates one `trades/` collection; dashboard renders zero-state in the user's chosen base; `portfolio-tools/` module compiles with handler stubs + xfail tests; no T212/IB code shipped. |
| **v1** | T212 adapter + dashboard positions/trades/intents/FX, manual refresh, mobile Vue. | 15-min poll green for 7 days on Duong's T212 account; positions/trades/intents render; manual refresh works. |
| **v1.5** | IB Client Portal adapter (Option β) + human-in-the-loop re-auth flow. | 24h session renewal working end-to-end. |
| **v2** | Claude Code Routine — morning digest → Discord. `mcp-portfolio` server shipped. | Daily digest lands in Discord for 7 consecutive mornings; archived to `digests/`. |
| **v2.5** | Weekly health-check routine (Sun 18:00). | One clean weekly run. |
| **v3** | Gemini chat panel (Level 3 scope, full tool-parity). | Chat creates/updates intents; throttling verified; all tools reachable from chat. |
| **v4** | Auto-intent-matching — `portfolio_mark_trade_matched` called by a Firestore trigger when a new trade fuzzy-matches an open intent. | Precision > 0.9 on Duong's historical set. |
| **v5+** | Claude proposes new intents (opt-in), deeper analytics, additional brokers. | TBD. |

Each phase is one approved plan of its own — this ADR is the umbrella.

---

## 11. Risks / Open Questions

Known gating questions flagged for Duong (do **not** re-ask in planning; carry into v1 kickoff):

1. **Does the friend have T212 API beta activation enabled?** If not, v1 ships with CSV-import-only for him until activation.
2. **Does the friend have an IB account with Client Portal API accessible?** If not, v1.5 is Duong-only; friend uses CSV.
3. **Does the friend have Claude Code + Max?** If not, his digest runs on Duong's shared quota under Duong's routine, or we skip his digest in v2.

Architectural risks worth tracking:

- **IB Client Portal 24h session fragility** — Option β requires browser re-auth every 24h. Mitigation: email re-auth link to Duong on session expiry. If this proves too disruptive, fall back to TWS gateway in v2+ (explicitly out of scope for v1.5).
- **Gemini free-tier ceiling** — 1500 RPD across both users is tight if chat becomes primary UX. Mitigation: per-user bucket, hard cap with graceful "try again in N minutes" UI. Paid-tier upgrade is a v3.5 decision.
- **T212 30-day trade-history window** — re-polling cannot recover trades older than 30 days. Mitigation: CSV bootstrap at v0/v1 covers history beyond the window; any future gap is a one-time CSV patch.
- **MCP stdio server auth** — the `mcp-portfolio` server runs on Duong's machine with a service-account key. Key leak risk. Mitigation: key stored in `secrets/` (gitignored), loaded via `tools/decrypt.sh`; key scoped to the two user UIDs only.
- **Intent parsing reliability** — free-text → structured is best-effort. v1 stores `rawText` always; parsing is informational. Do not gate any write on successful parse.
- **Two-user scale assumption** — schema assumes two users forever. If we expand past ~10 users, revisit Firestore indexing, Auth allowlist, and shared-quota model.

Open questions beyond the three above:

4. **Figma file owner** — RESOLVED (v0 kickoff, 2026-04-19): Neeko creates a fresh Figma file in Duong's workspace for the v0 dashboard and returns the file ID. QA gate (rule 16) diffs against that file.
5. **Discord webhook channel** — RESOLVED (v0 kickoff, 2026-04-19): channel does not exist. Ekko stands up `#portfolio-digest` (private) and the webhook in parallel, tracked as a separate task. Required before v2.
6. **FX source** — RESOLVED (v0 kickoff, 2026-04-19): ECB daily reference rates as the default source, with `portfolio_set_fx_override` as the manual escape hatch. No paid API for v1.
7. **Base currency per user** — RESOLVED (v0 kickoff, 2026-04-19): per-user choice between USD and EUR, set at onboarding, stored on `users/{uid}.baseCurrency`. The two users may run on different bases. This is a schema change, applied above in §3, §4, §5, and §8 — not a footnote.

---

## 12. Handoff Notes

For the task-breakdown agent picking this up after approval:

- **Repo** — all app code lands in `harukainguyen1411/strawberry-app` under `apps/portfolio/` and `dashboards/portfolio/`. This plan and any memory entries stay in `Duongntd/strawberry`. See `architecture/cross-repo-workflow.md`.
- **Phased delivery** — each phase (v0 through v3 at minimum) gets its own plan in `plans/proposed/` with a concrete task list. This ADR is the umbrella; do not try to execute it as a single sprint.
- **Tool-parity first** — the shared `portfolio-tools/` handler module is the architectural spine. Build it before either UI or MCP/Gemini adapters. Every feature after v0 adds one handler, then wires three adapters.
- **TDD sequencing** — xfail test commit → implementation commit, on the same branch, every task (rule 12). The adapter tests should live alongside the handler tests and share fixtures.
- **CSV-first bootstrap** — v0 ships CSV-only intentionally so the schema, rules, and dashboard shell are validated before any broker-API work. Do not skip.
- **Do not assign implementers here.** Plan writers never assign executors (repo convention).
- **Open questions §11** — surface items 1–3 to Duong at v1 kickoff; items 4–7 at v0 kickoff.
