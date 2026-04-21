---
status: proposed
orianna_gate_version: 2
complexity: complex
concern: work
owner: Swain
created: 2026-04-21
tags:
  - demo-studio
  - e2e
  - ship
  - integration
  - service-1
  - work
tests_required: true
---

# ADR: Demo Studio v3 — E2E Integration and Ship Gate

<!-- orianna: ok — every bare module name in this plan (session_store.py, managed_session_client.py, managed_session_monitor.py, agent_proxy.py, main.py, config_mgmt_client.py, async_ttl_cache.py, factory_bridge.py, factory_bridge_v2.py, validate_v2.py, preview.py, sample-config.json, session.py, auth.py, dashboard_service.py, phase.py, deploy.sh, Dockerfile, requirements.txt, grep-gate.sh, migrate_session_status.py) is a missmp/company-os file under tools/demo-studio-v3/ — this plan orchestrates existing ADRs for that repo; it does not introduce any strawberry-agents local file under those names -->
<!-- orianna: ok — every HTTP route token (/session/new, /session/{id}/status, /session/{id}/build, /session/{id}/cancel-build, /session/{id}/close, /session/{id}/complete, /session/{id}/preview, /session/{id}/approve, /api/managed-sessions, /api/managed-sessions/{id}/terminate, /dashboard, /sessions, /v1/config, /v1/config/{sessionId}, /v1/schema, /build) is an HTTP path on a Cloud Run service, not a filesystem path -->
<!-- orianna: ok — every collection path (demo-studio-sessions, demo-studio-sessions/{sessionId}/events/{seq}, demo-studio-used-tokens) is a Firestore collection, not a filesystem path -->

## 0. Context

Four sibling ADRs converge on the same branch — `feat/demo-studio-v3` at `company-os/tools/demo-studio-v3/` — and together constitute a shippable end-to-end product. This plan is not a new feature; it is the **integration contract and ship gate** that sequences their landing, defines the E2E narrative that must pass before `MANAGED_AGENT_DASHBOARD` flips to default-on, and specifies rollback.

The four ADRs are:

- **SE** — `plans/proposed/work/2026-04-20-session-state-encapsulation.md` (still `proposed/`; signing in flight). Extracts `session_store.py` as the single Firestore boundary; locks the `SessionStatus` enum to `{configuring, building, built, qc_passed, qc_failed, build_failed, completed, cancelled}`; introduces `transition_status(..., cancel_reason=...)`.
- **BD** — `plans/approved/work/2026-04-20-s1-s2-service-boundary.md` (approved; Orianna-signed). Ejects all config state + translation from S1; enforces "S1 = session lifecycle + agent hosting only"; extends the SE grep-gate.
- **MAL** — `plans/approved/work/2026-04-20-managed-agent-lifecycle.md` (approved). Eager terminal-state teardown via `transition_status` hook + in-process idle scanner; shared `managed_session_client.py` wrapper.
- **MAD** — `plans/approved/work/2026-04-20-managed-agent-dashboard-tab.md` (+ `-tasks.md`) (approved). Second `/dashboard` tab listing live Anthropic managed sessions with two-source enrichment join; per-row terminate action behind a confirmation modal.

Current code state on `feat/demo-studio-v3` (verified 2026-04-21 during plan authoring — see §1.3 for HEAD SHAs): MAD is the furthest along — route scaffolding, `async_ttl_cache.py`, and the Managed Agents tab UI are committed in the local worktree at `~/Documents/Work/mmp/workspace/company-os-mad-xfail` on branch `chore/mad-a1-a3-d6-xfail`. BD deletion work has not started. SE `session_store.py` does not yet exist on the branch. MAL `managed_session_client.py` and `managed_session_monitor.py` do not yet exist on the branch.

Duong's directive for this plan: **"All other services are already available and this is already possible."** The E2E is shippable today in the sense that every external dependency (Anthropic managed agents, S2 `demo-config-mgmt`, S3 `demo-factory-cloud`, slack-relay MCP, Firestore) is live. What is missing is the internal wiring across SE/BD/MAL/MAD, the tests that prove the wiring holds, and the gate that decides the feature flag is ready to flip.

This ADR does not re-decide anything the four sibling ADRs already decided. It only orchestrates.

### 0.1 What this plan is NOT

- **NOT** a rewrite or amendment of any of the four sibling ADRs. Where the sequencing in §1 diverges from a sibling's internal phasing, the sibling's phasing wins and this plan follows.
- **NOT** a task decomposition. Task files for SE, MAL, MAD already exist; BD tasks are Kayn's to produce on the same branch. This plan operates one level above them.
- **NOT** new scope. Nothing here introduces a service, a schema field, or an HTTP route that the four sibling ADRs don't already introduce.
- **NOT** a fifth service. S5 (preview iframe) remains out of scope per BD OQ-BD-3 resolution.

## 1. Live state inspection (2026-04-21)

### 1.1 Repo HEAD SHAs at plan authoring

| Repo / worktree | Branch | HEAD SHA | Status |
|---|---|---|---|
| `company-os/` | `feat/demo-studio-v3` | `13fc893` | clean; "chore: promote lifecycle BD amendment to approved" |
| `company-os-mad-xfail/` (worktree) | `chore/mad-a1-a3-d6-xfail` | `1de8549` | MAD.A.1/A.2/A.3/A.4 + MAD.D.1-D.6 committed; `test-results.json` + `test-run-history.json` dirty |
| `api/` | `main` | `4056ac9` | clean |
| `mcps/` | `ws-mcp-param-type-guards` | `4ccf08d` | unrelated branch; slack-relay MCP already in place |
| `ops/` | `main` | `854445c` | unrelated work |

### 1.2 Sub-repos touched by the E2E flow

