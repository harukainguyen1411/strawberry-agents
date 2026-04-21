---
status: proposed
orianna_gate_version: 2
complexity: normal
concern: work
owner: Sona
created: 2026-04-20
tags:
  - demo-studio
  - service-1
  - managed-agent
  - dashboard
  - ui
  - work
tests_required: true
---

# ADR: Managed Agent Control — Dashboard Tab (Demo Studio v3 Service 1)

Date: 2026-04-20
Scope: `company-os/tools/demo-studio-v3` (Service 1 only), `/dashboard` UI.
Related:
- `plans/2026-04-20-managed-agent-lifecycle.md` — automated monitor (idle warn + auto-terminate). Shares the SDK wrapper introduced below.
- `secretary/agents/azir/learnings/2026-04-20-managed-agent-lifecycle-adr.md` — SDK-gap context.

## 1. Context

The `/dashboard` tab in Service 1 today renders exclusively from our Firestore `demo-studio-sessions` collection. That means:

- **Blind to orphans.** A managed session alive on Anthropic but with no Firestore row is invisible. Operators cannot see it, let alone kill it.
- **Blind to drift.** A Firestore row marked `completed` whose managed session was never deleted shows as "done" while silently billing.
- **`cost_usd` is our estimate**, computed from session duration inside Service 1. It is not Anthropic's ground truth.

The lifecycle ADR addresses the automated path (scanner + auto-kill). Operators still need a human surface to: inspect the live Anthropic view, correlate it with our DB, and terminate a session on demand — including orphans. Separate ADRs because the surfaces differ (async loop vs. HTTP route + UI) even though both hit the same Anthropic API.

## 2. Decision

Add a second tab to `/dashboard` titled **"Managed Agents"** that:

1. Lists managed sessions directly from Anthropic (creator-key-scoped).
2. Joins each row via a **two-source join** (per BD amendment §2.1):
   - **Firestore `demo-studio-sessions`** (by `managedSessionId`) → `sessionId`, `slackChannel`, `slackThreadTs`, `userEmail` (resolved from `slackUserId`), `dbStatus`. All lifecycle fields per BD-1.
   - **S2 `config_mgmt_client.fetch_config(sessionId)`** → `brand`. Only brand. No `insuranceLine` — that field does not exist on S2.
3. Shows orphan rows (Anthropic-only, no DB match), tagged visibly. Orphan rows: skip both joins.
4. Exposes a per-row **Terminate** action with a confirmation modal. Terminate calls Anthropic, then flips the DB row (if matched) to `cancelled` with `cancelReason: manual_dashboard`, and writes an audit-log entry.
5. Reuses `managed_session_client.py` — the same SDK wrapper introduced for the lifecycle scanner. One place owns Anthropic list/retrieve/delete calls.

The existing tab (DB-rendered sessions view) stays unchanged. This is additive.

## 3. UI layout

Two-tab interface, client-side state, no route split:

```
+----------------------------------------------------------+
| Demo Studio Dashboard                                    |
+----------------------------------------------------------+
| [ Sessions ]  [ Managed Agents ]                         |  <- tab bar
+----------------------------------------------------------+
| Filter: [ All | Active | Idle | Orphans ]   Sort: idle v |
+----------------------------------------------------------+
| Sess ID    Status  Idle   Brand     User         Action  |
|----------------------------------------------------------|
| ses_abc    idle    62m    Allianz   dnt@missmp   [Stop]  |
| ses_def    running 4m     AXA       jmr@missmp   [Stop]  |
| ses_ghi    idle    130m   — ORPHAN  —            [Stop]  |
| ses_jkl    idle    12m    Generali  ppt@missmp   [Stop]  |
+----------------------------------------------------------+
```

