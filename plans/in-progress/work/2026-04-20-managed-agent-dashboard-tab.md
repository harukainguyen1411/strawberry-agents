---
status: in-progress
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
orianna_signature_approved: "sha256:2685a2f5876ac4231bfd949630fbd9b584ca87a909331d1913802efecb782ea7:2026-04-21T05:54:25Z"
orianna_signature_in_progress: "sha256:2685a2f5876ac4231bfd949630fbd9b584ca87a909331d1913802efecb782ea7:2026-04-21T05:58:17Z"
---

# ADR: Managed Agent Control — Dashboard Tab (Demo Studio v3 Service 1)

Date: 2026-04-20
Scope: `company-os/tools/demo-studio-v3` (Service 1 only), `/dashboard` UI. <!-- orianna: ok -->
Related:
- `plans/proposed/work/2026-04-20-managed-agent-lifecycle.md` — automated monitor (idle warn + auto-terminate). Shares the SDK wrapper introduced below. <!-- orianna: ok -->
- `secretary/agents/azir/learnings/2026-04-20-managed-agent-lifecycle-adr.md` — SDK-gap context. <!-- orianna: ok -->

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
5. Reuses `managed_session_client.py` — the same SDK wrapper introduced for the lifecycle scanner. One place owns Anthropic list/retrieve/delete calls. <!-- orianna: ok -->

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
2. Per-row S2 `config_mgmt_client.fetch_config(sessionId)` (parallel, `asyncio.gather`) → brand. 404 → brand null + degraded. 5xx → brand null + degraded + error log. <!-- orianna: ok -->

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

## 5. SDK wrapper — `managed_session_client.py` <!-- orianna: ok -->

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

- **Confirmation modal required** before every terminate — copy pending (Q1). Modal must show **brand** (from the S2-fetched `enrichment.brand` already supplied by the list call — no re-fetch) + user + idle minutes. When `enrichment.brand` is null (cold session or degraded), modal displays `"Brand: — (config not yet set)"` and keeps the terminate action enabled. <!-- orianna: ok -->
- **Audit log entry** on every terminate attempt. Event `managed_session_terminated_manual` with `{ managedSessionId, actor, dbSessionId?, isOrphan, result, reason, timestamp }`. Logs route through the existing `logger` in `main.py`, no new infra. <!-- orianna: ok -->
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