- **`company-os/tools/demo-studio-v3/`** — S1. Owns all changes in this plan. Single Cloud Run service `demo-studio` per `deploy.sh`.
- **`company-os/tools/demo-config-mgmt/`** — S2. No code changes required; S1's `config_mgmt_client.fetch_config(sessionId)` hits it. Already deployed at `https://demo-config-mgmt-4nvufhmjiq-ew.a.run.app` per S1's `deploy.sh` env wire.
- **`company-os/tools/demo-factory-cloud/`** — S3. No code changes required; S1's new `trigger_factory` is a thin `POST /build {sessionId}` per BD §5.3. Already deployed at `https://demo-factory-4nvufhmjiq-ew.a.run.app`.
- **`company-os/tools/demo-studio-mcp/`** — MCP server. No code changes; already targets S2 directly per its existing tool definitions.
- **`company-os/tools/demo-preview/`** — S5. Out of scope per BD OQ-BD-3. This plan does not migrate the preview route away from S1 — that handoff is tracked separately (see OQ-SHIP-4).
- **`mcps/slack-relay/`** — slack-relay MCP, already live; MAL scanner posts to `#demo-studio-alerts` via it.

### 1.3 Pre-existing MAD work on the worktree

Committed on `chore/mad-a1-a3-d6-xfail` (base: `feat/demo-studio-v3@13fc893`):

```
1de8549 test(demo-studio-v3): remove xfail markers from MAD.D.6 — all 5 tests green
5d3d985 feat(demo-studio-v3): Managed Agents tab UI — MAD.D.1–D.5
fc2b9c7 feat(demo-studio-v3): scaffold managed-sessions routes behind feature flag (MAD.A.4)
0658933 feat(demo-studio-v3): add async TTL cache primitive (MAD.A.2)
620e0a4 chore: add xfail UI fixture test for managed-agents tab (MAD.D.6)
7935294 chore: add xfail tests for /api/managed-sessions route scaffolding (MAD.A.3)
d577231 chore: add xfail tests for async TTL cache primitive (MAD.A.1)
```

MAD.B (list handler + two-source enrichment) and MAD.C (terminate handler) are **not started** on this worktree. They are blocked on `managed_session_client` (MAL.A) and `session_store.transition_status(..., cancel_reason=...)` (SE.A.6). This plan sequences the unblock.

## 2. Integration DAG

The scope of changes spans four ADRs. The dependency graph below names every load-bearing inter-ADR artefact and the phase it lands in. Within a single ADR, the ADR's own task file owns ordering; this DAG only orders **across** ADRs.