Columns (left to right):
- **Managed Session ID** — truncated, click to copy full.
- **Anthropic Status** — `idle | running | rescheduling | terminated` (per SDK).
- **Idle** — minutes since last activity. `—` with tooltip if Spike 1 confirms the field is unavailable.
- **Brand** — from S2 via `config_mgmt_client.fetch_config(sessionId)` (per BD amendment §2.2). `—` when brand is in `degradedFields` (cold session or S2 unreachable). `— ORPHAN` if no Firestore match.
- **User** — email resolved from Firestore `slackUserId`. Blank on orphan.
- **DB Status** — our Firestore status. Blank on orphan. Flags drift if `terminated` on Anthropic but not a terminal status in our DB.
- **Slack Thread** — link to the session's slack thread if present.
- **Action** — `[Stop]` button, disabled if Anthropic status is already `terminated`.

Default sort: idle duration descending (longest-idle first). Filter `Orphans` shows only Anthropic-only rows. See Q2 on default orphan visibility (LOCKED — show by default, tagged).

No paging in v1 — at <100 concurrent sessions, a single list call with client-side filter is fine. See Q3.

## 4. Backend routes

All routes live on Service 1. Require no new auth (inherit whatever guards the existing dashboard — see section 8).

### `GET /api/managed-sessions`

Returns the merged list. Response shape (per BD amendment §2.3):

```json
{
  "sessions": [
    {
      "managedSessionId": "ses_abc123",
      "anthropicStatus": "idle",
      "idleMinutes": 62,
      "idleMinutesAvailable": true,
      "enrichment": {
        "sessionId": "sess_ds_7421",
        "slackChannel": "demos",
        "slackThreadTs": "1713620000.001200",
        "userEmail": "dnt@missmp.eu",
        "dbStatus": "in_progress",
        "brand": "Allianz"
      },
      "isOrphan": false,
      "degradedFields": []
    },
    {
      "managedSessionId": "ses_ghi789",
      "anthropicStatus": "idle",
      "idleMinutes": 130,
      "idleMinutesAvailable": true,
      "enrichment": null,
      "isOrphan": true,
      "degradedFields": []
    }
  ],
  "fetchedAt": "2026-04-20T14:32:00Z",
  "cacheAgeSeconds": 4,
  "degradedFields": []
}
```

Orphan rows: `enrichment: null`, `isOrphan: true`.
Cold sessions (Firestore row exists, S2 returns 404): `enrichment.brand: null`, `degradedFields: ["brand"]`. Everything else populated.
S2 5xx on enrichment fetch: same as cold — `enrichment.brand: null`, `degradedFields: ["brand"]`, but log as an error and still render the row.

`insuranceLine` is removed from the response entirely.

`degradedFields` is non-empty when Spike 1 gaps force fallbacks (e.g. `["idleMinutes"]` if the Anthropic idle surface is unavailable for that row).

The `GET /api/managed-sessions` handler must explicitly implement two enrichment fetches per row in parallel:
1. Firestore batch lookup by `managedSessionId` → slack/user/dbStatus.
2. Per-row S2 `config_mgmt_client.fetch_config(sessionId)` (parallel, `asyncio.gather`) → brand. 404 → brand null + degraded. 5xx → brand null + degraded + error log.

Note: the dashboard handler importing `config_mgmt_client` is the **expected** pattern per BD §3.14 (allowed callers) and must NOT be flagged by the grep-gate.

### `POST /api/managed-sessions/{managed_session_id}/terminate`

Request body: `{ "reason": "manual_dashboard" }` (reason is fixed server-side; body reserved for future audit context).

Flow:
1. Call `managed_session_client.stop(managed_session_id)` — same function used by the lifecycle scanner.
2. On Anthropic 2xx or 404: look up Firestore row by `managedSessionId`.
3. If found and current status not terminal: `session_store.transition_status(sessionId, cancelled, cancelReason=manual_dashboard)`.
4. Write audit-log entry (see section 8).
5. Invalidate the list cache (section 6).

Response: `{ "ok": true, "terminated": true, "wasOrphan": false, "dbUpdated": true }`. On Anthropic error, return 502 with `{ "ok": false, "error": "..." }` and do **not** touch Firestore.