- **Kayn / Aphelios:** decompose into (a) `managed_session_client.py` extraction — coordinate with the lifecycle ADR's decomposition so both ADRs land one module, not two; (b) list endpoint + enrichment join (two-source: Firestore + S2); (c) terminate endpoint + audit log; (d) tab UI + confirmation modal. Spike 1 from the lifecycle ADR gates all of this — same spike serves both ADRs. <!-- orianna: ok -->
- **Seraphine (UI):** tab bar + table + filter + modal. Mockup in §3 is indicative, not prescriptive.
- **Caitlyn / Vi (tests):** (i) `managed_session_client` shared-unit coverage (covered by lifecycle ADR's test plan). (ii) Dashboard route unit: join logic (two-source enrichment), orphan tagging, cache TTL, terminate DB write. (iii) Integration: real Anthropic throwaway session, list + terminate from UI, assert DB flipped and audit log written. (iv) Regression: existing `/dashboard` tab unchanged.
- **Depends on:** `2026-04-20-managed-agent-lifecycle.md` (SDK wrapper + Spike 1). This ADR cannot ship without the wrapper; it may ship before the scanner loop if Spike 1 completes first. <!-- orianna: ok -->

## Test plan

Four layers per ADR §11 handoff (Caitlyn / Vi):

- **I1 — `managed_session_client` shared-unit coverage:** list, retrieve, and stop operations are unit-tested with a stubbed Anthropic SDK; idle-minutes unavailability drives `degradedFields: ["idleMinutes"]` in the response.
- **I2 — Dashboard route unit:** `GET /api/managed-sessions` two-source enrichment join (Firestore lifecycle fields + S2 brand), orphan tagging, 10-second TTL cache behaviour, and terminate DB write are covered with mocked session_store and config_mgmt_client.
- **I3 — Regression: existing Sessions tab unchanged:** a regression test asserts the existing `/dashboard` Sessions tab response shape is byte-identical before and after this PR.
- **I4 — Integration: list and terminate from UI:** real Anthropic throwaway session, list confirmed in the Managed Agents tab, terminate action asserts DB row flipped to `cancelled` and audit-log entry written; S2 stubbed at integration-test boundary.

## Amendments

_Source: `company-os/plans/2026-04-20-managed-agent-dashboard-tab-bd-amendment.md` in `missmp/company-os`. Inlined verbatim._ <!-- orianna: ok — cross-repo reference; file exists at ~/Documents/Work/mmp/workspace/company-os/plans/ --> <!-- orianna: ok -->

**Date:** 2026-04-20 (s3)
**Author:** Sona (coordinator, fastlane edit)
**Scope:** names the sections of `plans/2026-04-20-managed-agent-dashboard-tab.md` <!-- orianna: ok — inlined amendment from company-os; self-ref under company-os plan naming convention --> that change as a consequence of the §11 resolutions in `plans/2026-04-20-s1-s2-service-boundary.md` <!-- orianna: ok — inlined from company-os; plan exists in this repo at plans/proposed/work/ --> (BD ADR). <!-- orianna: ok -->

### 1. Why this amendment exists

The dashboard-tab ADR pre-dates BD §11 (strict resolutions). Its enrichment join reads `brand` and `insuranceLine` from the S1 Firestore session doc. Per BD-1 (strict, no denormalisation), `brand` is **not** on the S1 session doc — it lives only on S2 under `configs/{sessionId}`. Per BD's deletion list, `insuranceLine` is not a field at all in the S2 `DemoConfig` schema and is subject to the grep-gate (BD §2 Rule 4) across `tools/demo-studio-v3/`. <!-- orianna: ok — cross-repo path; tools/demo-studio-v3/ lives in missmp/company-os, not this repo --> <!-- orianna: ok -->

The ADR's core (Anthropic-side control — list/retrieve/terminate — and the `managed_session_client.py` SDK wrapper) is architecturally sound and orthogonal to BD. <!-- orianna: ok -->

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

Brand is sourced from the S2-fetched `enrichment.brand` that the list call already supplied (not a re-fetch, not a Firestore read). When `enrichment.brand` is null (cold session or degraded), modal displays `"Brand: — (config not yet set)"` and keeps the terminate action enabled. <!-- orianna: ok -->

#### 2.6 §5 SDK wrapper — unchanged

`managed_session_client.py` stays exactly as decomposed. It does not call S2; it only talks to Anthropic. The enrichment join lives in the `GET /api/managed-sessions` handler, not in the wrapper. BD-clean. <!-- orianna: ok -->

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

When Kayn issues the dashboard-tab task file (`plans/2026-04-20-managed-agent-dashboard-tab-tasks.md`), the `GET /api/managed-sessions` handler task must explicitly list two enrichment fetches in its acceptance criteria: <!-- orianna: ok -->
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
- **Kayn:** decompose the dashboard-tab ADR + this amendment into `plans/2026-04-20-managed-agent-dashboard-tab-tasks.md` on `feat/demo-studio-v3` (worktree). <!-- orianna: ok -->
- **Orianna:** optional fact-check on six load-bearing claims Azir flagged in his BD-consistency scan: `managedSessionId` on S1 doc, `userEmail` resolution S1-owned, `config.brand` schema path on S2, cold-session 404 semantics, `insuranceLine` absent from S2 `DemoConfig`, no existing `/dashboard` read path depending on `session.config`. <!-- orianna: ok -->
- **Camille:** SE.E grep-gate already captures `insuranceLine` literal per BD §2 Rule 4 — no extension needed for this amendment.

## Tasks

_Source: `company-os/plans/2026-04-20-managed-agent-dashboard-tab-tasks.md` in `missmp/company-os`. Inlined verbatim._ <!-- orianna: ok — cross-repo task file; inlined per §D3 one-plan-one-file rule --> <!-- orianna: ok --> <!-- orianna: ok -->

# Task breakdown — Managed Agent Control: Dashboard Tab (MAD)

Source ADR: `plans/approved/work/2026-04-20-managed-agent-dashboard-tab.md` (including the inlined BD amendment in §Amendments). <!-- orianna: ok --> <!-- orianna: ok -->

Branch: `feat/demo-studio-v3` (company-os worktree at `~/Documents/Work/mmp/workspace/company-os-demo-studio-v3`). Same branch as the lifecycle (MAL) and session-state-encapsulation (SE) breakdowns — all three ADRs share one PR branch per §11 handoff notes. <!-- orianna: ok --> <!-- orianna: ok -->

Task-ID scheme: `MAD.<phase>.<n>`. Phases track ADR §4–§8 surfaces, not UI vs. backend. Every impl task is preceded by an xfail test commit on the same branch per Rule 12.

AI-minute estimates are wall-clock Sonnet-builder time per commit (test commit + impl commit counted separately). Estimates do NOT include Kayn breakdown or Senna review time.

## Cross-ADR dependency map (load-bearing — read first)

Dashboard tab consumes three sibling artefacts. All three sibling ADRs are **still in `plans/proposed/work/`** as of 2026-04-21 (signing in flight by separate Ekko). This breakdown is **not** blocked on their promotion — it is blocked on the **code artefacts** they task, which land on the same `feat/demo-studio-v3` branch: <!-- orianna: ok --> <!-- orianna: ok -->

| Artefact | Source ADR / task | Used by | Hard blocker? |
| --- | --- | --- | --- |
| `managed_session_client.py` (SDK wrapper) with `list_active` / `retrieve` / `stop` | MAL.A.* in `managed-agent-lifecycle-tasks.md` (once MAL breakdown issued) | MAD.B.2 (list handler), MAD.C.2 (terminate handler) | **YES** — cannot start MAD.B/C impl before wrapper exists. MAD can start the UI (MAD.D) + route skeletons in parallel. | <!-- orianna: ok --> <!-- orianna: ok -->
| Spike 1 appendix (Anthropic SDK surface: `idle_minutes`, events-list fallback, filter param) | MAL.0.1 | MAD.B (degradedFields semantics) | **YES** for MAD.B acceptance wording; MAD.B can be scaffolded but not closed until Spike 1 lands. |
| `session_store.transition_status(sessionId, to_status, cancel_reason=…)` | SE.A.6 | MAD.C.2 (terminate handler flips DB row to `cancelled` with `cancelReason: manual_dashboard`) | **YES** for MAD.C impl. MAD.C test (MAD.C.1) can mock it. If SE slips, MAD.C degrades to "call wrapper, skip DB flip, toast warning" per ADR §7 last row. |
| `config_mgmt_client.fetch_config(sessionId) -> DemoConfig` (returns brand only; 404 on cold) | S1↔S2 boundary ADR (BD), client tasked there | MAD.B.2 (per-row S2 enrichment) | **YES** for MAD.B impl. If BD slips, MAD.B.2 stubs the client behind a feature flag and brand always returns `null` with `degradedFields: ["brand"]`. See risk in §Risks. |
| `cancel_reason` kwarg on `transition_status` (OQ-MAL-6) | SE.A.6 signature, MAL-flagged | MAD.C.2 | **YES** — MAD.C task body hard-requires the kwarg. Escalated to Duong below as OQ-MAD-1. |

Grep-gate reminder (BD §2 Rule 4 / SE.E): the dashboard handler importing `config_mgmt_client` is an **allowed caller** per BD §3.14. MAD.E.1 explicitly verifies SE.E's grep-gate does not flag MAD's imports.

---

## Phase summary & estimates

| Phase | Scope | Tasks | AI-min |
| --- | --- | --- | --- |
| MAD.0 | Preflight: confirm shared deps + worktree | 2 | 10 |
| MAD.A | Route scaffolding + cache primitive | 4 (2 xfail + 2 impl) | 70 |
| MAD.B | `GET /api/managed-sessions` + two-source enrichment join | 6 (3 xfail + 3 impl) | 165 |
| MAD.C | `POST /api/managed-sessions/{id}/terminate` + audit log | 4 (2 xfail + 2 impl) | 95 |
| MAD.D | UI: tab bar + table + filter + confirmation modal | 6 (2 test + 4 impl) | 180 |
| MAD.E | Grep-gate allowlist verification + regression guard | 2 (1 test + 1 errand) | 30 |
| MAD.F | Integration test (real Anthropic throwaway) | 2 (1 test + 1 fixture) | 55 |
| MAD.G | Doc / ops follow-ups | 1 | 15 |
| **TOTAL** | | **27** | **620** |

Rough wave diagram (hard serial points marked `→`, parallelisable within wave marked `∥`):

```
Wave 0: MAD.0.1 → MAD.0.2
Wave 1: MAD.A.1 ∥ MAD.A.2  →  MAD.A.3 ∥ MAD.A.4
Wave 2: MAD.B.1  →  MAD.B.2  →  MAD.B.3 ∥ MAD.B.4  →  MAD.B.5  →  MAD.B.6
Wave 3: MAD.C.1  →  MAD.C.2  ∥  MAD.C.3  →  MAD.C.4
Wave 4: MAD.D.1  →  MAD.D.2 ∥ MAD.D.3 ∥ MAD.D.4  →  MAD.D.5  →  MAD.D.6
Wave 5: MAD.E.1  →  MAD.E.2
Wave 6: MAD.F.1  →  MAD.F.2
Wave 7: MAD.G.1
```

MAD.D (UI) can run **in parallel** with MAD.A–C once MAD.A.3 (route skeleton returning a stub payload) lands. MAD.B + MAD.D sync at MAD.D.5 (wire real fetch).

---

## Phase MAD.0 — Preflight

### MAD.0.1 — Confirm shared dependencies landed or stubbed (ERRAND)
- **What:** on `feat/demo-studio-v3`, verify that (a) `tools/demo-studio-v3/managed_session_client.py` exists with the signatures in ADR §5 (`list_active`, `retrieve`, `stop`) OR is staged by an in-flight MAL.A PR; (b) `tools/demo-studio-v3/session_store.py::transition_status` accepts `cancel_reason` kwarg OR OQ-MAD-1 is resolved; (c) `tools/demo-studio-v3/config_mgmt_client.py::fetch_config(sessionId)` exists with 404-on-cold semantics per BD §4.1. <!-- orianna: ok --> <!-- orianna: ok -->
- **Deliverable:** a short status note appended to this task file under "MAD.0.1 result" listing (i) which deps are live, (ii) which are staged in a branch, (iii) which are missing → triggers stub-fallback path in MAD.B.2 / MAD.C.2.
- **Acceptance:** Kayn / Evelynn can read the note and decide whether MAD.B / MAD.C impl starts now or parks behind MAL / SE / BD.
- **Blockers:** none.
- **AI-min:** 5.

### MAD.0.2 — Worktree hygiene (ERRAND)
- **What:** confirm `~/Documents/Work/mmp/workspace/company-os-demo-studio-v3` worktree is checked out on `feat/demo-studio-v3` and is up to date with origin. If absent, `git worktree add` it (raw — company-os has no `safe-checkout.sh`, per Kayn memory). <!-- orianna: ok --> <!-- orianna: ok -->
- **Acceptance:** `git -C ~/Documents/Work/mmp/workspace/company-os-demo-studio-v3 status` is clean on `feat/demo-studio-v3`. <!-- orianna: ok --> <!-- orianna: ok -->
- **Blockers:** none.
- **AI-min:** 5.

---

## Phase MAD.A — Route scaffolding + cache primitive

Scaffolds the two new routes (list + terminate) behind a feature flag `MANAGED_AGENT_DASHBOARD=1` plus the 10-second in-process async TTL cache. No Anthropic / Firestore / S2 calls yet — this phase ships a route that returns a stub payload so MAD.D (UI) can start in parallel.

### MAD.A.1 — xfail: TTL cache primitive (TEST)
- **What:** add `tools/demo-studio-v3/tests/test_async_ttl_cache.py` with tests covering: (i) first call hits underlying async fn; (ii) second call within TTL returns cached value + `cacheAgeSeconds` > 0; (iii) call after TTL re-fetches; (iv) `invalidate()` forces re-fetch next call; (v) concurrent callers during a fetch coalesce to one underlying call (single-flight). <!-- orianna: ok --> <!-- orianna: ok -->
- **Acceptance:** tests import `tools.demo_studio_v3.async_ttl_cache` and xfail with ImportError / AttributeError. Marked `@pytest.mark.xfail(reason="MAD.A.2 not yet implemented", strict=True)`.
- **Commit:** `chore: add xfail tests for async TTL cache primitive (MAD.A.1)`.
- **AI-min:** 15.

### MAD.A.2 — impl: async TTL cache primitive (BUILDER)
- **What:** implement `tools/demo-studio-v3/async_ttl_cache.py`. Small `AsyncTTLCache(ttl_seconds: int)` class with `.get_or_fetch(key, coro_fn)`, `.invalidate(key)`, and per-key single-flight via `asyncio.Lock`. Exposes `cache_age_seconds(key)`. <!-- orianna: ok --> <!-- orianna: ok -->
- **Acceptance:** MAD.A.1 tests pass (drop xfail). No new deps.
- **Commit:** `feat(demo-studio-v3): add async TTL cache primitive (MAD.A.2)`.
- **AI-min:** 20.

### MAD.A.3 — xfail: /api/managed-sessions + /terminate route registration (TEST)
- **What:** add `tests/test_managed_sessions_routes.py`. Tests: (i) `GET /api/managed-sessions` returns 200 with stub shape `{sessions: [], fetchedAt, cacheAgeSeconds, degradedFields: []}` when flag on; (ii) returns 404 when flag off; (iii) `POST /api/managed-sessions/ses_abc/terminate` returns 501 (not implemented yet) when flag on — scaffolds the URL path + method so MAD.D.4 can wire the modal. <!-- orianna: ok --> <!-- orianna: ok -->
- **Acceptance:** xfail on both routes (404/404 vs. 200/501).
- **Commit:** `chore: add xfail tests for /api/managed-sessions route scaffolding (MAD.A.3)`.
- **AI-min:** 15.

### MAD.A.4 — impl: route scaffolding + feature flag (BUILDER)
- **What:** register `GET /api/managed-sessions` and `POST /api/managed-sessions/{managed_session_id}/terminate` in `main.py` behind `os.getenv("MANAGED_AGENT_DASHBOARD") == "1"`. List returns the stub above; terminate returns 501. No business logic yet. <!-- orianna: ok --> <!-- orianna: ok -->
- **Acceptance:** MAD.A.3 tests pass.
- **Commit:** `feat(demo-studio-v3): scaffold managed-sessions routes behind feature flag (MAD.A.4)`.
- **AI-min:** 20.

---

## Phase MAD.B — `GET /api/managed-sessions` with two-source enrichment join

Implements ADR §4 list response + §6 caching + BD amendment §4 acceptance criteria. Hard-requires `managed_session_client` (MAL.A) and `config_mgmt_client` (BD). If either is missing, tasks here stub behind injection-friendly ports (see MAD.B.2 implementation note).

### MAD.B.1 — xfail: list-handler unit — happy path + orphan + cold + degraded (TEST)
- **What:** in `tests/test_managed_sessions_list.py` cover, with `managed_session_client`, `session_store`, and `config_mgmt_client` all mocked: <!-- orianna: ok --> <!-- orianna: ok -->
  1. Happy-path: 3 Anthropic rows, all have Firestore matches, all have S2 brand → response has 3 sessions, `isOrphan: false`, `enrichment.brand` set, `degradedFields: []`, `idleMinutesAvailable: true`. <!-- orianna: ok --> <!-- orianna: ok -->
  2. Orphan: 1 Anthropic row with no Firestore match → `enrichment: null`, `isOrphan: true`; Firestore batch called once; S2 NOT called for that row.
  3. Cold session: Firestore match, S2 returns 404 → `enrichment.brand: null`, `degradedFields: ["brand"]`, no error log.
  4. S2 5xx: Firestore match, S2 raises → `enrichment.brand: null`, `degradedFields: ["brand"]`, error log emitted with key `s2_enrichment_failed`.
  5. Spike 1 fallback: one row has `idle_minutes=None` from the wrapper → response has `idleMinutesAvailable: false`, `idleMinutes: null`, `degradedFields: ["idleMinutes"]` for that row.
  6. Response-level `degradedFields` aggregates the union of per-row `degradedFields` (distinct).
- **Acceptance:** all xfail strict.
- **Commit:** `chore: add xfail tests for managed-sessions list enrichment join (MAD.B.1)`.
- **AI-min:** 30.

### MAD.B.2 — impl: list handler — Anthropic list + two-source enrichment (BUILDER)
- **What:** implement the `GET /api/managed-sessions` handler. Flow per BD amendment §4:
  1. `summaries = await managed_session_client.list_active()`.
  2. `managed_ids = [s.managed_session_id for s in summaries]`.
  3. In parallel via `asyncio.gather`: (a) `fs_rows = session_store.batch_get_by_managed_ids(managed_ids)` — Firestore batch lookup; (b) per-row per-row `config_mgmt_client.fetch_config(sessionId)` for every row whose Firestore match exists (orphans skip both joins). <!-- orianna: ok --> <!-- orianna: ok -->
  4. Merge per ADR §4 response shape. Orphan: `enrichment=null, isOrphan=true`. Cold (S2 404): `enrichment.brand=null`, row-level `degradedFields=["brand"]`, no log. S2 5xx: same but log `s2_enrichment_failed` at error level and still render the row.
  5. `idle_minutes=None` from wrapper → `idleMinutesAvailable: false`, row-level `degradedFields += ["idleMinutes"]`.
  6. Response-level `degradedFields` = union of per-row degraded fields (stable order).
  7. Firestore batch: add `session_store.batch_get_by_managed_ids(list[str]) -> dict[str, SessionDoc | None]` if absent. Part of this task.
- **Implementation notes:**
  - `userEmail` resolution from `slackUserId` reuses whatever lookup already exists for the existing Sessions tab — do NOT introduce a new Slack lookup.
  - Per-row S2 fetches use `asyncio.gather(..., return_exceptions=True)` so one S2 failure does not tank the whole list; exceptions become degraded rows.
  - Allowed-caller note: this handler importing `config_mgmt_client` is on BD §3.14 allowlist. Do NOT suppress the grep-gate — MAD.E.1 adds the handler path to the allowlist explicitly.
- **Acceptance:** MAD.B.1 tests pass. Handler tolerates S2 timeout bounded by existing `config_mgmt_client` default (no new timeout config).
- **Depends on:** MAL.A (`managed_session_client`), BD (`config_mgmt_client`). If MAL.A staged but not merged: use the in-flight branch's module via worktree cherry-pick; otherwise park.
- **Commit:** `feat(demo-studio-v3): GET /api/managed-sessions two-source enrichment join (MAD.B.2)`.
- **AI-min:** 45.

### MAD.B.3 — xfail: 10-second TTL cache integration (TEST)
- **What:** `tests/test_managed_sessions_cache.py`. Tests: (i) two calls within 10s hit Anthropic list once; (ii) second call's response has `cacheAgeSeconds ∈ (0, 10]`; (iii) after 11 simulated seconds, cache expires and Anthropic called again; (iv) `retrieve()` and `stop()` are NOT cached (sanity check via mock call-count). <!-- orianna: ok --> <!-- orianna: ok -->
- **Acceptance:** xfail strict against MAD.B.2 handler (cache not yet wired).
- **Commit:** `chore: add xfail tests for managed-sessions 10s TTL cache (MAD.B.3)`.
- **AI-min:** 15.

### MAD.B.4 — impl: wire TTL cache into list handler (BUILDER)
- **What:** wrap the enriched-merged list call in `AsyncTTLCache(ttl_seconds=10)` keyed on `None` (single entry, no args). Populate `cacheAgeSeconds` in the response body from the cache. Expose a module-level `managed_sessions_list_cache` that MAD.C.2 can `.invalidate()`.
- **Acceptance:** MAD.B.3 tests pass. MAD.B.1 tests still pass.
- **Commit:** `feat(demo-studio-v3): 10s TTL cache for managed-sessions list (MAD.B.4)`.
- **AI-min:** 15.

### MAD.B.5 — xfail: Anthropic 5xx / 429 error-handling (TEST)
- **What:** `tests/test_managed_sessions_errors.py`. Tests per ADR §7 table rows 1–2: <!-- orianna: ok --> <!-- orianna: ok -->
  1. Anthropic 5xx + no prior cache → response is 503 with body `{error: "anthropic_unavailable", lastGoodCacheAgeSeconds: null}`.
  2. Anthropic 5xx + cache < 5min old → response is 200 with cached payload + `degradedFields: ["anthropicList"]` + header `X-Cache-Stale: true`.
  3. Anthropic 429 with `Retry-After: 30` → response is 503 with body carrying `retryAfterSeconds: 30`; metric `anthropic_rate_limited` incremented.
- **Acceptance:** xfail strict.
- **Commit:** `chore: add xfail tests for Anthropic list error-handling (MAD.B.5)`.
- **AI-min:** 20.

### MAD.B.6 — impl: Anthropic 5xx / 429 handling + stale-cache fallback (BUILDER)
- **What:** wrap `managed_session_client.list_active()` in try/except. On 5xx: if cache has a last-good entry ≤ 5min old, return it with `X-Cache-Stale` header + `degradedFields` flag; else 503. On 429: parse `Retry-After`, return 503 with retry hint. Log both at WARN with keys `anthropic_list_5xx` / `anthropic_list_rate_limited`.
- **Acceptance:** MAD.B.5 tests pass.
- **Commit:** `feat(demo-studio-v3): degraded-cache fallback for managed-sessions list (MAD.B.6)`.
- **AI-min:** 25.

---

## Phase MAD.C — `POST /api/managed-sessions/{id}/terminate`

Implements ADR §4 terminate route + §8 audit-log. Hard-requires `managed_session_client.stop` (MAL.A) and `session_store.transition_status` with `cancel_reason` kwarg (SE.A.6 + OQ-MAL-6). <!-- orianna: ok --> <!-- orianna: ok -->

### MAD.C.1 — xfail: terminate endpoint unit coverage (TEST)
- **What:** `tests/test_managed_sessions_terminate.py`. Tests: <!-- orianna: ok --> <!-- orianna: ok -->
  1. Happy path — Firestore row in non-terminal status: wrapper `stop()` called once; `session_store.transition_status(sessionId, "cancelled", cancel_reason="manual_dashboard")` called once; response `{ok: true, terminated: true, wasOrphan: false, dbUpdated: true}`; audit log event `managed_session_terminated_manual` with expected fields; list cache invalidated.
  2. Orphan (no Firestore match): wrapper `stop()` called; `transition_status` NOT called; response `{ok: true, terminated: true, wasOrphan: true, dbUpdated: false}`; audit log event with `isOrphan: true`.
  3. Already-terminal DB row (e.g. `cancelled`): wrapper `stop()` called; `transition_status` NOT called; response `{ok: true, terminated: true, wasOrphan: false, dbUpdated: false}`.
  4. Anthropic 404 on stop (already gone): treated as success per ADR §7 row 5; DB flipped if non-terminal.
  5. Anthropic 5xx on stop: response 502 with `{ok: false, error}`; DB untouched; audit log event with `result: "anthropic_error"`; cache NOT invalidated.
  6. Firestore write fails after successful Anthropic stop: response 200 with `dbUpdated: false`; log `db_update_failed_post_terminate` at WARN.
- **Acceptance:** xfail strict.
- **Commit:** `chore: add xfail tests for terminate endpoint (MAD.C.1)`.
- **AI-min:** 30.

### MAD.C.2 — impl: terminate endpoint (BUILDER)
- **What:** implement the handler per ADR §4 flow 1–5. Audit-log payload:
  ```json
  {
    "event": "managed_session_terminated_manual",
    "managedSessionId": "...",
    "actor": "operator",
    "dbSessionId": "sess_ds_..." ,
    "isOrphan": false,
    "result": "ok" | "anthropic_error" | "db_write_failed",
    "reason": "manual_dashboard",
    "timestamp": "..."
  }
  ```
  Log via the existing `logger` in `main.py` (no new infra). Do NOT invent per-user actor until dashboard auth lands — hard-coded `"operator"` per ADR §8 known-gap. <!-- orianna: ok --> <!-- orianna: ok -->
- **Acceptance:** MAD.C.1 tests pass. `cancel_reason` kwarg on `transition_status` assumed (OQ-MAD-1).
- **Depends on:** MAL.A (`managed_session_client.stop`), SE.A.6 (`transition_status` + `cancel_reason`). <!-- orianna: ok --> <!-- orianna: ok -->
- **Commit:** `feat(demo-studio-v3): POST /api/managed-sessions/{id}/terminate + audit log (MAD.C.2)`.
- **AI-min:** 35.

### MAD.C.3 — xfail: terminate invalidates list cache (TEST)
- **What:** `tests/test_managed_sessions_cache_invalidate_on_terminate.py`. Scenarios: (i) list → 200 cached; terminate OK; next list hits Anthropic again (mock call-count). (ii) terminate fails → cache NOT invalidated. <!-- orianna: ok --> <!-- orianna: ok -->
- **Commit:** `chore: xfail — terminate invalidates list cache (MAD.C.3)`.
- **AI-min:** 10.

### MAD.C.4 — impl: wire cache invalidation into terminate handler (BUILDER)
- **What:** on successful terminate (Anthropic 2xx/404), call `managed_sessions_list_cache.invalidate()`. On Anthropic error, do not invalidate.
- **Acceptance:** MAD.C.3 passes. MAD.C.1 tests still pass.
- **Commit:** `feat(demo-studio-v3): invalidate list cache on successful terminate (MAD.C.4)`.
- **AI-min:** 10.

---

## Phase MAD.D — UI: tab bar, table, filter, confirmation modal

ADR §3 + §8 + BD amendment §2.2. The existing Sessions tab view is untouched — this is additive per ADR §2 last paragraph and §9 non-goal "no changes to existing tab".

UI assumed to be the same Jinja / vanilla-JS stack as the existing `/dashboard` per SE.F.* context (confirm in MAD.D.1). If the existing dashboard is already React-mounted, substitute React components — but do not migrate the Sessions tab.

### MAD.D.1 — ERRAND: confirm UI stack + mockup alignment (ERRAND)
- **What:** open `tools/demo-studio-v3/templates/dashboard.html` (or equivalent). Note the existing tab pattern if any, CSS approach (tokens.css? tailwind? inline?), and JS fetch pattern. Append findings to this task file as "MAD.D.1 result". <!-- orianna: ok --> <!-- orianna: ok -->
- **Acceptance:** finding note documents (i) stack, (ii) whether a tab-bar primitive exists, (iii) existing `fetch()` error-toast pattern to reuse.
- **AI-min:** 15.

### MAD.D.2 — impl: tab-bar + empty "Managed Agents" view (BUILDER)
- **What:** introduce `[Sessions] [Managed Agents]` tab bar. Default tab = Sessions (preserve current landing behaviour). Clicking "Managed Agents" mounts an empty state "Loading…" while MAD.D.5 is wired. Client-side state only — no route split per ADR §3. Existing Sessions tab rendered by existing handler, byte-identical (regression asserted in MAD.E.2).
- **Acceptance:** visual check: tab bar renders; toggling tabs does not reload page; Sessions tab response unchanged on the wire.
- **Commit:** `feat(demo-studio-v3): dashboard tab bar + empty Managed Agents view (MAD.D.2)`.
- **AI-min:** 30.

### MAD.D.3 — impl: table + columns + filter + sort (BUILDER)
- **What:** implement the §3 table: Managed Session ID (click-to-copy full; truncated display), Anthropic Status, Idle (minutes, `—` with tooltip if `idleMinutesAvailable:false`), Brand (`—` on `degradedFields: ["brand"]`, `— ORPHAN` if `isOrphan:true`), User (blank on orphan), DB Status (blank on orphan, drift-flag if `anthropicStatus==terminated` and `dbStatus` non-terminal), Slack Thread (link if `slackThreadTs`), Action (`[Stop]` button). Filter bar: `All | Active | Idle | Orphans` (client-side on cached payload). Sort: default idle duration desc. Orphans visible by default per Q2 (LOCKED).
- **Acceptance:** fed a fixture payload (the MAD.B.1 happy-path + orphan + cold mix), table renders all states correctly. Degraded pill in tab header when `degradedFields` non-empty at response level.
- **Commit:** `feat(demo-studio-v3): managed-sessions table, filters, sort (MAD.D.3)`.
- **AI-min:** 45.

### MAD.D.4 — impl: confirmation modal + terminate button (BUILDER)
- **What:** `[Stop]` opens a single-click-with-modal (Q1 DEFERRED → single-click). Modal shows: session ID, brand (or `"Brand: — (config not yet set)"` when `enrichment.brand` null per ADR §8 + amendment §2.5 — terminate action stays enabled), user, idle minutes. `[Cancel]` / `[Terminate session]` buttons. On confirm: `POST /api/managed-sessions/{id}/terminate`; toast success / failure per ADR §7. Button disabled when `anthropicStatus === "terminated"`. <!-- orianna: ok --> <!-- orianna: ok -->
- **Acceptance:** fixture-driven UI test: modal opens with correct content; confirm triggers POST; success toast + row refresh; failure toast + row unchanged.
- **Commit:** `feat(demo-studio-v3): terminate confirmation modal (MAD.D.4)`.
- **AI-min:** 30.

### MAD.D.5 — impl: wire live fetch + auto-refresh (BUILDER)
- **What:** on Managed Agents tab activation and every 10s thereafter (aligned with the TTL cache so we don't thrash), call `GET /api/managed-sessions`. On 503: render error banner per ADR §7 rows 1–2. On 200 with `X-Cache-Stale: true`: render banner "Anthropic API unavailable — showing last cached view (Xs old)" using `cacheAgeSeconds`. Pause auto-refresh when tab is hidden (document.hidden).
- **Acceptance:** manual check against MAD.A.4 stub returns empty table; once MAD.B.2/B.6 live, real data; auto-refresh pauses when hidden.
- **Commit:** `feat(demo-studio-v3): wire live fetch + 10s auto-refresh for managed-sessions tab (MAD.D.5)`.
- **AI-min:** 25.

### MAD.D.6 — TEST: UI fixture/component test (TEST)
- **What:** if a UI test harness exists (Playwright already used per company-os conventions), add a component-level Playwright test for the tab under `tools/demo-studio-v3/tests/e2e/test_managed_agents_tab.spec.ts` (or closest equivalent) driving the fixture payload through a mocked `GET /api/managed-sessions`. Asserts: orphan row renders with ORPHAN tag; degraded brand renders `—` with tooltip; clicking Stop opens modal with correct brand/user/idle; confirming POSTs and refreshes. If no UI harness exists, park as `# TODO(MAD.D.6)` and flag to Senna. <!-- orianna: ok --> <!-- orianna: ok -->
- **Acceptance:** test green locally. UI-PR Rule 16 reminder: QA agent must run the full Playwright flow with video + screenshot + Figma diff before PR merges — this test is the first-pass fixture, not the Rule 16 gate.
- **Commit:** `test(demo-studio-v3): UI fixture test for managed-agents tab (MAD.D.6)`.
- **AI-min:** 35.

---

## Phase MAD.E — Grep-gate + regression guard

### MAD.E.1 — ERRAND: confirm SE.E grep-gate allowlists MAD handler (ERRAND)
- **What:** run `scripts/grep-gate.sh` (or whatever SE.E.1 produced) against the branch. Confirm the MAD list handler's `from config_mgmt_client import fetch_config` line is **allowed** per BD §3.14 (dashboard handler is an allowed caller). If the gate flags it, amend the allowlist in the gate config — **not** the import — and note the change in MAD.E.1 result. <!-- orianna: ok --> <!-- orianna: ok -->
- **Acceptance:** gate green on the branch with MAD.B.2 merged.
- **Blockers:** SE.E.1 must be merged (grep-gate exists).
- **AI-min:** 15.

### MAD.E.2 — TEST: existing Sessions tab regression (TEST)
- **What:** per ADR §Test plan I3: regression test asserts the existing Sessions tab's `/dashboard` response (rendered HTML or JSON, whichever the existing endpoint serves) is **byte-identical** before/after this PR. Capture a golden fixture in `tests/fixtures/dashboard_sessions_tab_golden.html` with a repeatable seeded session list; compare `resp.content == golden`. <!-- orianna: ok --> <!-- orianna: ok -->
- **Acceptance:** test green. Any intentional change to the Sessions tab is explicitly out of scope — if it triggers, kick back to Sona.
- **Commit:** `test(demo-studio-v3): golden regression for existing Sessions tab (MAD.E.2)`.
- **AI-min:** 15.

---

## Phase MAD.F — Integration test (real Anthropic throwaway session)

Per ADR §Test plan I4.

### MAD.F.1 — TEST: integration fixture + live-anthropic test (TEST)
- **What:** `tests/integration/test_managed_agents_e2e.py` (marker `@pytest.mark.integration`). Flow: <!-- orianna: ok --> <!-- orianna: ok -->
  1. Boot a throwaway Anthropic managed session via the existing test helper (reuse whatever MAL's Spike 1 produced if available).
  2. Call `GET /api/managed-sessions` — assert the session appears.
  3. Call `POST /api/managed-sessions/{id}/terminate`.
  4. Assert Firestore row flipped to `cancelled` with `cancelReason: manual_dashboard` (integration Firestore emulator).
  5. Assert audit-log entry emitted (capture via logger handler).
  6. S2 stubbed at integration boundary — do NOT hit real S2.
- **Acceptance:** test green when run with `INTEGRATION=1`. Gated off default CI run (same convention as existing integration tests).
- **Commit:** `test(demo-studio-v3): integration E2E — managed agents list + terminate (MAD.F.1)`.
- **AI-min:** 40.

### MAD.F.2 — ERRAND: integration test runbook entry (ERRAND)
- **What:** add a line to `tools/demo-studio-v3/README.md` (or the existing integration-test runbook) documenting how to run `MAD.F.1`: required env (`ANTHROPIC_API_KEY` with creator scope, Firestore emulator), teardown (throwaway session is auto-deleted by the test). <!-- orianna: ok --> <!-- orianna: ok -->
- **Commit:** `chore(demo-studio-v3): runbook entry for managed-agents integration test (MAD.F.2)`.
- **AI-min:** 15.

---

## Phase MAD.G — Doc / ops follow-ups

### MAD.G.1 — ERRAND: feature-flag default + rollout note (ERRAND)
- **What:** decide + document default for `MANAGED_AGENT_DASHBOARD` env var across dev / stg / prod. Recommended: `=1` on dev and stg; `=0` on prod until QA sign-off per Rule 16. Add to `tools/demo-studio-v3/README.md` env table. Add to deploy pipeline config if needed (reference deployment-pipeline plan if active). <!-- orianna: ok --> <!-- orianna: ok -->
- **Acceptance:** README updated; Sona signs off on prod default before PR merge.
- **Commit:** `chore(demo-studio-v3): document MANAGED_AGENT_DASHBOARD feature flag (MAD.G.1)`.
- **AI-min:** 15.

---

## Risks & mitigations

1. **Sibling ADR slippage (MAL / SE / BD still in `proposed/`).** Signing is in-flight by a separate Ekko as of 2026-04-21. If any of the three stalls past MAD.A, the affected phases park: <!-- orianna: ok --> <!-- orianna: ok -->
   - **MAL slips** → MAD.B, MAD.C, MAD.F park. MAD.A + MAD.D (skeleton + UI on stub payload) still ship.
   - **SE slips** → MAD.C degrades: handler calls wrapper, skips DB flip, returns `dbUpdated: false` with warning toast. Document as tech-debt for post-SE follow-up. (ADR §7 row 6 already tolerates this.)
   - **BD slips** → MAD.B.2 stubs `config_mgmt_client.fetch_config` to always return 404 behind a second feature flag `MANAGED_AGENT_DASHBOARD_BRAND=1`. All brand cells render `—`. Ship-able with the caveat that the confirmation modal shows `"Brand: — (config not yet set)"` for every row — operationally noisy but not broken.
2. **Single-instance cache assumption.** ADR §6 carries over the lifecycle ADR's single-FastAPI-instance assumption. If Cloud Run auto-scales ≥ 2 replicas before this ships, the cache becomes per-replica — tolerable (worst case 2x Anthropic list calls/window) but call out to Sona.
3. **Dashboard auth gap (ADR §8 known-gap, Q4 DEFERRED).** Terminate is an anonymous destructive action in v1. Audit log records `actor: "operator"` — not attributable. Flagged in PR description; not mitigated here.
4. **Per-row S2 fetch latency.** N ≤ 100 parallel `asyncio.gather` calls per cache miss. Acceptable for v1 per ADR §6. If S2 p99 regresses past ~2s, MAD.B p99 regresses same. Bounded-concurrency semaphore is out of scope per amendment §7. <!-- orianna: ok --> <!-- orianna: ok -->

---

## Open questions (OQ-MAD-*)

### OQ-MAD-1 — `cancel_reason` kwarg on `session_store.transition_status` — RESOLVED (Sona 2026-04-21)
SE.A.6 amended: signature is `transition_status(session_id, new_status, *, cancel_reason: str | None = None)`. Persisted as `cancelReason` on the session doc when set; unchanged when None. Additive — no existing callers affected. See SE ADR §8 decision log.

### OQ-MAD-2 — Stale-cache window for Anthropic-5xx fallback
ADR §7 row 1 says "last good cache if within 5 min". MAD.B.6 takes this literally. Confirm 5 min is the intended ceiling (vs. 10 min, vs. TTL × N). Low-stakes; defaulted to 5 min unless Duong overrides.

### OQ-MAD-3 — UI stack confirmation
MAD.D.1 produces this answer empirically, but if the existing dashboard is mid-migration (SE.F.* touched some of it), UI work may conflict with SE.F. **Recommend:** Kayn / Sona verify `tools/demo-studio-v3/templates/dashboard.html` is not being rewritten by SE.F tasks before MAD.D.2 kicks off. <!-- orianna: ok --> <!-- orianna: ok -->

### OQ-MAD-4 — Existing Sessions tab golden fixture (MAD.E.2)
The golden regression file requires a reproducible seed. If the existing Sessions tab rendering is non-deterministic (e.g. shows `now()`-derived fields), the golden approach fails. **Mitigation:** MAD.E.2 authors should freeze time + seed Firestore before capturing. Flag if either is infeasible.

---

## Semantic gaps found in the ADR during breakdown

1. **OQ-MAD-1 (cancel_reason kwarg) — RESOLVED (Sona 2026-04-21):** SE.A.6 extended with `cancel_reason: str | None = None` kwarg. See OQ-MAD-1 above and SE ADR §8.
2. **Idle-duration cell fallback when `idleMinutesAvailable: false`** — ADR §3 shows `—` in the cell; the degraded-pill in tab header is described; but ADR does not specify whether `Sort: idle desc` should treat `null` idle as first or last. **Choice made in MAD.D.3:** treat `null` as last (i.e. known-idle-longest surfaces on top). Flag for QA sign-off.
3. **Drift flagging on DB Status column** — ADR §3 column list says "Flags drift if `terminated` on Anthropic but not a terminal status in our DB" — visual treatment (red text? icon? tooltip?) not specified. **Choice made in MAD.D.3:** `⚠️` glyph + tooltip "DB out of sync with Anthropic". Flag for QA.
4. **Audit-log `dbSessionId` on orphan** — ADR §8 payload shows `dbSessionId?` (optional). On orphan termination it's absent. Implemented as-written; no ambiguity.
5. **Feature-flag existence** — ADR never names a feature flag. MAD.A.4 introduces `MANAGED_AGENT_DASHBOARD=1` to make the phased rollout to prod auditable and to give MAD.G.1 something to document. Not in scope of the ADR but a best-practice add.
6. **Post-BD grep-gate allowlist entry for the dashboard handler** — BD §3.14 says it's allowed, but SE.E.1 grep-gate config must actually include the allowlist entry. MAD.E.1 closes the loop; flag that SE.E's allowlist file may need an edit in a MAD PR rather than an SE PR if the file lives in SE's scope.

---

## Test plan

Inherits the parent ADR's four-layer test plan (§Test plan I1–I4) and materialises it into concrete task pairs:

- **I1 — `managed_session_client` unit coverage** is owned by the MAL breakdown (MAL.A.*). Not re-tasked here; MAD.B / MAD.C consume the wrapper under mock in their own unit tests.
- **I2 — Dashboard route unit tests:** MAD.B.1 (enrichment join + orphan + cold + degraded), MAD.B.3 (10s TTL cache), MAD.B.5 (Anthropic 5xx/429), MAD.C.1 (terminate flow + audit log), MAD.C.3 (cache invalidation on terminate).
- **I3 — Regression: existing Sessions tab unchanged:** MAD.E.2 (golden byte-compare).
- **I4 — Integration (live Anthropic throwaway + Firestore emulator):** MAD.F.1.
- **UI tests:** MAD.D.6 (fixture-level Playwright component test). Rule 16 (QA full Playwright + Figma diff) is a PR-gate concern, not a task — Sona dispatches a QA agent at PR-open time.

Every impl task (`BUILDER` tier) is preceded on the same branch by an xfail TEST commit per Rule 12. Pairing summary:

| xfail TEST | impl BUILDER |
| --- | --- |
| MAD.A.1 | MAD.A.2 |
| MAD.A.3 | MAD.A.4 |
| MAD.B.1 | MAD.B.2 |
| MAD.B.3 | MAD.B.4 |
| MAD.B.5 | MAD.B.6 |
| MAD.C.1 | MAD.C.2 |
| MAD.C.3 | MAD.C.4 |

MAD.D.* UI tasks are test-paired via MAD.D.6 (single fixture test covering the table + modal; UI TDD is traditionally looser per company-os convention). MAD.E.2 and MAD.F.1 are standalone TEST tasks (no paired impl — they exercise existing code).

---

## Handoff

- **Sona (work coordinator):** dispatch MAD.0.1 + MAD.0.2 first; results gate whether MAD.B/C start now or park. Watch OQ-MAD-1 — needs Duong yes/no before MAD.C.2 merges.
- **Orianna:** no new fact-check hooks in this breakdown. BD amendment's six flagged facts (Azir's scan) are the relevant fact-checks; they are not re-checked here.
- **Kayn follow-ups:** if OQ-MAD-1 resolves YES, amend `plans/proposed/work/2026-04-20-session-state-encapsulation-tasks.md` SE.A.6 body to add `cancel_reason` kwarg before MAD.C.2 dispatch. If NO, amend MAD.C.2 + MAD.C.1 to drop the kwarg and represent cancelReason via a separate `session_store.update_session(sessionId, cancelReason=…)` call. <!-- orianna: ok --> <!-- orianna: ok -->