```
                            ┌─────────────────────────────────────────┐
                            │                                         │
                            ▼                                         │
SE.0 (audit) ── SE.A.1-A.2 (scaffold + dataclass) ── SE.A.4/A.4b ──► SE.A.5-A.6 ──► SE.A.7-A.8 ──► SE.B.2 ──► SE.B.4 ──► SE.C ──► SE.D ──► SE.E
                     │                                     │                                                     │
                     │                                     │                                                     │
                     │                                     └────► MAL.B.2 (terminal hook)                       │
                     │                                     └────► MAD.C.2 (terminate calls transition_status)   │
                     │                                                                                          │
                     │                                                                                          │
                     ▼                                                                                          │
                  BD.delete-from-S1 (17 sites, per BD §3.14)                                                    │
                     │                                                                                          │
                     ├──► BD.retain (fetch_schema, fetch_config kept) ──► MAD.B.2 two-source enrichment         │
                     │                                                                                          │
                     └──► BD Rule 4 grep-gate patterns ──► SE.E.2 (engine) ◄──── MAD.E.1 (allowlist delta)      │
                                                                                                                │
                                                                                                                │
MAL.0.1 (SDK spike) ──► MAL.A.1-A.4 (stop_managed_session + wrapper) ──► MAL.C.2, MAL.C.3 (refactor cancel/close)
                                │
                                ├──► MAL.B.1-B.2 (terminal-state hook; requires SE.A.6)
                                │
                                └──► MAL.D.1-D.4 (scanner; requires MAL.0.1 spike outcome + SE.A.6 for DB flip)
                                                                        │
                                                                        └──► MAL.E/F/G (slack, startup wiring, config)
                                                                                                                │
MAD.A.1-A.4 (route scaffold + cache) ◄────── ALREADY COMMITTED ON WORKTREE (2026-04-21)                         │
     │                                                                                                          │
     └──► MAD.B.1-B.6 (list + enrichment + cache + error handling)                                              │
              │                                                                                                 │
              └──► MAD.C.1-C.4 (terminate + audit log + cache invalidate; requires MAL.A + SE.A.6)              │
                       │                                                                                        │
                       └──► MAD.D.1-D.6 (UI — partly committed) ──► MAD.E (grep-gate verify, regression) ──► MAD.F (integration E2E)
                                                                                                                │
                                                                                                                │
SHIP GATE (§4) ◄────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Hard serial points across ADRs

1. **SE.A.6 gates MAL.B.2 and MAD.C.2.** Both require `transition_status` with the `cancel_reason` kwarg. SE must ship A.1–A.6 before either consumer can close.
2. **MAL.0.1 (Spike 1) gates MAL.A.3, MAL.A.4, MAL.D.1–D.4 and MAD.B (degradedFields wording).** The spike outcome (a/b/c paths for idle-timestamp resolution) also conditionally gates SE.A.4 — if path (c) wins, SE.A.4 Session dataclass appends `lastActivityAt` per MAL BD-amendment §2.4.
3. **MAL.A.2 gates MAD.B.2, MAD.C.2, MAL.C.2, MAL.C.3.** The wrapper is the single entry-point for all Anthropic session calls in this ADR cluster.
4. **BD delete-from-S1 must land inside SE.A.4 (session-creation writes) and before SE.B.2 / SE.B.4 (call-site migrations).** Per BD §7 sequencing table. Any site that reads `session.get("config", …)` must see the post-BD shape at migration time, otherwise SE.B produces a two-migration rebase storm.
5. **SE.E.2 engine lands with SE. MAD.E.1 adds the MAD row to the allowlist atomically with MAD.B.2.** Per `assessments/advisory/2026-04-21-mad-grep-gate-allowlist-advisory.md` §1: the allowlist row ships in the MAD PR, not SE.
6. **MAD.D (UI) can run in parallel with everything after MAD.A.3.** Already partly committed on the worktree. The UI wires live data at MAD.D.5 only once MAD.B.2 / B.4 / B.6 land.

### 2.2 Recommended landing order

Strictly ordered by earliest-mergeable-without-breaking-main. Each row is independently mergeable (revertible) from main.

| Wave | Content | Depends on (prior wave) |
|---|---|---|
| **W0** | MAL.0.1 spike appendix committed; MAD.0.1 / MAD.0.2 errands done; SE.0.1 / SE.0.2 audit | — |
| **W1** | SE.A.1 → SE.A.6 (session_store scaffold + dataclasses + create/get/update/transition_status) | W0 |
| **W2** | BD delete-from-S1 Wave A: `sample-config.json`, `validate_v2.py`, `preview.py` + `/session/{id}/preview` route, `patch_config` fn (removable-without-call-site-change items) | W1 (not strictly required but avoids rebase) |
| **W3** | SE.A.7 → SE.A.8 (list_sessions); MAL.A.1 → MAL.A.4 (stop_managed_session + wrapper); MAL.C.1 → MAL.C.3 (refactor /cancel-build, /close to use wrapper) | W1 |
| **W4** | SE.B.2 (main.py call-site migration) AND BD delete-from-S1 Wave B (main.py create-session paths, session_page/chat/history brand fetches refactored to S2) — **single coordinated PR** | W1, W2, W3 |
| **W5** | SE.B.4 (factory_bridge*.py migration) AND BD delete-from-S1 Wave C (map_config_to_factory_params, _build_content_from_config, prepare_demo_dict deleted) — **single coordinated PR** | W4 |
| **W6** | MAL.B.1 → MAL.B.2 (terminal-state hook inside transition_status); MAL.D.1 → MAL.D.4 (scanner class + scan_once); MAL.E.1 → MAL.E.3 (slack messaging); MAL.F.1 → MAL.F.2 (startup/shutdown wiring); MAL.G.1 → MAL.G.2 (config plumbing) | W3 + W1 |
| **W7** | MAD.B.1 → MAD.B.6 (list handler + two-source enrichment + 10s TTL + Anthropic error handling); MAD.C.1 → MAD.C.4 (terminate + audit + cache invalidate); MAD.D.5 wires live fetch | W3 (MAL.A), W4 (BD fetch_config path), W1 (SE.A.6) |
| **W8** | SE.C (status-enum migration script + backfill); SE.D (auth tokens to in-process TTL); SE.E.2 grep-gate engine; MAD.E.1 allowlist row; MAD.E.2 regression | W7 |
| **W9** | MAL.H.1 / MAL.H.2 (observability + integration test); MAD.F.1 / MAD.F.2 (integration E2E); MAD.G.1 (runbook doc) | W6, W7 |
| **W10** | **Ship gate §4** — flip `MANAGED_AGENT_DASHBOARD=1` as default in deploy.sh | W9 |

Waves W2 and W6+W7 may be executed in parallel provided the worktree-checkout rule holds (single branch `feat/demo-studio-v3`; serialised merges via CI).

## 3. E2E narrative

The shippable E2E is one continuous user journey, traced across SE/BD/MAL/MAD once all ten waves merge. Each bullet labels the ADR surface it exercises.

### 3.1 Happy path

1. **Session creation.** User (Duong, via the Slack `/demo` command) posts `brand=Allianz, market=DE, languages=[de, en]` to the demo-studio Slack entry point.
   - Service 1 `POST /session/new` — SE-aligned: writes a bare lifecycle doc to `demo-studio-sessions` via `session_store.create_session(slack_user_id, slack_channel, slack_thread_ts)`. **No `config`, no `configVersion`, no `brand`/`market`/`languages`/`shortcode` on the session doc** (BD Rule 1).
   - S1 boots an Anthropic managed agent via `agent_proxy.create_managed_session`; seeds it with identity fields as agent-init metadata (BD §5.1). The `managedSessionId` is written back to the session doc via `session_store.update_session`.
   - S1 does **not** `POST /v1/config` at this point (BD OQ-BD-5 resolution (c)). S2 has no config for this session until the agent's first `set_config` MCP call lands.

2. **Agent configures via MCP.** The managed agent calls `set_config` → S2 `POST /v1/config` directly via the `demo-studio-mcp` server. S1 is not in this path. S2 writes `configs/{sessionId}` version 1.

3. **Build trigger.** User approves; UI posts `POST /session/{id}/build`.
   - S1 handler: `session_store.transition_status(sessionId, "building")` (CAS enforced per SE §4.3). Then a thin `POST /build {sessionId}` to S3 per BD §5.3. **No translation, no `map_config_to_factory_params`, no `configVersion` pin** (BD §3.3/§3.4). S3 fetches config from S2 itself.
   - `factoryRunId` returned by S3, persisted via `session_store.update_session(factoryRunId=...)`.

4. **Build completes; QC runs.** S3 calls back (existing SSE path). On success: `session_store.transition_status(sessionId, "built")` → `transition_status(sessionId, "qc_passed")` → `transition_status(sessionId, "completed")` (SE §4.3 chain).
   - **MAL terminal-state hook fires** (ADR §2.1) on the `completed` transition: `await agent_proxy.stop_managed_session(managedSessionId, reason="transition_to_completed")` — with the 5s timeout per MAL.A.4, inside `session_store.transition_status` post-commit.
   - Anthropic session deleted eagerly. Cost bounded.

5. **Dashboard visibility.** Operator opens `/dashboard`, clicks the Managed Agents tab.
   - `GET /api/managed-sessions` (MAD route). `managed_session_client.list_active()` hits Anthropic. For each returned row, `asyncio.gather` of (a) `session_store.batch_get_by_managed_ids` (lifecycle enrichment: slackChannel, slackUserId, dbStatus), (b) `config_mgmt_client.fetch_config(sessionId)` (S2 enrichment: brand only). Orphan rows (no Firestore match) render with `— ORPHAN`; cold rows (S2 404) render `—` with tooltip.
   - Response is cached 10s via `async_ttl_cache`. Auto-refresh polls every 10s while tab is visible.

6. **Idle scanner kicks in (for long-running sessions).** A long-running session (user started it, forgot to close it) trips the MAL scanner's 60min warn threshold → one slack warning to `#demo-studio-alerts` (MAL §5). At 120min idle → `agent_proxy.stop_managed_session` + `session_store.transition_status(sessionId, "cancelled", cancel_reason="idle_timeout")`.