## 5. SDK wrapper — `managed_session_client.py`

New file, lifts Anthropic SDK details into one module. Shared between the lifecycle scanner and this dashboard tab.

Exposed surface:

```python
class ManagedSessionClient:
    async def list_active(self) -> list[ManagedSessionSummary]:
        """Paginated Anthropic list, filtered to MANAGED_AGENT_ID. See lifecycle ADR §3 for filter fallback."""

    async def retrieve(self, session_id: str) -> ManagedSessionDetail:
        """Status + lastActivityAt (or computed-from-events fallback)."""

    async def stop(self, session_id: str, *, reason: str = "") -> StopResult:
        """Idempotent. Handles interrupt-before-delete for running. Swallows 404."""
```

`ManagedSessionSummary` and `ManagedSessionDetail` are dataclasses holding the normalized fields — in particular, `idle_minutes: int | None` where `None` signals Spike 1 fallback and drives the `degradedFields` response.

`stop()` is the same extraction called out in the lifecycle ADR §4 — the inline delete at `main.py:2111-2115` gets refactored into this wrapper as part of the same PR. Both ADRs must agree on this module name to avoid a split implementation.

## 6. Caching strategy

In-process async TTL cache, 10-second lease, keyed on the list call (no args). Motivation: the page auto-refreshes and operators click tabs; uncached we would spam `list_active()` on every pageload.

- First request: fetch from Anthropic, store in cache (payload includes the enriched-merged-from-both-sources list), return.
- Subsequent requests within 10s: return cached payload, set `cacheAgeSeconds` in the response body.
- After any terminate action: synchronously invalidate the cache so the next list reflects reality.
- Cache lives inside the FastAPI process. Single-instance assumption from lifecycle ADR §4 carries over.

The cache stores `{anthropic-list} × {firestore-join} × {S2-config-fetch per row}`. A cache miss triggers N parallel S2 fetches; N ≤ 100 in v1. p99 list-latency is now bounded by the slowest S2 fetch, not by Anthropic alone. Acceptable for v1; revisit if S2 latency regresses.

Not cached: `retrieve()` or `stop()`. Only the list.

## 7. Error handling

| Failure | UI behaviour |
| --- | --- |
| Anthropic 5xx on list | Banner: "Anthropic API unavailable — showing last cached view (Xs old)." Rows render from the last good cache if within 5 min; else empty state with retry button. |
| Anthropic 429 (rate limit) | Same banner as 5xx but copy says "rate-limited, retrying in Ns". Respect `Retry-After`. |
| Spike 1 field gap (`idleMinutes` unavailable) | Cell renders `—`, tooltip: "Idle duration not exposed by Anthropic SDK. See lifecycle ADR §3." `degradedFields` flag surfaced via a small pill in the tab header. |
| Terminate 5xx | Toast: "Terminate failed — session unchanged." DB untouched. |
| Terminate 404 (already gone) | Treat as success — row disappears on next refresh. DB still flipped to `cancelled` if it was non-terminal. |
| Firestore write fails after successful Anthropic delete | Log `db_update_failed_post_terminate`, return 200 with `dbUpdated: false`. Operator sees a warning toast; the scanner's Anthropic-as-source-of-truth model keeps cost bounded regardless. |
| S2 unavailable (5xx) on per-row config fetch | Brand cell renders `—`, tooltip: "Config service unavailable — brand unknown." Row's `degradedFields` includes `"brand"`. Tab header pill aggregates degraded rows. Firestore-sourced cells (user, slack, dbStatus) still render normally. |
| S2 404 on per-row config fetch (cold session) | Brand cell renders `—`, tooltip: "Config not yet set." No error logged — this is expected for newly-booted agents before first `set_config`. `degradedFields: ["brand"]`. |

## 8. Security

Terminate is destructive. Mitigations:

- **Confirmation modal required** before every terminate — copy pending (Q1). Modal must show **brand** (from the S2-fetched `enrichment.brand` already supplied by the list call — no re-fetch) + user + idle minutes. When `enrichment.brand` is null (cold session or degraded), modal displays `"Brand: — (config not yet set)"` and keeps the terminate action enabled.
- **Audit log entry** on every terminate attempt. Event `managed_session_terminated_manual` with `{ managedSessionId, actor, dbSessionId?, isOrphan, result, reason, timestamp }`. Logs route through the existing `logger` in `main.py`, no new infra.
- **Actor = `"operator"`** for now — the dashboard has no per-user auth, only Service 1's existing guard. Flagged as a **known gap**: the audit trail cannot attribute a terminate to a specific human until the dashboard has identity. Resolve when dashboard auth lands; tracked outside this ADR.
- **No GET endpoint leaks secrets.** List response contains session IDs, idle time, brand/user metadata — no API keys, no transcripts.
- **Route scoping:** `/api/managed-sessions*` sits behind the same network/edge guard as the rest of `/dashboard`. If the current `/dashboard` is unauthenticated in Cloud Run, this tab inherits that posture — and terminate becomes an anonymous destructive action. Must verify before ship; see Q4.

## 9. Non-goals

- **Cost reporting / per-session cost truth.** Requires an admin API key and the organisation usage endpoint. Separate track.
- **Per-user quotas or rate limits.**
- **Retry / resume of terminated sessions.** Once stopped, stopped.
- **Editing agent config from the dashboard.**
- **Auth / user identity for the dashboard itself.** Flagged as a gap in §8; not solved here.
- **Paging / infinite scroll in v1** — see Q3.
- **Bulk terminate.** One session at a time.
- **Changes to Service 2/3/4/5.**
- **New metrics/observability backend** — reuse existing logger.

## 10. Open questions

**Q1. Confirmation-modal copy.** **DEFERRED (2026-04-20 Duong + Lulu): use single-click-with-modal (no type-to-confirm gate) for v1; revisit at QA if UX deems it insufficient.** The proposed "Type TERMINATE" gate is warranted only for bulk or irreversible multi-step actions; a single-session terminate with a confirmation modal is sufficient for v1.

**Q2. Orphan visibility default.** **LOCKED (2026-04-20 Duong): show by default, tagged.** The dashboard is a debugger for when the scanner fails or lags — orphans must be visible without requiring a filter toggle.

**Q3. Paging vs. infinite scroll.** At <100 concurrent sessions a single list is fine. Threshold for re-evaluation: 250 concurrent. Lean: server-paged cursor, matching Anthropic's own pagination.

**Q4. Dashboard auth posture.** **DEFERRED (2026-04-20 Duong): inherit existing `/dashboard` posture; auth refactor will happen in a separate initiative.** Ship terminate without additional gating for now. Audit log + confirmation modal are the only safeguards in v1.

## 11. Handoff notes