7. **Manual terminate via dashboard.** Operator spots a drift / orphan / long-idle row that the scanner hasn't caught yet. Clicks `[Stop]` on the row → confirmation modal shows `brand`, user, idle minutes. Confirm → `POST /api/managed-sessions/{id}/terminate`.
   - Handler: `managed_session_client.stop()`, then `session_store.transition_status(sessionId, "cancelled", cancel_reason="manual_dashboard")` if matched. Audit-log event `managed_session_terminated_manual` emitted. List cache invalidated. UI row disappears on next refresh.

### 3.2 Degraded paths exercised by the E2E

- **Cold session dashboard.** User has just opened a session but the agent hasn't run `set_config` yet. MAD tab shows the row with `Brand: —` + "config not yet set" tooltip. Terminate action still enabled (MAD §8, as amended).
- **S2 5xx on dashboard enrichment.** MAD list handler logs `s2_enrichment_failed`, renders `Brand: —` + degradation pill in tab header. Row stays terminable.
- **Anthropic 5xx on list.** MAD falls back to stale cache ≤ 5min with `X-Cache-Stale: true` banner (MAD §7).
- **Terminal-hook failure.** MAL terminal-state hook exception is swallowed post-commit; scanner catches the session on the next cycle (MAL §2.2). No user-facing impact.
- **Scanner can't resolve idle timestamp.** If MAL.0.1 spike lands on path (c), SSE event handler maintains `lastActivityAt` per MAL BD-amendment §2.4 pre-conditions; scanner reads it from the session doc.

### 3.3 Not covered by this E2E (explicit non-path)

- Preview rendering — lives on S5 per BD OQ-BD-3. The `/session/{id}/preview` S1 route deletes in BD Wave A (W2).
- Approve flow — deleted per SE §1.3 table; no `approved` state post-enum-migration.
- Cost reporting / admin-API-key queries — MAD ADR §9 non-goal.

## 4. Ship gate

`MANAGED_AGENT_DASHBOARD=1` must be the **default** in `company-os/tools/demo-studio-v3/deploy.sh` before a release is cut. The flag ships default-off until this gate is green.

### 4.1 Per-service green-check list

All items must be green on `feat/demo-studio-v3@HEAD` before flipping the flag. Each is owned by the corresponding ADR's task file; this plan only enumerates.

**S1 — `demo-studio` Cloud Run service:**

- [ ] SE.A unit tests all pass (dataclasses, create/get/update/transition_status, list_sessions).
- [ ] SE.B migration tests all pass (every `main.py` / `auth.py` / `factory_bridge*.py` / `dashboard_service.py` call-site rewired through `session_store`; old `session.py` deleted or re-export-only).
- [ ] SE.C migration script dry-run report shows zero heuristic-unresolved rows on the current `demo-studio-sessions` collection snapshot (or all unresolved rows are explicitly hand-walked and documented in the deploy runbook).
- [ ] SE.E.2 grep-gate green on the branch: no `from google.cloud import firestore` outside `session_store.py` (one `# azir: boundary` exception); no `session\[?["\']config["\']\]?\s*=` assignments outside tests/migrations; no literal `insuranceLine` anywhere under `tools/demo-studio-v3/`; no `from config_mgmt_client import fetch_config` outside the MAD allowlist + existing S1 callers.
- [ ] BD delete-from-S1 complete: `sample-config.json`, `validate_v2.py`, `preview.py`, `map_config_to_factory_params`, `_build_content_from_config`, `prepare_demo_dict`, `patch_config` all absent. Pre-existing test `tests/test_no_local_validation.py` passes without skip.
- [ ] MAL unit tests all pass (stop_managed_session idempotency, ManagedSessionMonitor decision matrix, Slack enrichment two-source join, MonitorConfig invariant).
- [ ] MAL.0.1 spike appendix exists and documents idle-timestamp resolution (path a/b/c).
- [ ] MAL.0.2 confirms `#demo-studio-alerts` + slack-relay bot membership, or fallback channel committed to `SLACK_ALERT_CHANNEL` default.
- [ ] MAD unit tests all pass (list handler happy/orphan/cold/degraded, terminate handler 6 scenarios, cache behaviour, Anthropic error handling).
- [ ] MAD.E.2 golden-regression test for existing Sessions tab: response bytes identical before/after.
- [ ] Pre-commit hook (`scripts/install-hooks.sh`) installed on every contributor's worktree; pre-push TDD gate shows zero bypass attempts for the branch.

**Integration (live-service) gates:**

- [ ] MAL.H.2 integration test passes locally with a real `ANTHROPIC_API_KEY`: throwaway managed session created → stop → retrieve returns terminated/404.
- [ ] MAD.F.1 integration E2E passes locally: throwaway managed session visible in the list; terminate flips Firestore emulator row to `cancelled` with `cancelReason=manual_dashboard`; audit-log entry captured.
- [ ] New E2E smoke (§5) passes against staging.

**CI gates:**

- [ ] `tdd-gate.yml` green — every impl commit on the branch preceded by an xfail test commit.
- [ ] `e2e.yml` green — Playwright smoke on stg includes the MAD tab path.
- [ ] Pre-merge Senna (code) + Lucian (plan-fidelity) reviews approved.

### 4.2 Release criteria

A single release PR from `feat/demo-studio-v3` → `main` once the §4.1 list is green. The release PR body must link:

1. The MAL.0.1 spike appendix.
2. The SE.C migration dry-run report.
3. The MAD integration test output.
4. The E2E smoke report (§5).
5. All four ADR paths (SE, BD, MAL, MAD).

Per CLAUDE.md Rule 18, merge requires one distinct-identity review + all checks green. No `--admin` bypass.

### 4.3 Flag-flip commit