- **Kayn / Aphelios:** decompose into (a) `managed_session_client.py` extraction — coordinate with the lifecycle ADR's decomposition so both ADRs land one module, not two; (b) list endpoint + enrichment join (two-source: Firestore + S2); (c) terminate endpoint + audit log; (d) tab UI + confirmation modal. Spike 1 from the lifecycle ADR gates all of this — same spike serves both ADRs.
- **Seraphine (UI):** tab bar + table + filter + modal. Mockup in §3 is indicative, not prescriptive.
- **Caitlyn / Vi (tests):** (i) `managed_session_client` shared-unit coverage (covered by lifecycle ADR's test plan). (ii) Dashboard route unit: join logic (two-source enrichment), orphan tagging, cache TTL, terminate DB write. (iii) Integration: real Anthropic throwaway session, list + terminate from UI, assert DB flipped and audit log written. (iv) Regression: existing `/dashboard` tab unchanged.
- **Depends on:** `2026-04-20-managed-agent-lifecycle.md` (SDK wrapper + Spike 1). This ADR cannot ship without the wrapper; it may ship before the scanner loop if Spike 1 completes first.

## Test plan

Four layers per ADR §11 handoff (Caitlyn / Vi):

- **I1 — `managed_session_client` shared-unit coverage:** list, retrieve, and stop operations are unit-tested with a stubbed Anthropic SDK; idle-minutes unavailability drives `degradedFields: ["idleMinutes"]` in the response.
- **I2 — Dashboard route unit:** `GET /api/managed-sessions` two-source enrichment join (Firestore lifecycle fields + S2 brand), orphan tagging, 10-second TTL cache behaviour, and terminate DB write are covered with mocked session_store and config_mgmt_client.
- **I3 — Regression: existing Sessions tab unchanged:** a regression test asserts the existing `/dashboard` Sessions tab response shape is byte-identical before and after this PR.
- **I4 — Integration: list and terminate from UI:** real Anthropic throwaway session, list confirmed in the Managed Agents tab, terminate action asserts DB row flipped to `cancelled` and audit-log entry written; S2 stubbed at integration-test boundary.

## Amendments

_Source: `company-os/plans/2026-04-20-managed-agent-dashboard-tab-bd-amendment.md` in `missmp/company-os`. Inlined verbatim._ <!-- orianna: ok — cross-repo reference; file exists at ~/Documents/Work/mmp/workspace/company-os/plans/ -->

**Date:** 2026-04-20 (s3)
**Author:** Sona (coordinator, fastlane edit)
**Scope:** names the sections of `plans/2026-04-20-managed-agent-dashboard-tab.md` that change as a consequence of the §11 resolutions in `plans/2026-04-20-s1-s2-service-boundary.md` (BD ADR).

### 1. Why this amendment exists

The dashboard-tab ADR pre-dates BD §11 (strict resolutions). Its enrichment join reads `brand` and `insuranceLine` from the S1 Firestore session doc. Per BD-1 (strict, no denormalisation), `brand` is **not** on the S1 session doc — it lives only on S2 under `configs/{sessionId}`. Per BD's deletion list, `insuranceLine` is not a field at all in the S2 `DemoConfig` schema and is subject to the grep-gate (BD §2 Rule 4) across `tools/demo-studio-v3/`. <!-- orianna: ok — cross-repo path; tools/demo-studio-v3/ lives in missmp/company-os, not this repo -->

The ADR's core (Anthropic-side control — list/retrieve/terminate — and the `managed_session_client.py` SDK wrapper) is architecturally sound and orthogonal to BD.

### 2. Dashboard-tab ADR sections affected

#### 2.1 §2 Decision #2 — enrichment join

**After:** Enrichment is a **two-source join**, in parallel per row:
- **Firestore `demo-studio-sessions`** (by `managedSessionId`) → `sessionId`, `slackChannel`, `slackThreadTs`, `userEmail` (resolved from `slackUserId`), `dbStatus`. All lifecycle fields per BD-1.
- **S2 `config_mgmt_client.fetch_config(sessionId)`** → `brand`. Only brand. No `insuranceLine` — that field does not exist on S2.

If the Firestore row is missing → `isOrphan: true`, skip both joins.
If the S2 fetch returns 404 (cold session — pre-first `set_config`, per BD §4.1) or 5xx → brand renders `—` and the row's `degradedFields` includes `"brand"`.

#### 2.2 §3 UI columns

**After:** Drop the `InsuranceLine` column entirely (dead field per BD). Remaining column becomes **`Brand`** only, sourced from S2. `—` rendered when brand is in `degradedFields`. `— ORPHAN` still applies when the Firestore row is missing.

Column list net change:
- Remove: `InsuranceLine`.
- Keep (re-sourced): `Brand` (S2 instead of Firestore).
- Unchanged: Managed Session ID, Anthropic Status, Idle, User, DB Status, Slack Thread, Action.

#### 2.3 §4 `GET /api/managed-sessions` response shape

The `firestore` sub-object is renamed to `enrichment` and split into two sub-sources to make provenance explicit (see the response shape in §4 above). `insuranceLine` is removed from the response entirely.

#### 2.4 §7 error-handling table — new rows

Two new rows added (incorporated into §7 above): S2 unavailable (5xx) on per-row config fetch; S2 404 on per-row config fetch (cold session).

#### 2.5 §8 confirmation modal

Brand is sourced from the S2-fetched `enrichment.brand` that the list call already supplied (not a re-fetch, not a Firestore read). When `enrichment.brand` is null (cold session or degraded), modal displays `"Brand: — (config not yet set)"` and keeps the terminate action enabled.

#### 2.6 §5 SDK wrapper — unchanged

`managed_session_client.py` stays exactly as decomposed. It does not call S2; it only talks to Anthropic. The enrichment join lives in the `GET /api/managed-sessions` handler, not in the wrapper. BD-clean.

#### 2.7 §6 caching — payload shape amended

The 10-second TTL cache mechanism is unchanged but its **payload shape** is now the enriched-merged-from-both-sources list (per §2.3). A cache miss triggers N parallel S2 fetches.

### 3. Sections explicitly unchanged

- §1 Context
- §2 decisions #1, #3, #4, #5 (Anthropic list, orphan tag, Terminate action, SDK wrapper reuse)
- §5 SDK wrapper (Anthropic-only, no S2)
- §6 caching mechanism
- §7 existing rows (new rows added in §2.4)
- §9 non-goals
- §10 open questions Q1, Q2, Q3, Q4

### 4. Task decomposition hints for Kayn

When Kayn issues the dashboard-tab task file (`plans/2026-04-20-managed-agent-dashboard-tab-tasks.md`), the `GET /api/managed-sessions` handler task must explicitly list two enrichment fetches in its acceptance criteria:
1. Firestore batch lookup by `managedSessionId` → slack/user/dbStatus.
2. Per-row S2 `config_mgmt_client.fetch_config(sessionId)` (parallel, asyncio.gather) → brand. 404 → brand null + degraded. 5xx → brand null + degraded + error log.

SE.E grep-gate (BD §2 Rule 4) — the dashboard handler importing `config_mgmt_client` is the **expected** pattern per BD §3.14 (allowed callers) and must not be flagged.

No managed-agent-dashboard task should read `session.get("config", …)` from the Firestore doc. The `brand` field does not exist there post-BD.

### 5. OQ resolutions affected

None. Q1, Q2 (locked: show by default), Q3, Q4 (deferred) are all unchanged by BD.

### 6. Sequencing

- Promotes alongside the two other already-approved plans (BD ADR + SE amendment).
- Does **not** block the managed-agent-lifecycle ADR decomposition.
- Kayn's decomposition of the dashboard-tab ADR **must** read this amendment before producing the task file.

### 7. Out-of-scope for this amendment

- No rewrite of the ADR itself.
- No changes to §5 SDK wrapper, §9 non-goals, Q1/Q3/Q4 open questions.
- No new test-plan guidance.
- No decisions about S2 per-row fetch parallelism beyond "use asyncio.gather, bounded concurrency if needed."

### 8. Handoff

- **Duong:** promote this file via the work-concern convention. Then invoke Kayn to decompose the dashboard-tab ADR into tasks, referencing this amendment.
- **Kayn:** decompose the dashboard-tab ADR + this amendment into `plans/2026-04-20-managed-agent-dashboard-tab-tasks.md` on `feat/demo-studio-v3` (worktree).
- **Orianna:** optional fact-check on six load-bearing claims Azir flagged in his BD-consistency scan: `managedSessionId` on S1 doc, `userEmail` resolution S1-owned, `config.brand` schema path on S2, cold-session 404 semantics, `insuranceLine` absent from S2 `DemoConfig`, no existing `/dashboard` read path depending on `session.config`.
- **Camille:** SE.E grep-gate already captures `insuranceLine` literal per BD §2 Rule 4 — no extension needed for this amendment.