After the release PR merges, a **separate** follow-up PR flips `MANAGED_AGENT_DASHBOARD=1` in `deploy.sh` (or the equivalent Cloud Run env var in the `set-env-vars` line). This is a one-line change. Wave W10.

This keeps the PR that deploys the code atom-ically separable from the PR that exposes it to operators — if the deploy smoke surfaces a hidden regression, reverting the flag-flip leaves the code in place for triage.

## 5. E2E smoke test surface

Runs on stg after every deploy that touches `feat/demo-studio-v3`; required for prod flip per CLAUDE.md Rule 17.

Smoke script lives under `company-os/tools/demo-studio-v3/tests/smoke/test_e2e_ship.py` (added by this plan's implementers, owner TBD by Evelynn). Not a pytest-marker on the existing suite — a standalone script runnable via `python tests/smoke/test_e2e_ship.py --env=stg`.

### 5.1 Scenarios

Each scenario is ~30–60s wall-clock against stg. The smoke creates real managed sessions — it runs on stg where cost is bounded, not on prod.

| # | Scenario | Asserts |
|---|---|---|
| S1 | Create session | `POST /session/new` returns 200; Firestore row exists with lifecycle-only fields (no `brand`/`config`/`configVersion`); `managedSessionId` set; no S2 doc for sessionId (cold). |
| S2 | Agent first set_config | Via MCP tool directly (bypass S1). S2 `GET /v1/config/{sessionId}` returns version 1 with brand populated. |
| S3 | Dashboard visibility, cold | `GET /api/managed-sessions` (flag-on, auth as operator) shows the session; `enrichment.brand: null`; `degradedFields: ["brand"]`; row renders in UI (check via Playwright snapshot). |
| S4 | Dashboard visibility, warm | After S2, repeat S3; `enrichment.brand: "Allianz"`; `degradedFields: []`. |
| S5 | Build | `POST /session/{id}/build` returns 200; S3 receives `{sessionId}` only (no translated payload — asserted via S3 request log); `factoryRunId` set on session doc. |
| S6 | Completion path | Wait for build → built → qc_passed → completed (or simulate via status-transition harness). Assert MAL terminal hook fires: Anthropic session returns 404 on retrieve within 10s of `completed` transition. |
| S7 | Orphan detect + terminate | Create a second managed session out-of-band (no Firestore row). Dashboard shows it as `— ORPHAN`. `[Stop]` → Anthropic session terminated; no Firestore write attempted; audit log has `isOrphan: true`. |
| S8 | Idle scanner warn path | Create a session; patch the Anthropic idle surface to return 61min (test-only hook). Scanner next cycle posts slack warning to `#demo-studio-alerts` (or fallback). Assert slack-relay receives the post. |
| S9 | Anthropic 5xx fallback | Stub Anthropic list to 5xx; cached response still returned; banner rendered; status-500 never reaches UI. |
| S10 | Regression: existing Sessions tab | Compare `/dashboard` Sessions-tab response bytes against golden fixture committed in MAD.E.2. |

### 5.2 Prod smoke

S1, S3, S4, S5, S6 only (no S2 MCP call, no S7 orphan injection, no S8 scanner patch). On prod-smoke failure, `scripts/deploy/rollback.sh` auto-invokes per CLAUDE.md Rule 17.

## 6. Deployment sequencing

S1 is a single Cloud Run service (`demo-studio`, project `mmpt-233505`, region `europe-west1`) deployed via `company-os/tools/demo-studio-v3/deploy.sh`. S2/S3/S4/S5 are already deployed and unchanged.

### 6.1 Deploy order

Only one service deploys: `demo-studio`. A single `gcloud run deploy` per wave-boundary commit on `main`.

| Wave on main | Deploy? | Reason |
|---|---|---|
| W1 (SE.A) | Yes | `session_store` is additive; old `session.py` still serves traffic; safe to canary. |
| W2 (BD Wave A: passive deletes) | Yes | `sample-config.json`, `validate_v2.py`, `preview.py`, `patch_config` have no runtime callers; `/preview` route returns 410 (see OQ-SHIP-4 for handoff to S5). |
| W3 (MAL.A + SE.A.8 + MAL.C refactor) | Yes | wrapper + refactored routes are internal; no external surface change. |
| W4 (SE.B.2 + BD main.py sites) | **Canary** | first user-facing change. Deploy with `--no-traffic` + 10% traffic split for 1h smoke before 100%. |
| W5 (SE.B.4 + BD factory_bridge) | **Canary** | factory path changes from translated to thin pass-through. Requires S3 team confirmation that S3 self-fetch is live (OQ-SHIP-2). 10% traffic split for 2h. |
| W6 (MAL full) | Yes | scanner starts with `MANAGED_SESSION_MONITOR_ENABLED=true` as default. Kill-switch `false` available as env flip without redeploy if regression. |
| W7 (MAD full) | Yes | routes behind `MANAGED_AGENT_DASHBOARD=0` (default-off); invisible to operators. |
| W8 (SE.C + SE.D + grep-gate) | Yes | SE.C migration script runs **once** against the `demo-studio-sessions` collection, outside the Cloud Run deploy. Coordinate with Heimerdinger: run on staging first, dry-run, then prod. SE.D flips token storage; backward-compatible (old tokens in Firestore continue to work until TTL expires, new tokens go to in-process cache). |
| W9 (observability + integration) | Yes | test-only; no runtime change. |
| W10 (flag flip) | Yes | one-line env-var change; `gcloud run services update demo-studio --update-env-vars MANAGED_AGENT_DASHBOARD=1` is the flip mechanism, not a source change. |

### 6.2 Single-instance assumption

MAL §4 and MAD §6 both assume Cloud Run is pinned to `--min-instances=1 --max-instances=1`. Current `deploy.sh` does not set these flags explicitly (they default to Cloud Run's `min=0, max=100`). **This is a gap** and is raised as OQ-SHIP-1.

### 6.3 Env-var changes in deploy.sh

The current `deploy.sh --set-env-vars` list contains 12 entries. This plan adds:

```
IDLE_WARN_MINUTES=60,
IDLE_TERMINATE_MINUTES=120,
SCAN_INTERVAL_SECONDS=300,
SLACK_ALERT_CHANNEL=demo-studio-alerts,
MANAGED_SESSION_MONITOR_ENABLED=true,
MANAGED_AGENT_DASHBOARD=0,  <!-- orianna: ok — env var name; flipped to 1 in W10 -->
```

`CONFIG_MGMT_URL`, `FACTORY_URL`, `PREVIEW_URL`, `VERIFICATION_URL`, `WALLET_STUDIO_BASE_URL` — all already present. No new secrets; `CONFIG_MGMT_TOKEN` is already bound via `secrets-mapping.txt`.

## 7. Data migration + backfill coordination

Two migrations converge. They must run in a specific order.

### 7.1 SE.C — status-enum migration

Owner: SE task file. Script: `company-os/tools/demo-studio-v3/scripts/migrate_session_status.py`.

- Reads every doc in `demo-studio-sessions`.
- Applies the SE §4.2 mapping: `approved` → `configuring`, `complete` → `completed`, `failed` → `build_failed`, `archived`+`outputUrls` → `completed`|`cancelled` per heuristic.
- Idempotent on re-run.
- Dry-run mode first; production run logged + report committed under `company-os/tools/demo-studio-v3/docs/session-store-audit.md`.

### 7.2 BD — legacy-config orphan

Per BD §8.1, recommendation B (orphan). **No backfill of embedded `config` to S2.**

- Pre-deploy query: `count(*) from demo-studio-sessions where status in ('configuring', 'building')`.
- Expected count: single digits given current traffic (verify with Heimerdinger / ops at time-of-deploy).
- Each user with an in-flight session is hand-walked (Slack ping: "restart your session, this one's tombstoned").
- After deploy, embedded `config` fields are dead data — the grep gate prevents new reads, the doc write-allowlist prevents new writes. Field cleanup is deferred indefinitely (harmless in Firestore; no cost pressure).

### 7.3 Migration order

1. **Before W4 deploy:** run `migrate_session_status.py --dry-run` on staging. Review report.
2. **Between W4 deploy and W5 deploy:** run `migrate_session_status.py` on staging. Smoke.
3. **Before W4 prod deploy:** run `migrate_session_status.py --dry-run` on prod. Review report.
4. **During W4 prod deploy window:** Slack-hand-walk active sessions per §7.2; run `migrate_session_status.py` on prod immediately after canary flips to 100%.

### 7.4 Coordination with other ADRs

- **MAL terminal-hook set** includes `completed` and `cancelled` — both are in the SE.C-migrated enum. MAL.B.2 must NOT deploy against a collection where docs still have pre-SE.C status values (`complete`, `failed`, `archived`); the terminal-hook check is a set-membership test, and pre-migration values would not trigger the hook. This is why §6.1 sequences SE.C in W8, after MAL is live — the hook is effectively disabled on legacy-status rows for the one deploy where MAL landed but SE.C hasn't run yet. Mitigated by: (a) the idle scanner (MAL.D) catches anything the hook missed within 2h; (b) the legacy-status row count is expected low per §7.2.

## 8. Rollback plan

Each wave is independently revertible; no wave's rollback is blocked by a later wave.

### 8.1 Per-wave rollback

| Wave | Rollback | Impact |
|---|---|---|
| W1 (SE.A) | `git revert <sha>` on main; redeploy | `session_store.py` disappears; no call-sites use it yet. Safe. |
| W2 (BD Wave A) | Revert commit that deletes the four files; redeploy | `/preview` route returns to old behaviour; no code calls `patch_config`. Safe. |
| W3 (MAL.A + SE.A.8 + MAL.C refactor) | Revert + redeploy | `cancel-build` and `close` go back to inline delete; wrapper removed. Safe. |
| W4 (SE.B.2 + BD main.py) | Revert + redeploy; re-run `migrate_session_status.py --reverse` (script adds reverse-mapping mode — OQ-SHIP-3) | Traffic switches back to `session.py` / direct-Firestore. BD-deleted lines regenerate. **Data risk**: enum values mid-revert. Canary traffic split keeps this to 10%. |
| W5 (SE.B.4 + BD factory) | Revert + redeploy | Factory path reverts to translated. S3 must continue to accept translated payloads — confirm with S3 team before W5 (see OQ-SHIP-2). |
| W6 (MAL full) | Revert + redeploy; OR set `MANAGED_SESSION_MONITOR_ENABLED=false` via `gcloud run services update` (no code change) | Scanner + terminal hook disabled; eager teardown via inline deletes still works via MAL.C refactor which stays live. |
| W7 (MAD full) | Revert + redeploy; OR keep code + flag off (`MANAGED_AGENT_DASHBOARD=0`) | UI tab disappears; routes return 404. |
| W8 (SE.C + SE.D + grep-gate) | Revert grep-gate: safe. Revert SE.D: tokens fall back to Firestore — but the `demo-studio-used-tokens` collection was dropped; **SE.D rollback requires a code-path that still writes to the collection AND the collection to exist**. Mitigation: defer the `DROP COLLECTION demo-studio-used-tokens` step one wave (W9). | Acceptable. |
| W9 (observability + integration) | Revert | Test artefacts only. |
| W10 (flag flip) | `gcloud run services update demo-studio --update-env-vars MANAGED_AGENT_DASHBOARD=0` | UI tab disappears; Sessions tab unchanged. Operators can still file tickets describing orphans; MAL scanner still catches them. |

### 8.2 Integrated rollback

If a prod smoke fails at W4–W10, the composite rollback path is:

1. `scripts/deploy/rollback.sh` auto-triggers (CLAUDE.md Rule 17).
2. `gcloud run services update-traffic demo-studio --to-revisions=PREVIOUS=100` routes 100% back to the pre-deploy revision.
3. Slack alert to `#demo-studio-alerts` + Duong + Heimerdinger.
4. Post-mortem runbook entry committed within 24h.

### 8.3 Data rollback

SE.C enum migration is idempotent but not losslessly reversible — the mapping `archived` → `completed`|`cancelled` is heuristic and loses the `archived` label permanently. If SE.C needs reversal:

- OQ-SHIP-3 tracks whether a reverse-mapping mode is worth the task cost.
- If rejected (quickest), rollback of W8's SE.C is "live with the new enum"; any code path reverting to W7 or earlier must accept either the migrated enum or be explicitly backward-compatible.
- BD's orphaned `config` field is pure read-free dead data; no rollback needed — it persists until someone writes a cleanup script.

## 9. Open questions

Gating questions. Each carries a **LOCKED** decision, a **DEFERRED** flag with a trigger, or an **OPEN** label requiring a Duong decision before W-n commences. Using the canonical Duong decision format.

**OQ-SHIP-1. Cloud Run min-instances pinning.** MAL and MAD both assume `--min-instances=1 --max-instances=1`; current `deploy.sh` does not set these, defaulting to Cloud Run's `min=0, max=100`. In-process scanner dedup cache and MAD list cache both break on multi-instance: warnings duplicate, cache coherence is lost.

```
OQ-SHIP-1. Pin demo-studio Cloud Run to min=max=1?
   a: update deploy.sh to pin; cleanest — matches the stated assumption; audit trail in git
   b: keep deploy.sh open-ended + add a startup-time assertion in main.py that fails loud on >1 instance; balanced — works if Cloud Run ever auto-scales accidentally
   c: leave as-is; quickest, but the MAL dedup cache + MAD TTL cache both silently mis-behave on >1 instance (duplicate slack warnings, stale cache views)
Pick: a — the pinning is an assumption both MAL §4 and MAD §6 already made; making it explicit in deploy.sh is cheap and closes the gap Orianna would otherwise flag at fact-check time.
```

**OQ-SHIP-2. S3 self-fetch confirmation before W5.** BD §5.3 + §8.2 states S3 takes `{sessionId}` only and self-fetches config from S2. BD §7 puts this pre-deploy confirmation on Sona. It has **not been confirmed** as of this plan. If S3 still expects the translated payload, W5 cannot deploy.

```
OQ-SHIP-2. Pre-W5 S3 self-fetch verification strategy?
   a: Sona pings S3 team, waits for explicit confirmation + live-staging test against a throwaway session before W5 merges; cleanest, highest confidence
   b: deploy W5 with a one-deploy-only dual-path in trigger_factory — sends both `{sessionId}` AND the translated payload, lets S3 ignore whichever it doesn't use; then drops the translated payload in W6; balanced, more code churn
   c: assume S3 self-fetch is live (spec says it is); deploy W5; watch for errors; quickest, but blast radius is every new build until rollback
Pick: a — BD §7 already assigned this to Sona; §6.1 and §8.1 both mark W5 as canary-with-traffic-split, which gives us the rollback window but only after at-least-one-build has broken. Waiting for explicit confirmation is the asymmetric-cost-correct choice here.
```

**OQ-SHIP-3. SE.C enum-migration reverse mode.** §8.3 covers this.

```
OQ-SHIP-3. Add a --reverse mode to migrate_session_status.py for W4 rollback?
   a: yes — add a full reverse-mapping mode with an audit log of heuristic-resolved rows so the reverse run can apply them accurately; cleanest, but the `archived`-split rows are lossy regardless
   b: no, but add a pre-migration snapshot step — `gcloud firestore export` to a dated bucket before W4 prod run; balanced; restore-from-snapshot is the rollback mechanism
   c: no reverse, no snapshot; quick; if W4 rollback is needed we hand-walk affected rows with ops
Pick: b — the snapshot is cheap, universal, and works for any rollback scenario (not just enum), and doesn't require writing reverse-mapping logic that would only be exercised under duress. §7.3 wave note already recommends the dry-run → snapshot → run → smoke sequence; this just codifies it.
```

**OQ-SHIP-4. `/session/{id}/preview` route deprecation during W2.** BD §3.6 deletes `preview.py` outright. Operators may have existing bookmarks or preview-tab inline previews that link to `/session/{id}/preview` on S1.

```
OQ-SHIP-4. How to handle /session/{id}/preview deprecation at W2?
   a: full redirect to S5's preview URL with a one-page banner announcing the move, 410 after 30 days; cleanest user experience
   b: return HTTP 410 Gone with a JSON body pointing at S5; balanced; no new infra
   c: just delete the route; quickest; any existing bookmark 404s
Pick: b — operators are few enough to Slack-notify once; 410 + body is cheap; the 30-day redirect of (a) is more ceremony than the audience warrants. Confirm with Duong if operator-facing bookmarks actually exist; if not, (c) is viable.
```

**OQ-SHIP-5. MAL scanner startup default.** W6 deploys with `MANAGED_SESSION_MONITOR_ENABLED=true` as default per §6.3. If the scanner has an unknown latent bug, every deploy from W6 onward starts the loop.

```
OQ-SHIP-5. Default state for MANAGED_SESSION_MONITOR_ENABLED at W6?
   a: false (scanner off by default); flip to true in W10 alongside the MAD flag; cleanest observation window
   b: true (scanner on) but with IDLE_TERMINATE_MINUTES=1440 (24h) — safety-off without silencing the warn path; balanced; learns scan+warn behaviour without risking false-positive kills
   c: true with the specced thresholds (60/120); quickest to parity with the MAL ADR; relies on the MAL.D unit tests being complete
Pick: b — the ADR's stated cost model is "bounded by 2h idle"; widening to 24h for one week costs ~11× the original ceiling, which is negligible at current session volume, and surfaces scan-cycle + warn behaviour with a real user load we can't get from unit tests. Narrow back to 120 in W10 when everything's proven.
```

**OQ-SHIP-6. Grep-gate enforcement mode at W8.** SE.E.2 + BD Rule 4 + MAL.E.1b land as a CI check. Per `assessments/advisory/2026-04-21-mad-grep-gate-allowlist-advisory.md` §4 (Camille's advisory), the gate should run at both pre-commit and CI with the same script. But the MAD worktree already has commits that predate the gate.

```
OQ-SHIP-6. Retroactive grep-gate enforcement on MAD worktree commits?
   a: require all existing MAD commits to pass the gate via rebase-onto-amended-history; cleanest history, but rebases 7+ commits
   b: grandfather existing MAD commits (gate runs on the merge-commit diff to main, not per-commit history) — new commits on the branch must pass, PR check gate-at-merge; balanced, preserves committer identity + TDD ordering
   c: skip the gate on the MAD PR and enable from next PR onward; quickest, but leaves a gap in the audit trail
Pick: b — preserving the xfail-impl commit pairs unchanged is important (the pre-push TDD hook checks those pairs, and rebasing would lose them); a merge-commit diff check is structurally equivalent to a per-file check on the PR-visible change; advisory §4 supports pre-commit + CI but is silent on retroactive vs. forward-only enforcement.
```

**OQ-SHIP-7. Single ship PR or ten wave PRs?** §4.2 treats it as one release PR at W10; §2.2 sequences ten waves, each of which could be its own merge. Merging ten separate PRs from one long-lived branch risks rebase storms; one giant PR obscures reviews.

```
OQ-SHIP-7. PR granularity?
   a: one PR per wave (W1–W10), each from feat/demo-studio-v3 → main, serialised by CI; cleanest review surface; risks rebase interleave with parallel MAD worktree work
   b: one PR per logical cluster (4 PRs: SE+BD pre-migration, MAL, MAD, migration+flag-flip); balanced; each PR is reviewable in one sitting
   c: one PR for everything at W10; quickest to merge; review would take days and the bisect surface on any post-merge regression is the whole ADR cluster
Pick: b — the four-cluster split mirrors the ADR boundaries; Senna/Lucian can review each cluster against its ADR; the canary-traffic-split strategy (§6.1) works at this granularity (each cluster's PR is one Cloud Run deploy). Also: four PRs lets Duong sequence merges by confidence — he can merge SE+BD while still reviewing MAL+MAD, which is impossible with one giant PR.
```

## Test plan

Per CLAUDE.md Rule 12 (TDD) + Rule 13 (regression). This plan itself is an orchestration ADR — it does not add production code, so it does not add production xfail tests. The tests listed below are the integration-layer surface that the four sibling ADRs' task files already own, rolled up for ship-gate purposes.

- **T1 — Unit coverage from sibling ADRs.** Green-check items in §4.1 constitute the unit-test surface; each sibling task file owns its own xfail-impl pairs. This plan does not duplicate them.
- **T2 — Integration test: MAL.H.2 stop_managed_session round-trip.** Real Anthropic API key, throwaway session, stop → retrieve → assert terminated or 404. Owner: MAL task file. Gate-list item in §4.1.
- **T3 — Integration test: MAD.F.1 end-to-end list + terminate.** Real Anthropic, Firestore emulator, stubbed S2. Asserts list shows the session, terminate flips DB + writes audit log + invalidates cache. Owner: MAD task file. Gate-list item in §4.1.
- **T4 — E2E smoke test: `tests/smoke/test_e2e_ship.py`.** Ten scenarios S1–S10 per §5.1. Runs against stg after every deploy that touches `feat/demo-studio-v3`; runs against prod (subset — §5.2) after prod deploys; prod-smoke failure triggers `scripts/deploy/rollback.sh`. This test file is the one net-new test surface this plan adds.
- **T5 — Regression: existing Sessions tab byte-identical.** MAD.E.2 golden-fixture test. Gate-list item in §4.1.
- **T6 — Grep-gate CI check.** SE.E.2 + BD Rule 4 + MAL.E.1b + MAD.E.1 allowlist. CI-level enforcement; must be green on the release PR.
- **T7 — Ship-gate manual checklist review.** §4.1 list reviewed by Evelynn (coordinator) + Duong before W10 flag flip. Not a test in the CI sense, but the final gate — documented in the runbook entry added by MAD.G.1 / this plan's handoff.

## Handoff

- **Duong:** resolve OQ-SHIP-1 through OQ-SHIP-7. W0 (spikes + audits) can start immediately after resolutions; W1 cannot begin until SE is Orianna-signed at `approved` (signing in flight per agent-network note; Evelynn tracks).
- **Evelynn:** owns wave sequencing + PR-granularity decisions (once OQ-SHIP-7 resolves). Spawns implementers per the sibling task files. Runs the §4.1 gate-list review before W10 flip.
- **Orianna:** fact-check the §1.1 HEAD SHAs and the §1.3 pre-existing MAD work tree if this plan is promoted before W0 starts (line-number drift is expected; the ADR is point-in-time). Verify cross-plan references to SE/BD/MAL/MAD ADR paths are valid at sign-time.
- **Kayn / Aphelios:** no new task files from this plan. Each sibling ADR's existing task file stands. If SE promotes to `approved/` and any task-file amendments are needed to align with the §2.2 wave sequencing, those amendments land in the SE task file, not here.
- **Heimerdinger:** owns §6.1 deploy sequencing + §6.3 env-var wire + §7 migration runbook. Confirm Firestore export + Cloud Run traffic-split recipes before W4.
- **Senna + Lucian:** review the four cluster PRs (assuming OQ-SHIP-7b) against the cluster's ADR(s). Regression-lock: the MAD PR's Senna review must verify the allowlist row per advisory §1.
- **Akali:** run Playwright flow + Figma diff against the Managed Agents tab before the MAD PR merges, per CLAUDE.md Rule 16. Report under `assessments/work/qa-reports/`.

## Non-goals (explicit)

- **NOT** a fifth service. S5 preview stays out of scope.
- **NOT** a redesign of the auth posture. MAD ADR Q4 deferred; this plan inherits the deferral.
- **NOT** a rewrite of the config schema. S2 is authoritative; this plan consumes S2's contract as-is.
- **NOT** an admin-identity-per-operator for MAD terminate audit logs. MAD ADR §8 known-gap; this plan inherits.
- **NOT** a bulk-terminate UI. MAD ADR §9 non-goal; this plan inherits.
- **NOT** cross-region HA for demo-studio. Single-region Cloud Run pinned; if traffic grows, a separate ADR owns that question.
- **NOT** an alternative deployment target (GKE, Cloud Functions). `gcloud run deploy` as in the existing `deploy.sh`.
