---
status: implemented
complexity: normal
concern: work
owner: Sona
created: 2026-04-20
tags:
  - demo-studio
  - service-1
  - managed-agent
  - lifecycle
  - cost-control
  - work
tests_required: true
---

# ADR: Managed-Agent Session Lifecycle Control (Demo Studio v3 Service 1)

Date: 2026-04-20
Scope: `company-os/tools/demo-studio-v3` (Service 1 only) <!-- orianna: ok -->
Related: `secretary/agents/azir/learnings/2026-04-20-session-api-adr.md` (session-state-encapsulation ADR) <!-- orianna: ok -->

## 1. Context

Anthropic Managed Agent sessions created under `MANAGED_AGENT_ID=agent_011Ca9Dk3H4m6DYcA6e489Ew` can run indefinitely. Idle but unclosed sessions continue to be billed at an hourly rate (confirmed by Anthropic docs; see section 3). Cost grows per active session.

Today, Service 1 creates a managed session in two places and almost never tears one down:

- `agent_proxy.py::create_managed_session` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ --> — called during session bootstrap.
- `main.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ --> line 2046-area — wires the managed session into Firestore and hands it to the browser SSE proxy. <!-- orianna: ok -->
- The only existing stop path is `POST /session/{session_id}/cancel-build` <!-- orianna: ok — HTTP route, not a filesystem path --> (`main.py:2084`), which calls `client.beta.sessions.delete(...)` — but only when the user explicitly cancels a build.

Any other exit path (user closes tab, demo completes, QC fails, backend crashes, build_failed, orphan record) leaves the managed session running until Anthropic internally expires it. We have observed drift between our Firestore `status` and Anthropic's view: partial writes and crashed transitions mean our DB cannot be trusted as source of truth for "what is actually running".

We need deterministic lifecycle control that is robust to DB drift and crash scenarios.

## 2. Decision

Two lifecycle signals, with **Anthropic as source of truth**:

### 2.1 Terminal-state cleanup (eager)

Inside `session_store.transition_status` (see session-state-encapsulation ADR), every successful transition into a terminal status — `{completed, cancelled, qc_failed, build_failed, built}` — synchronously calls `agent_proxy.stop_managed_session(managed_session_id)`. Idempotent: a second call on an already-deleted session is a no-op (`404 -> ignore`).

### 2.2 Idle scanner (safety net)

An in-process async task runs every `SCAN_INTERVAL_SECONDS=300` (5 min) inside Service 1. Each scan:

1. Enumerates active Managed Agent sessions via the Anthropic SDK filtered to our `MANAGED_AGENT_ID`.
2. For each active session, resolves its idle duration (see section 3 for field resolution).
3. If idle > `IDLE_WARN_MINUTES=60`: post a one-line Slack warning (see section 5), deduped via in-process TTL cache.
4. If idle > `IDLE_TERMINATE_MINUTES=120`: call `client.beta.sessions.delete(id)`, then update the matching Firestore row to `status=cancelled, cancelReason=idle_timeout`. If no Firestore row matches, log `orphan_terminated` and still delete on Anthropic.

### 2.3 Source-of-truth rule

The scanner trusts Anthropic for "what is running" and "how long has it been idle". Our Firestore is consulted **only for enrichment** (slack coordinates for the warning — see BD amendment §2.1 for the revised enrichment join). DB drift cannot cause us to miss a live session, nor to kill a session Anthropic already ended.

### 2.4 Idle-only, no absolute-age tiers

Explicitly rejected: 2/4/6/12/24h absolute-age thresholds. An active-but-long demo (e.g. training a new account manager) must not be killed just for running long. Idle is the signal that matters.

## 3. Anthropic API research needed

Based on `https://platform.claude.com/docs/en/managed-agents/sessions` <!-- orianna: ok — external URL; Anthropic managed sessions docs, fetched 2026-04-20 --> (fetched 2026-04-20):

| Need | Documented surface | Gap / fallback |
| --- | --- | --- |
| (a) List active sessions for an `agent_id` | `client.beta.sessions.list()` — paginated, returns `{id, status}` | **Docs do not show an `agent` filter param.** Fallback: list all, then either (i) filter client-side by retrieving each session's `agent.id` via `retrieve()`, or (ii) persist the managed_session_id -> agent_id map in Firestore and filter using our own data. Implementers (Kayn) must confirm the SDK signature by reading `anthropic` Python package source before finalising. | <!-- orianna: ok -->
| (b) Get session with last activity timestamp | `client.beta.sessions.retrieve(session_id)` returns status and other fields | **`lastActivityAt` is not shown in docs.** The statuses listed are `{idle, running, rescheduling, terminated}`. Fallback: compute idle via events — `client.beta.sessions.events.list(session_id)` (or equivalent) sorted by `created_at` desc; idle duration = `now - latest_event.created_at`. Implementers must verify the events-list endpoint name and `created_at` field during Spike 1 (see section 4). If events list is also unavailable, second fallback: persist `lastActivityAt` ourselves on every inbound SSE event in Service 1, accepting the DB-drift risk on this one field only. |
| (c) Stop / end a session | `client.beta.sessions.delete(session_id)` (documented; already used in `main.py:2113` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ -->) | Deleting a `running` session requires an interrupt event first. `stop_managed_session()` must send an `interrupt` event before delete when status is `running`, or catch the error and retry. |

**Blocker assessment:** Gap (a) is solvable with a client-side filter at our current session volume (<100 concurrent). Gap (b) is the real risk: if neither `lastActivityAt` nor an events-list endpoint exposes a usable timestamp, we fall back to Service-1-maintained idle tracking, which reintroduces DB-drift risk for the scanner's core input. This is flagged as Q1 below and must be resolved before implementation.

## 4. Module shape

New file: `company-os/tools/demo-studio-v3/managed_session_monitor.py` <!-- orianna: ok — future file in missmp/company-os --> <!-- orianna: ok -->

- `ManagedSessionMonitor` class with async `run_forever()` loop.
- TTL dedup cache: `dict[str, float]` keyed by `managed_session_id`, value = expiry epoch. Warnings suppressed if entry is present and not expired.
- Started as an asyncio background task in `main.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ --> FastAPI `startup` event. Cancelled on `shutdown` event. <!-- orianna: ok -->
- Single-instance assumption: Cloud Run Service 1 runs `--min-instances=1 --max-instances=1`. If that changes, a second instance would double-scan; collision is safe (deletes are idempotent) but warnings could duplicate. Mitigation: migrate dedup cache to Firestore if we ever scale out. Out of scope for this ADR.

New function in `agent_proxy.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ -->: <!-- orianna: ok -->

```python
async def stop_managed_session(session_id: str, reason: str = "") -> bool:
    """Idempotently terminate a managed session.

    Returns True if deleted, False if already gone. Handles `running` state by
    sending an interrupt event first. Swallows 404. Logs all outcomes.
    """
```

Terminal-state wiring: `session_store.transition_status` (per session-state-encapsulation ADR) calls `stop_managed_session` as a post-commit hook inside the same code path that fires status-change webhooks. The hook is `await`-ed but wrapped in a per-call timeout (5s, matching the existing `cancel_build` pattern in `main.py:2112` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ -->) so a slow Anthropic response cannot block the transition.

### Spike 1 (before implementation)

Kayn's executor must spike the two SDK gaps (a) and (b) in section 3 and attach the findings to this ADR as an appendix before writing production code. Budget: estimate_minutes: 120.

## 5. Slack warning format

One line per warning, posted via the existing `slack-relay` MCP: <!-- orianna: ok — internal MCP server name; not on allowlist but is an internal company-os integration, not a filesystem path -->

```
:warning: Session idle 62min — Allianz (dnt@missmp.eu, #demos). Will auto-cancel at 120min.
```

Field sources (per BD amendment §2.2):
- `62min` — computed idle duration from section 3.
- `Allianz` — `brand` from **S2** via `config_mgmt_client.fetch_config(sessionId)`. No `insuranceLine` (dead field per BD).
- `dnt@missmp.eu` — owner email (resolve from `slackUserId` via existing helper, fallback to the raw Slack user ID). Source: Firestore (lifecycle field).
- `#demos` — `slackChannel` from Firestore.

Cold-session fallback (S2 returns 404 — session exists but first `set_config` hasn't happened yet):
```
:warning: Session idle 62min — (config not yet set, dnt@missmp.eu, #demos). Will auto-cancel at 120min.
```

S2-unavailable fallback (5xx / network error — logged as `slack_enrichment_degraded`):
```
:warning: Session idle 62min — (brand unavailable, dnt@missmp.eu, #demos). Will auto-cancel at 120min.
```

Target channel: `#demo-studio-alerts` <!-- orianna: ok — named Slack channel in company-os Slack workspace; not a filesystem path; presence is flagged as Q2 below -->. **Flagged:** confirm channel exists and bot is invited — see Q2.

Orphan variant (Firestore row missing):
```
:warning: Orphan session idle 62min — managedSessionId=ses_abc123 (no Firestore record). Will auto-cancel at 120min.
```

Termination variant (on kill):
```
:no_entry: Session auto-cancelled — Allianz (dnt@missmp.eu). Idle 121min > 120min threshold.
```

## 6. Config

All via env vars, no new secrets:

| Name | Default | Purpose |
| --- | --- | --- |
| `MANAGED_AGENT_ID` | existing | Scope of scanner (already in use). |
| `IDLE_WARN_MINUTES` | `60` | Warn threshold. |
| `IDLE_TERMINATE_MINUTES` | `120` | Kill threshold. Must be > warn. |
| `SCAN_INTERVAL_SECONDS` | `300` | 5 min. Lower bound: Anthropic read rate limit is 600/min org-wide (per managed-agents docs), so 5 min × list + retrieve-per-session is comfortably safe at our volume. |
| `SLACK_ALERT_CHANNEL` | `demo-studio-alerts` | Target channel for warnings. Pending Q2. |
| `MANAGED_SESSION_MONITOR_ENABLED` | `true` | Kill switch for emergency rollback. |

Invariant check at startup: `IDLE_WARN_MINUTES < IDLE_TERMINATE_MINUTES`. Fail fast on misconfiguration.

## 7. Consequences

**Positive**
- Cost bounded: no session runs past 2h idle, regardless of client behaviour, DB state, or user action.
- Terminal-state cleanup is eager and immediate — users don't wait 5 minutes for the scanner to catch a completed build.
- Orphans are guaranteed reaped.
- Anthropic-first design means our Firestore can drift freely without costing us money.
- No new infra (Cloud Scheduler, Pub/Sub, Tasks). One service, one deploy.

**Negative**
- Scanner adds ~1 Anthropic API list call + N retrieves per 5 min. At 100 concurrent sessions = 100/5min = 20/min, well under the 600/min read limit.
- In-process scanner: a crashed Service 1 skips scans until restart. Acceptable because terminal-state cleanup is eager and Cloud Run auto-restarts on crash within ~60s.
- Dedup cache in-memory: a restart re-warns every already-warned session once. Acceptable — one extra Slack line per session per restart.
- Tight coupling: scanner depends on `session_store.transition_status` per section 4 + session-state-encapsulation ADR. If that ADR slips, scanner ships without the eager path and cost containment degrades to "kill within 2h idle".

## 8. Non-goals

Explicitly out of scope:
- Absolute-age kill tiers (2/4/6/12/24h).
- Per-user quotas or rate limits.
- Cost dashboards or per-session cost attribution.
- Retry / resume of auto-terminated sessions (user starts a new session if they come back).
- Cloud Scheduler + HTTP scanner (considered, rejected in favour of in-process — see section 2.2 rationale).
- Changes to Service 2 (Config Mgmt), Service 3 (Factory), or any other downstream service.
- Cross-region / HA scanner design.
- Shutdown-hook termination of active sessions on Service 1 deploy (see Q3).

## 9. Open questions

**Q1. SDK signatures for list and retrieve.** **DEFERRED to Spike 1 (MAL.0.1):** whether `client.beta.sessions.list()` accepts an `agent` filter param, whether `retrieve()` returns a `lastActivityAt`/`updated_at` equivalent, and whether `client.beta.sessions.events.list(session_id)` exists — all three are resolved by Kayn's SDK inspection in Spike 1. Resolution: see MAL.0.1. Owner: Kayn / executor. Blocker for MAL.D implementation only.

**Q2. Slack alert channel.** **DEFERRED to MAL.0.2:** whether `#demo-studio-alerts` is the correct channel and the `slack-relay` bot has membership is confirmed in MAL.0.2. Fallback: reuse `#demos` with a `[alert]` prefix. Owner: Duong / ops.

**Q3. Terminate on Service 1 shutdown?** **DEFERRED (lean: do NOT terminate).** Cloud Run auto-restart is fast (~60s); in-process scanner handles reaping on next cycle. Duong may override; tracked as out-of-scope for this ADR. If override needed, add SE-style terminal-hook to the SIGTERM handler.

## 10. Handoff notes

- **Kayn / Aphelios:** break into tasks. Spike 1 (SDK gap confirmation) is the first task and gates the rest. The module boundary in section 4 is load-bearing — do not merge `stop_managed_session` into `main.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ -->. <!-- orianna: ok -->
- **Depends on:** `secretary/agents/azir/learnings/2026-04-20-session-api-adr.md` <!-- orianna: ok — company-os workspace file; cross-repo ref --> (session-state-encapsulation). Terminal-state hook in section 2.1 lives inside that ADR's `transition_status`. If that ADR slips, ship scanner without the eager path and accept the degraded cost floor. <!-- orianna: ok -->
- **Test strategy (for Caitlyn):** three layers. (i) Unit: `stop_managed_session` idempotency, interrupt-before-delete when running, 404 swallow. (ii) Unit: `ManagedSessionMonitor` decision logic with a stubbed SDK (< warn = no-op, warn-only = 1 slack call, terminate = delete + slack + Firestore). The enrichment unit test must stub both `session_store.get_session` (for slack/user fields) and `config_mgmt_client.fetch_config` (for brand), covering three enrichment states (success, 404 cold, 5xx degraded). (iii) Integration: real Anthropic SDK against a throwaway session; S2 stubbed at the integration-test boundary (no cross-service HTTP).
- **Regression test for existing `/cancel-build` <!-- orianna: ok — HTTP route name, not a filesystem path --> path:** existing call site at `main.py:2111-2115` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ --> inlines the delete. Refactor it to call `stop_managed_session` and add a test asserting equivalence (no behaviour change for end users).
- **Observability:** structured logs with event types `managed_session_warned`, `managed_session_terminated`, `orphan_terminated`, `scan_cycle_complete` (with counts), `slack_enrichment_degraded`. Feed to existing `logger` in `main.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ -->. No new metrics infra. <!-- orianna: ok -->

## Appendix: Files touched

- NEW `company-os/tools/demo-studio-v3/managed_session_monitor.py` <!-- orianna: ok — future file in missmp/company-os; does not exist until MAL.D.2 --> <!-- orianna: ok -->
- MODIFY `company-os/tools/demo-studio-v3/agent_proxy.py` — add `stop_managed_session`. <!-- orianna: ok -->
- MODIFY `company-os/tools/demo-studio-v3/main.py` — wire monitor startup/shutdown; refactor `cancel_build` to use `stop_managed_session`. <!-- orianna: ok -->
- MODIFY `company-os/tools/demo-studio-v3/session_store.py` <!-- orianna: ok — company-os file; exists at feat/demo-studio-v3 per SE ADR; terminal-state hook (MAL.B) depends on SE.A.6 --> — add terminal-state hook (per session-state-encapsulation ADR). <!-- orianna: ok -->
- MODIFY `company-os/tools/demo-studio-v3/tests/` — new test files per section 10 test strategy. <!-- orianna: ok -->

## Tasks

_Source: `company-os/plans/2026-04-20-managed-agent-lifecycle-tasks.md` in `missmp/company-os`. Inlined verbatim._ <!-- orianna: ok — cross-repo task file; inlined per §D3 one-plan-one-file rule --> <!-- orianna: ok -->

# Task breakdown — Managed-Agent Session Lifecycle Control (MAL)

Source ADR: `plans/approved/work/2026-04-20-managed-agent-lifecycle.md` (including inlined BD amendment in §Amendments). <!-- orianna: ok -->

Branch: `feat/demo-studio-v3` (company-os worktree at `~/Documents/Work/mmp/workspace/company-os-demo-studio-v3`). Same branch as the dashboard (MAD), session-state-encapsulation (SE), and S1↔S2 boundary (BD) breakdowns — all share one PR branch per ADR §10 handoff. <!-- orianna: ok -->

Task-ID scheme: `MAL.<phase>.<n>` (matches the ADR's own inline enumeration so cross-ADR links in MAD / SE / BD task files remain valid). Every impl task is preceded on the same branch by an xfail test commit per Rule 12.

AI-minute estimates are wall-clock Sonnet-builder time per commit (test commit + impl commit counted separately). They exclude Kayn breakdown and Senna / Caitlyn review time.

## Cross-ADR dependency map (load-bearing — read first)

| Artefact | Source | Consumed by | Hard blocker? |
| --- | --- | --- | --- |
| `session_store.transition_status(sessionId, to_status, *, cancel_reason=…)` | SE.A.6 (+ SE §8 extension — `cancel_reason` kwarg resolved per OQ-MAL-6 pointer) | MAL.B.2 (terminal-state hook), MAL.D.3 (scanner flip to `cancelled`) | **YES** for MAL.B.2 and MAL.D.3. If SE slips past MAL.A: ship scanner + primitive without eager path per ADR §10. |
| `config_mgmt_client.fetch_config(sessionId) -> DemoConfig` (brand only; 404 on cold) | BD (client tasked there) | MAL.E.2 (Slack enrichment join) | **YES** for MAL.E.2 impl. If BD slips: MAL.E.2 stubs client to raise 5xx always, rendering `brand unavailable` — scanner still ships, warnings degraded. |
| Spike 1 appendix (Anthropic SDK list-filter / retrieve idle / events-list / interrupt semantics) | MAL.0.1 (own phase) | MAL.A.3/A.4 (interrupt-before-delete), MAL.D.1/D.3/D.4 (idle resolution) | **YES** — MAL.0.1 gates MAL.A.3 and all of MAL.D. |
| `MANAGED_AGENT_ID` env var | already live in `agent_proxy.py` | MAL.D.3 (agent filter) | NO — pre-existing. | <!-- orianna: ok -->
| `slack-relay` MCP bot membership in `#demo-studio-alerts` | MAL.0.2 | MAL.E.3 (post path) | **Soft blocker** — MAL.E.3 ships either way; if bot absent, warnings log but don't post. MAL.0.2 locks the channel default. |
| SE.E.2 grep-gate allow-list (BD §2 Rule 4 — `config_mgmt_client` callers) | SE.E.2 | MAL.E.2 (allowed import of `config_mgmt_client`) | **Soft blocker** — if SE.E.2 not yet extended, add allow-list entry in the MAL PR itself and flag to Camille. |

Cross-file coupling with MAD breakdown: MAD.B.2 / MAD.C.2 consume the same `stop_managed_session` primitive MAL.A.4 produces (via the `managed_session_client` wrapper MAL's Spike 1 surface drives). MAL.A.4 must merge before MAD.B/C impl starts; see §Sequencing.

---

## Phase summary & estimates

| Phase | Scope | Tasks | AI-min |
| --- | --- | --- | --- |
| MAL.0 | Preflight: Anthropic SDK spike + Slack channel/bot confirm | 2 | 135 |
| MAL.A | `stop_managed_session` primitive in `agent_proxy.py` | 4 (2 xfail + 2 impl) | 110 | <!-- orianna: ok -->
| MAL.B | Terminal-state hook in `session_store.transition_status` | 2 (1 xfail + 1 impl) | 55 |
| MAL.C | Refactor `/cancel-build` + `/close` call sites | 4 (2 xfail + 2 impl) | 75 |
| MAL.D | `ManagedSessionMonitor` class (scan loop + decision matrix) | 5 (2 xfail + 3 impl, incl. contingent D.4) | 180 |
| MAL.E | Slack warning/termination messaging + grep-gate self-check | 4 (1 xfail + 2 impl + 1 CI) | 95 |
| MAL.F | FastAPI startup/shutdown wiring | 2 (1 xfail + 1 impl) | 45 |
| MAL.G | Config plumbing + startup invariant | 2 (1 xfail + 1 impl) | 40 |
| MAL.H | Observability tests + integration (real Anthropic throwaway) | 2 (1 unit + 1 integration) | 65 |
| **TOTAL** | | **27** | **800** |

Notes:
- MAL.0.1 (Spike 1) alone is budgeted 120 AI-min (the ADR says estimate_minutes: 120 wall-clock human budget; Sonnet reads the `anthropic` package and writes the 1-page appendix inside that envelope).
- MAL.D.4 is a **contingent** task — exact shape and AI-min vary (15 / 30 / 60) with the spike outcome a/b/c. Estimate above assumes case (b) / 30.
- `bdUpdated: false` style partial-failure counts as "landed" per Caitlyn convention; no retry tasks here.

## Wave diagram (hard serial points `→`, parallelisable within wave `∥`)

```
Wave 0:  MAL.0.1 ∥ MAL.0.2

Wave 1 (eager spine):                     Wave 1 (scanner spine, parallel):
  MAL.A.1 → MAL.A.2                         MAL.D.1 → MAL.D.2 → MAL.G.1 → MAL.G.2
       ↓                                                    ↓
  MAL.A.3 → MAL.A.4  ←─── gates ──── MAL.D.3 (idle resolution uses A.4 timeout semantics)
       ↓                                                    ↓
  MAL.B.1 → MAL.B.2   [req SE.A.6]         MAL.D.4 (contingent on MAL.0.1 outcome)
       ∥                                                    ↓
  MAL.C.1 → MAL.C.2                        MAL.E.1 → MAL.E.2 → MAL.E.3
       ∥                                                    ↓
  MAL.C.3                                  MAL.E.1b (CI wiring, parallel)
                                                            ↓
                                           MAL.F.1 → MAL.F.2 (also needs MAL.G.2)

Wave 2 (observability + integration, after both spines):
  MAL.H.1 (needs B.2 + D.3 + E.2)
  MAL.H.2 (needs A.4; parallel with H.1)
```

The **eager path** (A + B + C) and the **scanner path** (D + E + F + G) are **independently shippable** per ADR scope-and-sequencing rationale. A builder can dispatch both spines in parallel after Wave 0.

## Hard serial points (copied from ADR §Dispatch plan + expanded)

1. **MAL.0.1 gates all of MAL.D and MAL.A.3.** No idle-resolution decision is possible before the spike.
2. **MAL.B.2 must follow SE.A.6.** If SE slips past Wave 1, MAL.B parks; eager path ships without it per ADR §10.
3. **MAL.C.2 must follow MAL.A.2; MAL.C.3 must follow MAL.A.2** — they replace inline deletes with the primitive.
4. **MAL.F.2 must follow MAL.D.3 + MAL.G.2** — can't wire startup until both the class and its config are real.
5. **MAL.E.2 must follow MAL.D.2 (class scaffold) and requires `config_mgmt_client` (BD).**
6. **MAL.H.1 must follow MAL.B.2 + MAL.D.3 + MAL.E.2** — tests all observability events emitted by those paths.

---

## Phase MAL.0 — Preflight

### MAL.0.1 — Spike 1: Anthropic SDK surface for list + retrieve + events (ERRAND / SPIKE)
- **What:** per ADR §3 + §4 "Spike 1": read the installed `anthropic` Python package source. Produce a 1-page appendix at `company-os/plans/2026-04-20-managed-agent-lifecycle-spike1.md` (lives in missmp/company-os, NOT this repo) covering the three rows of ADR §3 table: <!-- orianna: ok -->
  - (a) `client.beta.sessions.list()` — does it accept an `agent` filter param? If no, confirm the client-side filter fallback signature.
  - (b) retrieve / last-activity — does `retrieve()` expose `lastActivityAt` / `updated_at` equivalent? If no, does `client.beta.sessions.events.list(session_id)` exist with a `created_at` field? If neither, case (c) — Service-1-maintained `lastActivityAt` via SSE proxy.
  - (c) stop — confirm `interrupt` event name and payload shape for `running` sessions before delete.
- **Deliverable:** the spike appendix, committed in the company-os worktree with `chore:` prefix. Append a short "result" block to THIS task file (same paragraph style as MAD.0.1) naming which case (a/b/c) landed for row (b), because it drives MAL.D.4 shape.
- **Acceptance:** appendix documents each row with exactly one of: (i) exact SDK surface confirmed, (ii) named fallback, (iii) blocker requiring Duong/Azir decision.
- **TDD:** exempt — research artefact, no code change.
- **Blockers:** none.
- **AI-min:** 120 (matches ADR's estimate_minutes: 120 budget).

### MAL.0.2 — Confirm `#demo-studio-alerts` Slack channel + bot membership (ERRAND)
- **What:** verify the channel exists in the company-os Slack workspace and that the `slack-relay` MCP bot is a member. If either is false, request invite OR fall back to `#demos` with `[alert]` prefix per ADR §5. Lock the chosen default for `SLACK_ALERT_CHANNEL`.
- **Deliverable:** finding appended to the MAL.0.1 spike appendix under a "Q2 — Slack channel" heading.
- **Acceptance:** channel name locked; bot membership confirmed or fallback chosen.
- **TDD:** exempt.
- **Blockers:** none.
- **AI-min:** 15.

---

## Phase MAL.A — `stop_managed_session` primitive

Pure additive. Merges independently of MAL.B/C/D. Module boundary (primitive in `agent_proxy.py`, NOT `main.py`) is load-bearing per ADR §10. <!-- orianna: ok -->

**BD note:** this primitive is pure Anthropic — it does NOT touch S2 (BD amendment §4 item 1).

### MAL.A.1 — xfail: idempotency + 404 swallow + outcome logging (TEST)
- **What:** new `tools/demo-studio-v3/tests/test_stop_managed_session.py`. Tests: <!-- orianna: ok -->
  1. Delete on idle status: wrapper `delete(session_id)` called once; returns `True`.
  2. 404 swallow: `delete()` raises `NotFoundError` → function returns `False`, no exception propagates.
  3. Idempotent second call: second invocation against an already-deleted id returns `False`, no new error.
  4. Outcome logging: success emits `managed_session_terminated` with `reason` field.
- **Acceptance:** tests import `agent_proxy.stop_managed_session` and xfail with `AttributeError` / `ImportError`. `@pytest.mark.xfail(reason="MAL.A.2", strict=True)`.
- **Commit:** `chore: add xfail tests for stop_managed_session idempotency (MAL.A.1)`.
- **TDD:** xfail commit for MAL.A.2.
- **Depends on:** none.
- **AI-min:** 20.

### MAL.A.2 — impl: idempotent delete path (BUILDER)
- **What:** add `async def stop_managed_session(session_id: str, reason: str = "") -> bool` to `tools/demo-studio-v3/agent_proxy.py`. Signature + docstring verbatim from ADR §4. Simple path (non-`running` status): call `client.beta.sessions.delete(session_id)`; swallow `NotFoundError` → return `False`. Log success via structured event `managed_session_terminated` with `reason` field. <!-- orianna: ok -->
- **Acceptance:** MAL.A.1 tests 1–4 pass (drop xfail).
- **Commit:** `feat(demo-studio-v3): stop_managed_session primitive (MAL.A.2)`.
- **TDD:** preceded by MAL.A.1.
- **Depends on:** MAL.A.1.
- **AI-min:** 25.

### MAL.A.3 — xfail: interrupt-before-delete on `running` + 5s timeout (TEST)
- **What:** extend `test_stop_managed_session.py`. Tests: <!-- orianna: ok -->
  5. Interrupt sent before delete when status `running` (exact SDK call from MAL.0.1 spike).
  6. Retry after first delete error on `running` status.
  7. 5s timeout: underlying call hangs → returns `False`, emits `managed_session_stop_timeout`.
- **Acceptance:** xfail strict against MAL.A.2 impl (no interrupt logic yet).
- **Commit:** `chore: add xfail tests for interrupt-before-delete + timeout (MAL.A.3)`.
- **TDD:** xfail commit for MAL.A.4.
- **Depends on:** MAL.A.2, MAL.0.1.
- **AI-min:** 20.

### MAL.A.4 — impl: interrupt-before-delete + 5s timeout (BUILDER)
- **What:** extend `stop_managed_session` to: (i) `retrieve(session_id)` first; (ii) if `status == "running"`, send interrupt event per spike appendix, then delete; (iii) wrap the whole call in `asyncio.wait_for(..., timeout=5.0)`; (iv) on timeout, log `managed_session_stop_timeout` and return `False`.
- **Acceptance:** MAL.A.3 tests pass.
- **Commit:** `feat(demo-studio-v3): interrupt-before-delete + 5s timeout in stop_managed_session (MAL.A.4)`.
- **TDD:** preceded by MAL.A.3.
- **Depends on:** MAL.A.3.
- **AI-min:** 45.

---

## Phase MAL.B — Terminal-state hook in `session_store.transition_status`

Depends on SE.A.6 landing. If SE slips, park this phase and accept the degraded cost floor ("kill within 2h idle" via scanner alone) per ADR §10.

### MAL.B.1 — xfail: terminal-state hook invocation (TEST)
- **What:** new `tools/demo-studio-v3/tests/test_transition_status_terminal_hook.py`. Tests: <!-- orianna: ok -->
  1. Hook called on transition to each terminal status: `completed`, `cancelled`, `qc_failed`, `build_failed`, `built`.
  2. Hook NOT called on transition to non-terminal status (e.g. `building`).
  3. Hook failure does NOT block the transition (exception swallowed + `terminal_hook_failed` logged).
  4. `managedSessionId is None` → hook skipped, `terminal_hook_skipped_no_managed_session` logged.
  5. 5s timeout bound (already enforced inside `stop_managed_session` per MAL.A.4).
- **Acceptance:** xfail strict — hook not yet wired.
- **Commit:** `chore: add xfail tests for transition_status terminal-state hook (MAL.B.1)`.
- **TDD:** xfail commit for MAL.B.2.
- **Depends on:** SE.A.6 (`transition_status` implemented).
- **AI-min:** 25.

### MAL.B.2 — impl: wire post-commit hook inside `transition_status` (BUILDER)
- **What:** modify `tools/demo-studio-v3/session_store.py::transition_status` so that, after a successful Firestore CAS commit, if `to_status` is in the terminal set, await `agent_proxy.stop_managed_session(session["managedSessionId"], reason=f"transition_to_{to_status}")`. Guards per MAL.B.1 tests 3/4/5. Post-commit — a hook failure CANNOT roll back the transition. Signature unchanged. <!-- orianna: ok -->
- **Acceptance:** MAL.B.1 tests pass. SE task-file's existing `transition_status` tests still pass.
- **Commit:** `feat(demo-studio-v3): terminal-state cleanup hook in transition_status (MAL.B.2)`.
- **TDD:** preceded by MAL.B.1.
- **Depends on:** MAL.B.1, MAL.A.4, SE.A.6.
- **AI-min:** 30.

---

## Phase MAL.C — Refactor `/cancel-build` + `/close` to use primitive

### MAL.C.1 — regression xfail: `/cancel-build` equivalence (TEST)
- **What:** new `tools/demo-studio-v3/tests/test_cancel_build_uses_stop_primitive.py`. Assert: (i) `POST /session/{id}/cancel-build` returns 200 on `building` status; still sets `_stop_flags[session_id] = True`; still deletes the managed session — but via `agent_proxy.stop_managed_session` (mock target moves from `main._client.beta.sessions.delete` to `main.stop_managed_session`). (ii) Response body byte-identical to pre-refactor baseline (golden fixture). (iii) 5s timeout behaviour preserved. <!-- orianna: ok -->
- **Acceptance:** xfail strict against current inline-delete code.
- **Commit:** `chore: add regression xfail for /cancel-build refactor (MAL.C.1)`.
- **TDD:** xfail + regression commit for MAL.C.2. Required by Rule 13 (bug/regression rule; refactors on stop paths treated equivalently per ADR §10).
- **Depends on:** MAL.A.2.
- **AI-min:** 15.

### MAL.C.2 — impl: refactor `/cancel-build` handler (BUILDER)
- **What:** in `tools/demo-studio-v3/main.py` around lines 2084–2120, replace the inline `_client.beta.sessions.delete(managed_session_id)` block with `await stop_managed_session(managed_session_id, reason="cancel_build")`. Keep the 5s timeout (now enforced inside the primitive). Remove the local `_client` construction if unused at that call site. <!-- orianna: ok -->
- **Acceptance:** MAL.C.1 passes. Pre-existing `tests/test_stop_build_phase.py` passes after mock-target rewrite. <!-- orianna: ok -->
- **Commit:** `refactor(demo-studio-v3): /cancel-build uses stop_managed_session (MAL.C.2)`.
- **TDD:** preceded by MAL.C.1.
- **Depends on:** MAL.C.1.
- **AI-min:** 20.

### MAL.C.3 — regression xfail + impl: `/close` (line 2204 inline delete) (TEST + BUILDER, paired)
- **What:** same pattern as MAL.C.1 + MAL.C.2 but for `POST /session/{id}/close` route at `main.py:2204`. One xfail regression test commit + one impl commit. New test `tests/test_close_uses_stop_primitive.py`; edit `main.py:2200–2215` area. Pre-existing `test_stop_and_archive.py` mock-target rewritten. <!-- orianna: ok -->
- **Acceptance:** regression test passes; existing archive tests still pass.
- **Commit sequence:**
  - `chore: add regression xfail for /close refactor (MAL.C.3 test)`.
  - `refactor(demo-studio-v3): /close uses stop_managed_session (MAL.C.3 impl)`.
- **TDD:** xfail-paired test commit precedes impl.
- **Depends on:** MAL.A.2. Independent of MAL.C.2.
- **AI-min:** 40 (split 15 test / 25 impl).

---

## Phase MAL.D — `ManagedSessionMonitor` class

### MAL.D.1 — xfail: decision-matrix coverage (TEST)
- **What:** new `tools/demo-studio-v3/tests/test_managed_session_monitor.py`. Stubbed Anthropic SDK + stubbed clock. Parametric cases: <!-- orianna: ok -->
  1. `idle < warn` → no-op.
  2. `warn ≤ idle < terminate` → one Slack warning; dedup cache entry written.
  3. `idle ≥ terminate` → `stop_managed_session` called + Slack termination posted + `session_store.transition_status(..., cancel_reason="idle_timeout")` attempted.
  4. Orphan (no Firestore row) → stop + orphan Slack variant; no transition attempted.
  5. Agent filter: only sessions under `MANAGED_AGENT_ID` acted on.
  6. `scan_cycle_complete` log emitted with counts.
  7. Dedup: second warning within TTL suppressed.
- **Acceptance:** xfail strict — class doesn't exist.
- **Commit:** `chore: add xfail tests for ManagedSessionMonitor decision matrix (MAL.D.1)`.
- **TDD:** xfail commit for MAL.D.2 + MAL.D.3.
- **Depends on:** MAL.0.1.
- **AI-min:** 30.

### MAL.D.2 — impl: class scaffold + TTL dedup cache + MonitorConfig (BUILDER)
- **What:** new `tools/demo-studio-v3/managed_session_monitor.py`. Define: <!-- orianna: ok -->
  - `MonitorConfig` dataclass (fields from ADR §6: `managed_agent_id`, `idle_warn_minutes`, `idle_terminate_minutes`, `scan_interval_seconds`, `slack_alert_channel`, `enabled`). `.from_env()` bodied in MAL.G.2.
  - `ManagedSessionMonitor(client, session_store, slack_relay, config)` with TTL dedup cache `dict[str, float]`.
  - `async def run_forever()` loop (cancellable via `asyncio.CancelledError`). <!-- orianna: ok -->
  - `async def scan_once()` — empty stub (bodied in MAL.D.3).
- **Acceptance:** import tests pass; `run_forever` cancels cleanly. MAL.D.1 tests still xfail.
- **Commit:** `feat(demo-studio-v3): ManagedSessionMonitor scaffold + dedup cache (MAL.D.2)`.
- **TDD:** preceded by MAL.D.1.
- **Depends on:** MAL.D.1.
- **AI-min:** 30.

### MAL.D.3 — impl: `scan_once` decision logic (BUILDER)
- **What:** body `scan_once()` per ADR §2.2. For each active session:
  1. Resolve idle duration via mechanism chosen in MAL.0.1 (a/b/c).
  2. Apply the MAL.D.1 decision matrix.
  3. For terminations: call `agent_proxy.stop_managed_session`; then attempt `session_store.transition_status(..., to_status="cancelled", cancel_reason="idle_timeout")` — swallow transition failure (Anthropic is authoritative).
  4. Emit `scan_cycle_complete` log with counts.
  5. Agent filter: only act on sessions whose agent id matches `MANAGED_AGENT_ID`.
- **Acceptance:** MAL.D.1 tests all pass.
- **Commit:** `feat(demo-studio-v3): scan_once decision logic for ManagedSessionMonitor (MAL.D.3)`.
- **TDD:** preceded by MAL.D.1.
- **Depends on:** MAL.D.2, MAL.A.4, SE.A.6.
- **AI-min:** 45.

### MAL.D.4 — CONTINGENT: idle-timestamp resolution fallback (TEST + BUILDER, shape TBD)
- **What:** shape depends on MAL.0.1 outcome:
  - **Case (a)** — `retrieve().last_activity_at` confirmed: fold into MAL.D.3. THIS TASK BECOMES A NO-OP; close immediately. **AI-min: 0.**
  - **Case (b)** — `events.list()` confirmed: add xfail + impl for "fetch latest event timestamp and compute `idle = now - latest.created_at`". **AI-min: 30.**
  - **Case (c)** — neither available: add xfail + impl for Service-1-maintained `lastActivityAt` — written ONLY by SSE event handler in `main.py`; read ONLY by `ManagedSessionMonitor`. BD amendment §2.4 pre-conditions mandatory: (1) spike documents why (a) and (b) are unworkable (MAL.0.1); (2) writer scoping; (3) reader scoping; (4) SE.A.4 `Session` dataclass appends the field (coordinate with Kayn → SE task file amendment in same PR). **AI-min: 60 (15 test + 45 impl).** <!-- orianna: ok -->
- **Acceptance:** scan uses a deterministic idle value regardless of spike outcome.
- **Commit sequence (cases b/c):** `chore: add xfail test for idle-resolution fallback (MAL.D.4 test)` + `feat(demo-studio-v3): idle-resolution fallback per Spike 1 case X (MAL.D.4 impl)`.
- **TDD:** paired xfail (cases b/c only).
- **Depends on:** MAL.0.1. Case (c) also on SE.A.4.
- **AI-min:** 30 (budget midpoint; adjust at dispatch).

---

## Phase MAL.E — Slack warning/termination messaging

### MAL.E.1 — xfail: Slack message formatting + enrichment states (TEST)
- **What:** new `tools/demo-studio-v3/tests/test_monitor_slack_format.py`. Render each variant (warn, orphan warn, termination) with mocked enrichment per BD amendment §2.2. Tests assert exact string shape for: <!-- orianna: ok -->
  1. Success enrichment (brand + user + channel all resolve).
  2. Cold-session (S2 returns 404) → `(config not yet set, …)` variant per ADR §5.
  3. S2-unavailable (5xx) → `(brand unavailable, …)` variant; `slack_enrichment_degraded` log emitted.
  4. Orphan (no Firestore row) → orphan variant.
  5. Termination on kill.
- **Forbidden literal:** the string `insuranceLine` must NOT appear in any format string, test assertion, or fixture (BD §2 Rule 4 + BDC-MAL-2 + grep-gate).
- **Acceptance:** xfail strict — helpers don't exist.
- **Commit:** `chore: add xfail tests for ManagedSessionMonitor Slack format (MAL.E.1)`.
- **TDD:** xfail commit for MAL.E.2.
- **Depends on:** MAL.D.2.
- **AI-min:** 25.

### MAL.E.1b — CI: grep-gate self-check for `insuranceLine` (CI WIRING)
- **What:** extend the grep-gate config (SE.E.2 produces it) so CI asserts the literal `insuranceLine` is absent from every non-test, non-migration file under `tools/demo-studio-v3/`. Pairs with SE.E.2's gate — prefer editing SE.E.2's allow-list/deny-list config file over duplicating. If SE.E.2 hasn't landed, add a standalone check `scripts/grep-gate-insurance-line.sh` and wire to CI; retire it when SE.E.2 absorbs the rule. <!-- orianna: ok -->
- **Acceptance:** CI fails if `insuranceLine` appears in any non-test / non-migration file under `tools/demo-studio-v3/`. <!-- orianna: ok -->
- **Commit:** `chore(demo-studio-v3): grep-gate CI check for insuranceLine literal (MAL.E.1b)`.
- **TDD:** N/A — CI wiring.
- **Depends on:** ideally SE.E.2 (consolidates allow-lists); can ship standalone.
- **AI-min:** 20.

### MAL.E.2 — impl: Slack formatting + two-source enrichment (BUILDER)
- **What:** add `_format_warning`, `_format_orphan_warning`, `_format_termination` helpers in `managed_session_monitor.py`. Enrichment helper makes TWO calls in parallel via `asyncio.gather(..., return_exceptions=True)`: <!-- orianna: ok -->
  - (a) `session_store.get_session(sessionId)` → `userEmail`, `slackChannel`, `slackThreadTs`, `slackUserId`.
  - (b) `config_mgmt_client.fetch_config(sessionId)` → `brand`.
  Returns `SlackEnrichment` struct with `brand: str | None`:
  - `None` from 404 → render "config not yet set".
  - `None` from 5xx → render "brand unavailable", emit `slack_enrichment_degraded` log.
  - Firestore row missing → orphan variant (no S2 call needed).
- **BD grep-gate:** `config_mgmt_client` import is permitted in this module per BD §3.14 allow-set. Add `# azir: config-boundary` comment on the import line. Update the consolidated allow-set (ADR §"Grep-gate allow-set" list) in SE.E.2 if it needs edit in the same PR.
- **Acceptance:** MAL.E.1 tests pass. `insuranceLine` absent from all scanner code paths (MAL.E.1b green).
- **Commit:** `feat(demo-studio-v3): Slack enrichment + formatting helpers (MAL.E.2)`.
- **TDD:** preceded by MAL.E.1.
- **Depends on:** MAL.E.1, BD (`config_mgmt_client.fetch_config`).
- **AI-min:** 35.

### MAL.E.3 — impl: wire monitor → slack-relay MCP (BUILDER)
- **What:** add `post_slack(channel, message)` helper that calls existing `slack-relay` MCP client. Monitor invokes on warn / orphan / terminate branches. Thin wrapper.
- **Acceptance:** integration test MAL.H.2 exercises the path. If MAL.0.2 locked the `#demos` fallback, default is still correct (env var drives it).
- **Commit:** `feat(demo-studio-v3): wire monitor to slack-relay MCP (MAL.E.3)`.
- **TDD:** exempt — covered by MAL.H.1 event assertions + MAL.H.2 integration.
- **Depends on:** MAL.E.2, MAL.0.2.
- **AI-min:** 15.

---

## Phase MAL.F — FastAPI startup/shutdown wiring

### MAL.F.1 — xfail: monitor lifecycle binding (TEST)
- **What:** new `tools/demo-studio-v3/tests/test_monitor_lifecycle_wiring.py`. Tests: <!-- orianna: ok -->
  1. FastAPI `startup` event instantiates `ManagedSessionMonitor` and schedules `run_forever()` as asyncio background task.
  2. `shutdown` event cancels the task cleanly (awaits cancellation; no pending-task warning).
  3. When `MANAGED_SESSION_MONITOR_ENABLED=false`, startup does NOT schedule the task.
- **Acceptance:** xfail strict against current `main.py`. <!-- orianna: ok -->
- **Commit:** `chore: add xfail tests for monitor lifecycle wiring (MAL.F.1)`.
- **TDD:** xfail commit for MAL.F.2.
- **Depends on:** MAL.D.2.
- **AI-min:** 20.

### MAL.F.2 — impl: wire monitor startup/shutdown in main.py (BUILDER)
- **What:** add startup + shutdown handlers in `tools/demo-studio-v3/main.py`. Respect `MANAGED_SESSION_MONITOR_ENABLED` env var. Kill-switch path per ADR §6 last row. <!-- orianna: ok -->
- **Acceptance:** MAL.F.1 passes.
- **Commit:** `feat(demo-studio-v3): wire ManagedSessionMonitor startup/shutdown (MAL.F.2)`.
- **TDD:** preceded by MAL.F.1.
- **Depends on:** MAL.F.1, MAL.D.3, MAL.G.2.
- **AI-min:** 25.

---

## Phase MAL.G — Config plumbing + startup invariant

### MAL.G.1 — xfail: `MonitorConfig.from_env()` + invariant (TEST)
- **What:** new `tools/demo-studio-v3/tests/test_monitor_config.py`. Tests: <!-- orianna: ok -->
  1. Reads each ADR §6 env var; applies documented defaults.
  2. `IDLE_WARN_MINUTES >= IDLE_TERMINATE_MINUTES` raises `ConfigError`.
  3. `SCAN_INTERVAL_SECONDS < 60` raises `ConfigError`.
  4. `MANAGED_SESSION_MONITOR_ENABLED` accepts `true/false/1/0` case-insensitive. <!-- orianna: ok -->
- **Acceptance:** xfail strict — `from_env` not implemented.
- **Commit:** `chore: add xfail tests for MonitorConfig.from_env (MAL.G.1)`.
- **TDD:** xfail commit for MAL.G.2.
- **Depends on:** MAL.D.2.
- **AI-min:** 15.

### MAL.G.2 — impl: `MonitorConfig.from_env()` + invariant (BUILDER)
- **What:** body `from_env()` classmethod on `MonitorConfig`. Raise `ConfigError(ValueError)` on invariant violation. Log loaded config at startup (redact nothing — no secrets here).
- **Acceptance:** MAL.G.1 passes. Startup fails fast on misconfig.
- **Commit:** `feat(demo-studio-v3): MonitorConfig.from_env with invariant (MAL.G.2)`.
- **TDD:** preceded by MAL.G.1.
- **Depends on:** MAL.G.1.
- **AI-min:** 25.

---

## Phase MAL.H — Observability + integration test

### MAL.H.1 — TEST: structured-log event assertions (TEST)
- **What:** new `tools/demo-studio-v3/tests/test_monitor_observability.py`. Assert every ADR §10 event type fires exactly once per triggering condition via `caplog` + JSON extractor: <!-- orianna: ok -->
  - `managed_session_warned`
  - `managed_session_terminated`
  - `orphan_terminated`
  - `scan_cycle_complete` (with counts)
  - `terminal_hook_failed`
  - `terminal_hook_skipped_no_managed_session`
  - `slack_enrichment_degraded` (added per BD amendment §2.5 / §4 item 6)
  - `managed_session_stop_timeout` (from MAL.A.4)
- **Acceptance:** all log events discoverable by `event_type`.
- **Commit:** `test(demo-studio-v3): observability event assertions for managed-agent lifecycle (MAL.H.1)`.
- **TDD:** test-only; lands after MAL.B.2 + MAL.D.3 + MAL.E.2.
- **Depends on:** MAL.B.2, MAL.D.3, MAL.E.2.
- **AI-min:** 25.

### MAL.H.2 — TEST: integration against real Anthropic SDK (TEST)
- **What:** new `tools/demo-studio-v3/tests/integration/test_stop_managed_session_integration.py` (`@pytest.mark.integration`). Flow: create a throwaway managed session via Anthropic SDK → assert `idle` → call `stop_managed_session` → assert `retrieve()` returns `terminated` (or raises `NotFoundError`). Skip when `ANTHROPIC_API_KEY` absent. S2 stubbed at integration boundary — do NOT hit real S2 (BD amendment §2.5). <!-- orianna: ok -->
- **Acceptance:** test green locally with a real API key; CI skips cleanly when unset.
- **Commit:** `test(demo-studio-v3): integration — stop_managed_session against real Anthropic (MAL.H.2)`.
- **TDD:** exempt — additive integration.
- **Depends on:** MAL.A.4.
- **AI-min:** 40.

---

## TDD pairing summary

Every impl BUILDER task is preceded on-branch by an xfail TEST commit per Rule 12.

| xfail TEST | impl BUILDER |
| --- | --- |
| MAL.A.1 | MAL.A.2 |
| MAL.A.3 | MAL.A.4 |
| MAL.B.1 | MAL.B.2 |
| MAL.C.1 | MAL.C.2 |
| MAL.C.3 (test half) | MAL.C.3 (impl half) |
| MAL.D.1 | MAL.D.2 |
| MAL.D.1 | MAL.D.3 |
| MAL.D.4 (test) | MAL.D.4 (impl) — cases b/c only |
| MAL.E.1 | MAL.E.2 |
| MAL.G.1 | MAL.G.2 |
| MAL.F.1 | MAL.F.2 |

Exempt (no paired impl or impl covered by other pair):
- MAL.0.1 / MAL.0.2 (research/ops errands, no code).
- MAL.E.1b (CI wiring).
- MAL.E.3 (thin wrapper; covered by H.1 + H.2).
- MAL.H.1 / MAL.H.2 (test-only tasks).

**TDD pair count: 11** paired test/impl commits (counting MAL.C.3 and MAL.D.4 once each).

---

## Risks & mitigations

1. **MAL.0.1 spike returns case (c) — Service-1-maintained `lastActivityAt`.** Reintroduces DB-drift risk for the scanner's core input (ADR §3 "real risk"). Mitigated by BD amendment §2.4 pre-conditions: field is pure-lifecycle, writer-scoped to SSE handler, reader-scoped to monitor, SE.A.4 dataclass extension. If pre-conditions can't be met on branch, escalate to Duong before MAL.D.4 impl starts.
2. **SE slippage past Wave 1.** Eager path unships (MAL.B parks). Scanner alone still achieves "kill within 2h idle". Acceptable degradation — named in ADR §10 handoff.
3. **BD slippage past Wave 1.** `config_mgmt_client.fetch_config` absent. Mitigation: MAL.E.2 stubs the client to raise 5xx, rendering `brand unavailable` on every alert. Scanner ships; alerts are noisy but not broken. BD §3.14 allow-set coordination (ADR "Grep-gate allow-set" section) moves to a follow-up.
4. **Single-instance scanner assumption (ADR §4).** Cloud Run configured `--min-instances=1 --max-instances=1`. If ops scales out, monitor collisions are safe (deletes idempotent) but warnings duplicate. Mitigation flagged in ADR §4; out of scope here.
5. **Dedup cache in-memory loss on restart.** One extra Slack line per already-warned session per Cloud Run restart. Acceptable per ADR §7.
6. **`#demo-studio-alerts` channel absent.** MAL.0.2 either secures invite or falls back to `#demos` prefix. Fallback is already wired via env var — no code-path risk.

---

## Open questions (OQ-MAL-*)

Mirroring the ADR's own list for Kayn-side traceability:

### OQ-MAL-1 — Idle-timestamp source — OPEN
Resolved by MAL.0.1 spike. Gates MAL.D.4 shape + MAL.A.3/A.4 interrupt semantics.

### OQ-MAL-2 — Slack channel default — OPEN
Resolved by MAL.0.2. `#demo-studio-alerts` vs `[alert]`-prefixed `#demos`. Ops/Duong decides; no impl impact (env var drives it).

### OQ-MAL-3 — Terminate managed sessions on Service 1 SIGTERM — OPEN / LEAN NO
ADR §9 Q3 leans do NOT. Not tasked here. If Duong overrides, add a MAL.F.3 task for a SIGTERM handler reaping active sessions via the primitive.

### OQ-MAL-4 — Slack enrichment source — RESOLVED
Resolved by BD amendment §2.1/§2.2. Two-source join: Firestore (slack/user) + S2 (brand). Implemented in MAL.E.2.

### OQ-MAL-5 — `lastActivityAt` S1-maintained fallback — CONDITIONALLY RESOLVED
Resolved by BD amendment §2.4 with four pre-conditions. Triggered only if MAL.0.1 returns case (c). MAL.D.4 is the landing spot.

### OQ-MAL-6 — `cancel_reason` kwarg on `transition_status` — RESOLVED
Per ADR amendment pointer: SE.A.6 amended to `transition_status(session_id, to_status, *, cancel_reason: str | None = None)` (matches OQ-MAD-1 resolution, keeps MAD.C and MAL.D.3 / MAL.B.2 call sites consistent). No Kayn action remaining; MAL.B.2 and MAL.D.3 use the kwarg directly.

---

## Semantic gaps / ADR touch-points surfaced during breakdown

1. **MAL.D.4 AI-min budget is spike-outcome-dependent (0 / 30 / 60).** The phase-summary estimate uses case (b) = 30 as the midpoint. Adjust at dispatch once MAL.0.1 lands. Flagged to Evelynn because it can swing the total by ±30 AI-min.
2. **MAL.E.1b grep-gate ownership.** The `insuranceLine` deny-rule logically belongs in SE.E.2's consolidated grep-gate config, but MAL may land before SE.E.2 if Wave ordering shifts. Task text allows either location; Camille will deduplicate when SE.E.2 lands. Cross-ADR coupling noted.
3. **Grep-gate allow-set consolidation.** ADR §"Grep-gate allow-set" list names four files that may import `config_mgmt_client` (main, factory_bridge*, managed_session_monitor, dashboard handler). This list must be merged with SE.E.2's authoritative config and MAD.E.1's allow-list check. Flagged — no single task owns the consolidation; propose Camille take it in SE.E.2 acceptance.
4. **`managedSessionId` shape on Firestore session doc.** MAL.B.2 assumes `session["managedSessionId"]` key exists on the SE-owned dataclass. If SE.A.4's `Session` dataclass names it differently (`managed_session_id`?), MAL.B.2 adapts at impl time. Non-blocking — signature confirmed at MAL.B.2 kickoff against SE.A.4 landed code.
5. **Scanner retry/backoff on Anthropic rate-limit.** ADR §6 says 600/min org-wide is "comfortably safe". Not tasked. If observed rate-limit hits in staging, MAL.D.3 needs a bounded-concurrency semaphore — flagged as follow-up, NOT in scope here.
6. **MAL.D.4 case (c) SE.A.4 coordination.** If case (c) lands, Kayn must amend `plans/approved/work/2026-04-20-session-state-encapsulation-tasks.md` SE.A.4 in-band to append `lastActivityAt: datetime | None` to the `Session` dataclass before MAL.D.4 impl merges. Non-blocking for eager path; cross-plan edit needed in the same PR or a gating commit. <!-- orianna: ok -->

---

## Test plan

Three-layer plan from ADR §10, materialised into task pairs:

- **I1 — `stop_managed_session` idempotency** — MAL.A.1 / A.2 (idle delete, 404 swallow, idempotency, logging); MAL.A.3 / A.4 (interrupt-before-delete, 5s timeout).
- **I2 — `ManagedSessionMonitor` decision matrix** — MAL.D.1 / D.2 / D.3 (all four outcomes + agent filter + scan cycle log + dedup); MAL.D.4 (spike-dependent fallback).
- **I3 — Slack enrichment coverage** — MAL.E.1 / E.2 (all three enrichment states: success / 404 cold / 5xx degraded) + MAL.E.1b (grep-gate).
- **I4 — Integration against real Anthropic SDK** — MAL.H.2 (throwaway session; S2 stubbed per BD amendment §2.5).
- **Observability** — MAL.H.1 (all eight event types).
- **Regression** — MAL.C.1 (`/cancel-build` byte-equivalence) + MAL.C.3 (`/close` byte-equivalence) per Rule 13.

---

## Handoff

- **Sona (work coordinator):** dispatch MAL.0.1 + MAL.0.2 first (Wave 0). Results gate Wave 1 scanner spine. Eager spine (A/B/C) can also start Wave 1 in parallel — it only needs the Spike 1 appendix for MAL.A.3 interrupt semantics, so consider scheduling MAL.A.1/A.2 concurrently with Spike 1 and blocking MAL.A.3 on spike landing.
- **Kayn follow-ups:**
  - If MAL.0.1 returns case (c), amend `plans/approved/work/2026-04-20-session-state-encapsulation-tasks.md` SE.A.4 before MAL.D.4 impl starts (add `lastActivityAt: datetime | None` to `Session` dataclass). <!-- orianna: ok -->
  - Reconcile grep-gate allow-set with SE.E.2 + MAD.E.1 when both land — if SE.E.2 hasn't absorbed MAL.E.1b, promote the rule into SE.E.2's config.
- **Caitlyn (tester):** three layers per ADR §10 + observability + regression. MAL.H.1 is the single unified observability-event test to own.
- **Camille (grep-gate):** MAL.E.1b adds / consolidates the `insuranceLine` deny-rule. Coordinates with SE.E.2 allow-list.
- **Orianna:** no new fact-check hooks in this breakdown. BD amendment's six flagged facts (Azir's earlier scan) are the relevant fact-checks; not re-checked here.
- **Evelynn / dispatch:** flag MAL.D.4 AI-min re-budget at MAL.0.1 close (±30).
**Repo:** `missmp/company-os`, all work under `tools/demo-studio-v3/`. <!-- orianna: ok — cross-repo path prefix; all tools/demo-studio-v3/ refs in this Tasks section refer to missmp/company-os --> <!-- orianna: ok -->
**Sister plans on the same branch:**
- `plans/proposed/work/2026-04-20-session-state-encapsulation.md` (SE) <!-- orianna: ok — sibling plan; session-state-encapsulation tasks are inlined in that plan per one-plan-one-file rule --> — provides `session_store.py` <!-- orianna: ok — company-os module under missmp/company-os/tools/demo-studio-v3/ --> and `session_store.transition_status`. MAL's terminal-state hook (ADR §2.1) plugs into SE.A.6 `transition_status`. <!-- orianna: ok -->
- `plans/approved/work/2026-04-20-s1-s2-service-boundary.md` (BD — approved) — S1 is session-lifecycle + agent-hosting only. Identity fields (`brand`, `market`, `languages`, `shortcode`) are NOT on the S1 session doc. <!-- orianna: ok -->

**TDD gate active:** every impl task must be preceded on the same branch by an xfail test commit referencing the task ID. Pre-push hook enforces; agents may not bypass.
**Regression-test rule:** the refactor of `/cancel-build` <!-- orianna: ok — HTTP route name, not a filesystem path --> (MAL.C.2) must carry a paired regression test (see MAL.C.1) per universal invariant 13 — behaviour must be preserved end-to-end.
**Conventional-commit prefix:** impl commits under `tools/demo-studio-v3/**` <!-- orianna: ok — glob pattern referring to missmp/company-os/tools/demo-studio-v3/; not a local filesystem path --> use `feat:` / `refactor:` / `fix:`; test-only commits use `chore:`; plan edits use `chore:`. <!-- orianna: ok -->

### Scope and sequencing rationale

This decomposition translates ADR §2–§7 into pairwise TDD tasks. The ADR is explicit that Spike 1 (SDK gap confirmation, §3+§4) gates all implementation work — idle-detection design is not decidable until Q1 is answered. MAL.0 is therefore not optional: it produces the appendix that unblocks MAL.D.

The work splits into two sub-ADRs that ship independently:
- **Eager path (MAL.A + MAL.B + MAL.C):** terminal-state cleanup. Shippable without the scanner. Depends on SE.A.6 (`transition_status`).
- **Safety-net path (MAL.D + MAL.E + MAL.F + MAL.G):** in-process `ManagedSessionMonitor`. Shippable behind `MANAGED_SESSION_MONITOR_ENABLED=false` kill-switch regardless of eager path state.

### Task ID scheme

- `MAL.0.*` — preflight (SDK spike, Slack bot membership check)
- `MAL.A.*` — `stop_managed_session` primitive in `agent_proxy.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ --> <!-- orianna: ok -->
- `MAL.B.*` — terminal-state hook in `session_store.transition_status`
- `MAL.C.*` — refactor `/cancel-build` <!-- orianna: ok — HTTP route name --> and `/close` <!-- orianna: ok — HTTP route name --> call sites to use the primitive
- `MAL.D.*` — `ManagedSessionMonitor` class (scan loop, dedup cache, decision logic)
- `MAL.E.*` — Slack warning/termination messaging
- `MAL.F.*` — `main.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ --> startup/shutdown wiring <!-- orianna: ok -->
- `MAL.G.*` — config plumbing + startup invariant check
- `MAL.H.*` — integration tests + observability

---

### MAL.0 — Preflight

#### MAL.0.1 — Spike 1: confirm Anthropic SDK surface for list + retrieve + events
- **What:** read the installed `anthropic` Python package source and produce a 1-page appendix covering ADR §3 table rows (a), (b), (c). Attach findings as `company-os/plans/2026-04-20-managed-agent-lifecycle-spike1.md` <!-- orianna: ok — future artefact in missmp/company-os, not yet created -->. Budget: estimate_minutes: 120. <!-- orianna: ok -->
- **Where:** new file `company-os/plans/2026-04-20-managed-agent-lifecycle-spike1.md`. <!-- orianna: ok — future file; does not exist until Kayn runs the spike --> <!-- orianna: ok -->
- **Why:** ADR §3 "Blocker assessment" — Gap (b) is the real risk.
- **Acceptance:** appendix documents each of the three rows with one of: (i) exact SDK surface confirmed, (ii) a named fallback, (iii) a blocker requiring a Duong/Azir decision.
- **TDD:** exempt — research artefact, no code change.
- **Depends on:** none.

#### MAL.0.2 — Confirm `#demo-studio-alerts` Slack channel + bot membership
- **What:** verify the target Slack channel exists and that the `slack-relay` <!-- orianna: ok — internal MCP server name in missmp/company-os --> MCP bot is a member. If not, either request invite or fall back to `#demos` with `[alert]` prefix per ADR §5 fallback.
- **Where:** append finding to `company-os/plans/2026-04-20-managed-agent-lifecycle-spike1.md`. <!-- orianna: ok — same future file as MAL.0.1 --> <!-- orianna: ok -->
- **Why:** ADR §5 / Q2. Without bot membership, MAL.E.2 fails silently in prod.
- **Acceptance:** channel name locked in for `SLACK_ALERT_CHANNEL` default; bot membership confirmed or fallback chosen.
- **TDD:** exempt — ops confirmation, no code change.
- **Depends on:** none.

---

### MAL.A — `stop_managed_session` primitive

Merges independently. Pure additive; no call-site changes yet.

#### MAL.A.1 — xfail tests for `stop_managed_session` idempotency + 404 swallow
- **What:** create `tools/demo-studio-v3/tests/test_stop_managed_session.py` <!-- orianna: ok — company-os future test file --> with four tests covering: delete on idle status, 404 swallow, idempotent second call, outcome logging. <!-- orianna: ok -->
- **Where:** new test file in `missmp/company-os` <!-- orianna: ok — GitHub org/repo name, not a filesystem path; test file lives in missmp/company-os/tools/demo-studio-v3/tests/ -->. <!-- orianna: ok -->
- **Why:** ADR §4 module shape — locks the idempotency contract before impl.
- **Acceptance:** tests import `agent_proxy.stop_managed_session` and fail with `AttributeError` or `ImportError`. Marked `@pytest.mark.xfail(reason="MAL.A.2", strict=True)`.
- **TDD:** xfail commit for MAL.A.2.
- **Depends on:** none.

#### MAL.A.2 — Implement `stop_managed_session` idempotent delete path
- **What:** add `async def stop_managed_session(session_id: str, reason: str = "") -> bool` in `tools/demo-studio-v3/agent_proxy.py` <!-- orianna: ok — company-os file -->. Signature and docstring verbatim from ADR §4. For the simple path (non-running status): call `client.beta.sessions.delete(session_id)`. Swallow `NotFoundError` → return `False`. Log success as structured event `managed_session_terminated` with `reason` field. <!-- orianna: ok -->
- **Where:** `tools/demo-studio-v3/agent_proxy.py`. <!-- orianna: ok — company-os file; missmp/company-os/tools/demo-studio-v3/agent_proxy.py --> <!-- orianna: ok -->
- **Why:** ADR §4 — primitive owned by `agent_proxy`, not `main.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ -->. Module boundary is load-bearing per ADR §10 handoff. <!-- orianna: ok -->
- **Acceptance:** MAL.A.1 tests 1, 2, 3, 4 pass.
- **TDD:** preceded by MAL.A.1.
- **Depends on:** MAL.A.1.

#### MAL.A.3 — xfail tests for interrupt-before-delete on `running` status
- **What:** extend `test_stop_managed_session.py` <!-- orianna: ok — company-os future test file under missmp/company-os/tools/demo-studio-v3/tests/ --> with tests covering: interrupt event sent before delete on running status, retry after delete error on running, 5s timeout. <!-- orianna: ok -->
- **Where:** same file as MAL.A.1.
- **Why:** ADR §3 Gap (c) + §4 "5s timeout matching `cancel_build` pattern".
- **Acceptance:** new tests fail (impl does not yet send interrupt); xfail/strict → MAL.A.4. Exact interrupt SDK call comes from MAL.0.1 spike appendix.
- **TDD:** xfail commit for MAL.A.4.
- **Depends on:** MAL.A.2, MAL.0.1.

#### MAL.A.4 — Implement interrupt-before-delete + 5s timeout
- **What:** extend `stop_managed_session` to: (i) call `retrieve(session_id)` first; (ii) if `status == "running"`, send interrupt event per spike appendix, then delete; (iii) wrap the whole call in `asyncio.wait_for(..., timeout=5.0)`; (iv) on timeout, log `managed_session_stop_timeout` and return `False`.
- **Where:** `tools/demo-studio-v3/agent_proxy.py`. <!-- orianna: ok — company-os file --> <!-- orianna: ok -->
- **Why:** ADR §3 Gap (c), §4 timeout requirement.
- **Acceptance:** MAL.A.3 tests all pass.
- **TDD:** preceded by MAL.A.3.
- **Depends on:** MAL.A.3.

---

### MAL.B — Terminal-state hook in `session_store.transition_status`

Depends on SE.A.6 (`session_store.transition_status` exists). If SE slips, MAL.B parks; eager path unavailable and scanner alone ships per ADR §10.

#### MAL.B.1 — xfail test for terminal-state hook invocation
- **What:** create `tools/demo-studio-v3/tests/test_transition_status_terminal_hook.py` <!-- orianna: ok — company-os future test file -->. Tests covering: hook called on transition to each terminal status in `{completed, cancelled, qc_failed, build_failed, built}`; hook NOT called on transition to non-terminal status; hook failure does not block the transition; 5s timeout bound. <!-- orianna: ok -->
- **Where:** new test file in `missmp/company-os` <!-- orianna: ok — GitHub org/repo name, not a filesystem path; test file lives in missmp/company-os/tools/demo-studio-v3/tests/ -->. <!-- orianna: ok -->
- **Why:** ADR §2.1 + §4 "post-commit hook … wrapped in a per-call timeout".
- **Acceptance:** tests fail because the hook does not exist yet; xfail/strict → MAL.B.2.
- **TDD:** xfail commit for MAL.B.2.
- **Depends on:** SE.A.6 (`transition_status` implemented).

#### MAL.B.2 — Wire post-commit hook inside `transition_status`
- **What:** modify `tools/demo-studio-v3/session_store.py::transition_status` <!-- orianna: ok — company-os file --> so that, after a successful Firestore CAS commit, if `to_status` is in the terminal set, it awaits `agent_proxy.stop_managed_session(session["managedSessionId"], reason=f"transition_to_{to_status}")`. Guard against: (a) `managedSessionId is None` — skip hook, log `terminal_hook_skipped_no_managed_session`; (b) hook exception — swallow + log `terminal_hook_failed`; (c) 5s timeout per MAL.A.4 already inside `stop_managed_session`. Hook is post-commit — a hook failure cannot roll back the transition. <!-- orianna: ok -->
- **Where:** `tools/demo-studio-v3/session_store.py`. <!-- orianna: ok — company-os file --> <!-- orianna: ok -->
- **Why:** ADR §2.1 eager cleanup.
- **Acceptance:** MAL.B.1 tests all pass. `transition_status` signature unchanged. SE task-file's existing `transition_status` tests still pass.
- **TDD:** preceded by MAL.B.1.
- **Depends on:** MAL.B.1, MAL.A.4, SE.A.6.

---

### MAL.C — Refactor `/cancel-build` <!-- orianna: ok — HTTP route name --> and `/close` <!-- orianna: ok — HTTP route name --> to use primitive

Both routes currently inline `_client.beta.sessions.delete(...)`. Refactor to call `agent_proxy.stop_managed_session`. Required for DRY and so the interrupt-before-delete behaviour (MAL.A.4) applies uniformly.

#### MAL.C.1 — Regression test for `/cancel-build` <!-- orianna: ok — HTTP route name --> equivalence
- **What:** add `tests/test_cancel_build_uses_stop_primitive.py` <!-- orianna: ok — future company-os test; path relative to tools/demo-studio-v3/ -->. Tests assert (i) `POST /session/{id}/cancel-build` <!-- orianna: ok — HTTP route, not a filesystem path --> still returns 200 on `building` status, still sets `_stop_flags[session_id] = True`, still deletes the managed session — but now via `agent_proxy.stop_managed_session` (mock target moves from `main.Anthropic` / `_client.beta.sessions.delete` to `main.stop_managed_session`); (ii) the response body is byte-identical to the pre-refactor baseline; (iii) 5s timeout behaviour preserved. <!-- orianna: ok -->
- **Where:** new test file.
- **Why:** universal invariant 13 — refactor touching the stop path needs a regression test.
- **Acceptance:** tests xfail against current inline-delete code; xfail/strict → MAL.C.2.
- **TDD:** xfail + regression commit for MAL.C.2.
- **Depends on:** MAL.A.2.

#### MAL.C.2 — Refactor `/cancel-build` <!-- orianna: ok — HTTP route name --> handler to call `stop_managed_session`
- **What:** in `tools/demo-studio-v3/main.py` <!-- orianna: ok — company-os file --> around lines 2084–2120, replace the inline `_client.beta.sessions.delete(managed_session_id)` block with `await stop_managed_session(managed_session_id, reason="cancel_build")`. Keep the 5s timeout (now enforced inside the primitive). Remove the local `_client` construction if no longer used at that call site. <!-- orianna: ok -->
- **Where:** `tools/demo-studio-v3/main.py`. <!-- orianna: ok — company-os file --> <!-- orianna: ok -->
- **Why:** ADR §10 handoff. DRY with scanner path and MAL.B hook.
- **Acceptance:** MAL.C.1 passes. Pre-existing `tests/test_stop_build_phase.py` <!-- orianna: ok — pre-existing company-os test file; path relative to tools/demo-studio-v3/ --> passes after mock-target rewrite. <!-- orianna: ok -->
- **TDD:** preceded by MAL.C.1.
- **Depends on:** MAL.C.1.

#### MAL.C.3 — Regression test + refactor for `/close` <!-- orianna: ok — HTTP route name --> (line 2204 inline delete)
- **What:** same pattern as MAL.C.1+C.2 but for the `/session/{id}/close` <!-- orianna: ok — HTTP route, not a filesystem path --> route at `main.py:2204`. One xfail regression test + one impl commit.
- **Where:** new test `tests/test_close_uses_stop_primitive.py`; edit `tools/demo-studio-v3/main.py:2200–2215` area. <!-- orianna: ok — company-os file paths --> <!-- orianna: ok -->
- **Why:** same as MAL.C.2 — DRY and timeout uniformity.
- **Acceptance:** regression test passes; `test_stop_and_archive.py` <!-- orianna: ok — pre-existing company-os test file relative to tools/demo-studio-v3/tests/ --> mock-target rewritten and passing. <!-- orianna: ok -->
- **TDD:** xfail-paired test commit precedes impl.
- **Depends on:** MAL.A.2. Independent of MAL.C.2.

---

### MAL.D — `ManagedSessionMonitor` class

#### MAL.D.1 — xfail tests for `ManagedSessionMonitor` decision matrix
- **What:** create `tools/demo-studio-v3/tests/test_managed_session_monitor.py` <!-- orianna: ok — company-os future test file -->. Stubbed Anthropic SDK + stubbed clock. Parametric cases: idle < warn → no-op; warn ≤ idle < terminate → one Slack warning; idle ≥ terminate → stop + Slack + Firestore transition; no Firestore row (orphan) → stop + orphan Slack; agent filter: only acts on `MANAGED_AGENT_ID` ones; scan cycle logs `scan_cycle_complete`. <!-- orianna: ok -->
- **Where:** new test file in `missmp/company-os` <!-- orianna: ok — GitHub org/repo name, not a filesystem path; test file lives in missmp/company-os/tools/demo-studio-v3/tests/ -->. <!-- orianna: ok -->
- **Why:** ADR §2.2 + §10 test strategy layer (ii).
- **Acceptance:** tests fail because class does not exist; xfail/strict → MAL.D.2 + D.3.
- **TDD:** xfail commit for MAL.D.2 and MAL.D.3.
- **Depends on:** MAL.0.1.

#### MAL.D.2 — Implement `ManagedSessionMonitor` class scaffold + TTL dedup cache
- **What:** create `tools/demo-studio-v3/managed_session_monitor.py` <!-- orianna: ok — company-os future file --> with: Class `ManagedSessionMonitor(client, session_store, slack_relay, config: MonitorConfig)`, TTL dedup cache, Config dataclass `MonitorConfig` with fields from ADR §6, `async def run_forever()` loop, `async def scan_once()` — empty stub. <!-- orianna: ok -->
- **Where:** new file `tools/demo-studio-v3/managed_session_monitor.py`. <!-- orianna: ok — company-os future file --> <!-- orianna: ok -->
- **Why:** ADR §4 module shape.
- **Acceptance:** import tests pass; `run_forever` cancels on `asyncio.CancelledError`. MAL.D.1 tests still xfail (scan logic empty). <!-- orianna: ok -->
- **TDD:** preceded by MAL.D.1.
- **Depends on:** MAL.D.1.

#### MAL.D.3 — Implement `scan_once()` decision logic
- **What:** body out `scan_once()` per ADR §2.2. For each active session: (i) resolve idle duration via the mechanism chosen in MAL.0.1; (ii) apply decision matrix from MAL.D.1; (iii) for terminations call `agent_proxy.stop_managed_session` + attempt `session_store.transition_status(..., to_status="cancelled", cancel_reason="idle_timeout")` — swallow transition failure, Anthropic is authoritative; (iv) emit `scan_cycle_complete` log with counts.
- **Where:** `tools/demo-studio-v3/managed_session_monitor.py` <!-- orianna: ok — company-os future file under missmp/company-os/tools/demo-studio-v3/ -->. <!-- orianna: ok -->
- **Why:** ADR §2.2, §2.3.
- **Acceptance:** MAL.D.1 tests all pass.
- **TDD:** preceded by MAL.D.1.
- **Depends on:** MAL.D.2, MAL.A.4, SE.A.6.

#### MAL.D.4 — xfail test + impl for idle-timestamp resolution fallback
- **What:** depending on MAL.0.1 outcome, one of:
  - (a) spike confirms `retrieve().last_activity_at` — no fallback task needed; fold into MAL.D.3.
  - (b) spike confirms `events.list()` — add xfail + impl for "fetch latest event timestamp and compute idle = now - latest.created_at".
  - (c) spike shows neither — add xfail + impl for "Service-1-maintained `lastActivityAt` on every inbound SSE event in Service 1, write to session doc via `session_store.update_session`". **BD-consistency note:** permitted as a pure lifecycle field (per BD amendment §2.4 pre-conditions) if spike returns (c).
- **Where:** either `managed_session_monitor.py` <!-- orianna: ok — company-os future file under missmp/company-os/tools/demo-studio-v3/ --> (cases a/b) or `agent_proxy.py` <!-- orianna: ok — company-os file --> + `main.py` <!-- orianna: ok — company-os file --> SSE proxy (case c). <!-- orianna: ok -->
- **Why:** ADR §3 Gap (b) is the real risk.
- **Acceptance:** scan uses a deterministic idle value regardless of spike outcome.
- **TDD:** paired xfail test.
- **Depends on:** MAL.0.1.

---

### MAL.E — Slack warning/termination messaging

#### MAL.E.1 — xfail tests for Slack message formatting
- **What:** `tools/demo-studio-v3/tests/test_monitor_slack_format.py` <!-- orianna: ok — company-os future test file -->. Tests render each of the message variants (warn, orphan warn, termination) with mocked enrichment data per BD amendment §2.2 field sources. Tests assert exact string shape. The literal `insuranceLine` must NOT appear in any format string or test assertion (BD grep-gate compliance). <!-- orianna: ok -->
- **Where:** new test file in `missmp/company-os` <!-- orianna: ok — GitHub org/repo name, not a filesystem path; test file lives in missmp/company-os/tools/demo-studio-v3/tests/ -->. <!-- orianna: ok -->
- **Why:** ADR §5 message shape, as amended by BD amendment §2.2.
- **Acceptance:** tests fail — formatting helpers don't exist yet; xfail/strict → MAL.E.2.
- **TDD:** xfail commit for MAL.E.2.
- **Depends on:** MAL.D.2.

#### MAL.E.1b — Grep-gate self-check for `insuranceLine`
- **What:** CI asserts the literal `insuranceLine` is absent from every file Kayn's decomposition touches under `tools/demo-studio-v3/` <!-- orianna: ok — grep-gate scope string referring to missmp/company-os/tools/demo-studio-v3/; not a local filesystem path -->. Pairs with SE.E.2's grep-gate. <!-- orianna: ok -->
- **Where:** CI check (wired alongside SE.E.2's grep-gate).
- **Why:** BD §2 Rule 4 + BDC-MAL-2 resolution.
- **Acceptance:** CI fails if `insuranceLine` appears in any non-test, non-migration file.
- **TDD:** N/A — CI wiring.

#### MAL.E.2 — Implement Slack messaging + enrichment lookup
- **What:** add `_format_warning`, `_format_orphan_warning`, `_format_termination` helpers in `managed_session_monitor.py` <!-- orianna: ok — company-os future file under missmp/company-os/tools/demo-studio-v3/ -->. The enrichment helper makes **two** calls in parallel (`asyncio.gather`): (a) `session_store.get_session(sessionId)` → slack/user fields; (b) `config_mgmt_client.fetch_config(sessionId)` → brand. Returns a `SlackEnrichment` struct with `brand: str | None` where `None` signals 404 (render "config not yet set") or 5xx (render "brand unavailable", log `slack_enrichment_degraded`). Note: `config_mgmt_client` import in this module is permitted per BD §2 Rule 4 allowed-set; add `# azir: config-boundary` comment on the import line. <!-- orianna: ok -->
- **Where:** `tools/demo-studio-v3/managed_session_monitor.py`. <!-- orianna: ok — company-os file --> <!-- orianna: ok -->
- **Why:** ADR §5; BD amendment §2.1 + §2.2 (two-source join).
- **Acceptance:** MAL.E.1 tests pass. Literal `insuranceLine` is absent from all scanner code paths.
- **TDD:** preceded by MAL.E.1.
- **Depends on:** MAL.E.1.

#### MAL.E.3 — Wire monitor → slack-relay MCP <!-- orianna: ok — slack-relay is an internal MCP server name used in missmp/company-os context -->
- **What:** add `post_slack(channel, message)` helper that calls the existing `slack-relay` MCP. Monitor invokes it on warn / orphan / terminate branches.
- **Where:** `tools/demo-studio-v3/managed_session_monitor.py`. <!-- orianna: ok — company-os file --> <!-- orianna: ok -->
- **Why:** ADR §5.
- **Acceptance:** integration test in MAL.H.2 exercises this path.
- **TDD:** exempt — thin wrapper over existing MCP client, covered by MAL.H.2.
- **Depends on:** MAL.E.2.

---

### MAL.F — FastAPI startup/shutdown wiring

#### MAL.F.1 — xfail test for monitor lifecycle binding
- **What:** `tests/test_monitor_lifecycle_wiring.py` <!-- orianna: ok — future company-os test file relative to tools/demo-studio-v3/ -->. Tests: FastAPI `startup` event instantiates `ManagedSessionMonitor` and schedules `run_forever()` as an asyncio background task; `shutdown` event cancels that task; when `MANAGED_SESSION_MONITOR_ENABLED=false`, startup does NOT schedule the task. <!-- orianna: ok -->
- **Where:** new test file.
- **Why:** ADR §4 startup/shutdown model.
- **Acceptance:** tests fail against current `main.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ -->; xfail/strict → MAL.F.2. <!-- orianna: ok -->
- **TDD:** xfail commit for MAL.F.2.
- **Depends on:** MAL.D.2.

#### MAL.F.2 — Wire monitor into `main.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ --> startup/shutdown <!-- orianna: ok -->
- **What:** in `tools/demo-studio-v3/main.py` <!-- orianna: ok — company-os file -->, add startup + shutdown event handlers for the monitor. Respect the `MANAGED_SESSION_MONITOR_ENABLED` env var. <!-- orianna: ok -->
- **Where:** `tools/demo-studio-v3/main.py`. <!-- orianna: ok — company-os file --> <!-- orianna: ok -->
- **Why:** ADR §4.
- **Acceptance:** MAL.F.1 passes.
- **TDD:** preceded by MAL.F.1.
- **Depends on:** MAL.F.1, MAL.D.3, MAL.G.2.

---

### MAL.G — Config plumbing + startup invariant check

#### MAL.G.1 — xfail test for `MonitorConfig.from_env()` + invariant
- **What:** `tests/test_monitor_config.py` <!-- orianna: ok — future company-os test file relative to tools/demo-studio-v3/ -->. Tests: reads each ADR §6 env var with listed default; `IDLE_WARN_MINUTES >= IDLE_TERMINATE_MINUTES` raises `ConfigError`; `SCAN_INTERVAL_SECONDS < 60` raises `ConfigError`; `MANAGED_SESSION_MONITOR_ENABLED` accepts `true/false/1/0` case-insensitive. <!-- orianna: ok -->
- **Where:** new test file.
- **Why:** ADR §6 invariant check.
- **Acceptance:** tests fail — `MonitorConfig.from_env()` does not exist; xfail/strict → MAL.G.2.
- **TDD:** xfail commit for MAL.G.2.
- **Depends on:** MAL.D.2.

#### MAL.G.2 — Implement `MonitorConfig.from_env()` + invariant
- **What:** body out the `from_env()` classmethod on `MonitorConfig`. Raise `ConfigError` (subclass of `ValueError`) on invariant violation. Log loaded config at startup.
- **Where:** `tools/demo-studio-v3/managed_session_monitor.py`. <!-- orianna: ok — company-os file --> <!-- orianna: ok -->
- **Why:** ADR §6.
- **Acceptance:** MAL.G.1 passes. Startup fails fast on misconfiguration.
- **TDD:** preceded by MAL.G.1.
- **Depends on:** MAL.G.1.

---

### MAL.H — Integration test + observability

#### MAL.H.1 — Structured-log event assertions (unit)
- **What:** `tests/test_monitor_observability.py` <!-- orianna: ok — future company-os test file relative to tools/demo-studio-v3/ -->. Assert that every ADR §10 event type fires exactly once per triggering condition: `managed_session_warned`, `managed_session_terminated`, `orphan_terminated`, `scan_cycle_complete`, `terminal_hook_failed`, `terminal_hook_skipped_no_managed_session`, `slack_enrichment_degraded` (new per BD amendment §2.5). Use `caplog` with a JSON log extractor. <!-- orianna: ok -->
- **Where:** new test file.
- **Why:** ADR §10 observability bullet.
- **Acceptance:** all log events discoverable by `event_type`.
- **TDD:** test-only task; safe to land after MAL.B.2 + MAL.D.3 + MAL.E.2.
- **Depends on:** MAL.B.2, MAL.D.3, MAL.E.2.

#### MAL.H.2 — Integration test against real Anthropic SDK
- **What:** `tests/integration/test_stop_managed_session_integration.py` <!-- orianna: ok — future company-os integration test relative to tools/demo-studio-v3/ -->. Creates a throwaway managed session, confirms it's `idle`, calls `stop_managed_session`, then asserts `retrieve()` returns `terminated` (or `404`). S2 stubbed at integration-test boundary (no cross-service HTTP). Skipped when `ANTHROPIC_API_KEY` is absent. <!-- orianna: ok -->
- **Where:** new file.
- **Why:** ADR §10 test strategy layer (iii); BD amendment §2.5 clarification (S2 stubbed, Anthropic is real).
- **Acceptance:** test passes locally with a real API key; CI skips cleanly when unset.
- **TDD:** exempt — integration test is additive.
- **Depends on:** MAL.A.4.

---

### Dispatch plan

**Critical path (eager-cost-containment spine):**
```
MAL.0.1 → MAL.A.1 → MAL.A.2 → MAL.A.3 → MAL.A.4 → MAL.C.1 → MAL.C.2
                                              ↘ MAL.B.1 → MAL.B.2
```

**Critical path (scanner spine):**
```
MAL.0.1 → MAL.D.1 → MAL.D.2 → MAL.G.1 → MAL.G.2 → MAL.D.3 → MAL.D.4 → MAL.E.1 → MAL.E.2 → MAL.F.1 → MAL.F.2
```

**Hard serial points:**
1. **MAL.0.1 gates all of MAL.D and MAL.A.3.**
2. **MAL.B.2 must follow SE.A.6.**
3. **MAL.C.2 must follow MAL.A.2** and **MAL.C.3 must follow MAL.A.2**.
4. **MAL.F.2 must follow MAL.D.3 + MAL.G.2**.

---

### BD-consistency concerns (resolved)

**BDC-MAL-1 — Slack enrichment reads `brand` / `insuranceLine` from Firestore session doc**

**Resolution (per BD amendment §2.1 / §2.2):** Enrichment is a two-source join. Firestore provides slack/user coordinates; S2 (`config_mgmt_client.fetch_config`) provides brand. `insuranceLine` is removed entirely — it does not exist on S2. Resolved as OQ-MAL-4.

**BDC-MAL-2 — `insuranceLine` literal appears in ADR's Slack format**

**Resolution:** The literal string `insuranceLine` is removed from all scanner code paths, format strings, and templates. MAL.E.1b grep-gate self-check enforces this.

**BDC-MAL-3 — MAL.D.4 fallback (c) would persist `lastActivityAt` on the S1 session doc**

**Resolution (per BD amendment §2.4):** Permitted as a pure lifecycle field if the spike returns case (c), with four pre-conditions: (1) spike documents why (a) and (b) are unworkable; (2) field is written only by the SSE event handler in `main.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ -->; (3) field is read only by `ManagedSessionMonitor`; (4) SE.A.4 Session dataclass revision appends this field (Kayn coordinates). Resolves OQ-MAL-5 conditionally. <!-- orianna: ok -->

---

### Open questions

- **OQ-MAL-1 — OPEN.** Idle-timestamp source. Resolved by MAL.0.1 spike.
- **OQ-MAL-2 — OPEN.** Slack channel `#demo-studio-alerts` vs `[alert]`-prefixed `#demos`. Ops/Duong decides.
- **OQ-MAL-3 — OPEN.** Terminate managed sessions on Service 1 shutdown. Lean: do NOT. Flagged for Duong.
- **OQ-MAL-4 — RESOLVED** by BD amendment §2.1/§2.2. Fetch brand from S2 per warn/terminate event; on S2 failure (404 cold or 5xx unavailable) render the message with brand elided rather than skip the alert.
- **OQ-MAL-5 — CONDITIONALLY RESOLVED** by BD amendment §2.4. Permitted with four pre-conditions (triggered only if spike returns case c).
- **OQ-MAL-6 — OPEN.** Extend SE.A.6 `transition_status` signature with optional `cancel_reason` kwarg vs separate `update_session` call. Kayn-internal decomposition question; resolves when MAL terminal-state-hook task is integrated with SE.A.6 acceptance criteria.

### Grep-gate allow-set for `config_mgmt_client` (cumulative across all BD amendments)

- `main.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ --> <!-- orianna: ok -->
- `factory_bridge*.py` <!-- orianna: ok — company-os file glob under missmp/company-os/tools/demo-studio-v3/ --> handful (per BD §2 Rule 4)
- `managed_session_monitor.py` <!-- orianna: ok — company-os future file under missmp/company-os/tools/demo-studio-v3/ --> (this amendment) <!-- orianna: ok -->
- Dashboard handler for `GET /api/managed-sessions` <!-- orianna: ok — HTTP route, not a filesystem path --> (dashboard amendment §4)

Kayn must consolidate this list in the SE.E.2 task acceptance criteria.

## Test plan

Three layers per ADR §10 test strategy (Caitlyn):

- **I1 — `stop_managed_session` idempotency:** MAL.A.1/A.2 unit tests cover idle-status delete, 404 swallow, idempotent second call, and outcome logging; MAL.A.3/A.4 extend to interrupt-before-delete on `running` status and 5-second timeout.
- **I2 — `ManagedSessionMonitor` decision matrix:** MAL.D.1/D.2/D.3 unit tests with a stubbed Anthropic SDK and stubbed clock cover all four decision outcomes — idle below warn threshold (no-op), warn-only, terminate with matched Firestore row, terminate orphan — plus agent-filter correctness and `scan_cycle_complete` log emission.
- **I3 — Slack enrichment coverage:** MAL.E.1/E.2 assert all three enrichment states (success, 404 cold, 5xx degraded) for each message variant; `insuranceLine` literal is absent from all scanner code paths (MAL.E.1b grep-gate).
- **I4 — Integration against real Anthropic SDK:** MAL.H.2 creates a throwaway managed session, confirms it is idle, calls `stop_managed_session`, and asserts the session is terminated; skipped when `ANTHROPIC_API_KEY` is absent.

## Amendments

_Source: `company-os/plans/2026-04-20-managed-agent-lifecycle-bd-amendment.md` in `missmp/company-os`. Inlined verbatim._ <!-- orianna: ok — cross-repo amendment file; exists in missmp/company-os --> <!-- orianna: ok -->

**Date:** 2026-04-20 (s3)
**Author:** Sona (coordinator, fastlane edit)
**Scope:** names the sections of `plans/2026-04-20-managed-agent-lifecycle.md` <!-- orianna: ok — self-ref under company-os plan naming; this plan is at plans/proposed/work/ in this repo --> (and tasks in `plans/2026-04-20-managed-agent-lifecycle-tasks.md` <!-- orianna: ok — future task file in missmp/company-os -->) that change as a consequence of the §11 resolutions in `plans/2026-04-20-s1-s2-service-boundary.md` <!-- orianna: ok — inlined from amendment; plan exists at plans/proposed/work/ in this repo --> (BD ADR). <!-- orianna: ok -->

### 1. Why this amendment exists

Aphelios' decomposition of the lifecycle ADR flagged three BD-consistency concerns:

- **BDC-MAL-1** — ADR §2.3 and §5 prescribe reading `config.brand` / `config.insuranceLine` off the **S1 session doc** for Slack-warning enrichment. BD-1 strict: those fields are not on the S1 session doc. <!-- orianna: ok -->
- **BDC-MAL-2** — ADR §5 Slack-format examples contain the literal string `insuranceLine`. BD §2 Rule 4 grep gate rejects any non-test PR containing that literal anywhere in `tools/demo-studio-v3/`. <!-- orianna: ok — cross-repo path in inlined amendment; refers to missmp/company-os --> <!-- orianna: ok -->
- **BDC-MAL-3** — MAL.D.4 case (c) fallback (spike-contingent) would persist a new `lastActivityAt` field on the S1 session doc. Not a strict BD-1/2 violation, but an expansion of the lifecycle-only surface that needs explicit sign-off.

Core lifecycle architecture (Anthropic-as-source-of-truth, eager terminal-state hook, 5-min scanner, idle-only thresholds, module boundary) is BD-clean and unchanged.

### 2. MAL ADR sections affected

#### 2.1 §2.3 Source-of-truth rule — enrichment source

**After:** Enrichment is a **two-source join**: Firestore `demo-studio-sessions` (by `managedSessionId`) → `userEmail`, `slackChannel`, `slackThreadTs`; S2 `config_mgmt_client.fetch_config(sessionId)` → `brand`. Only brand. No `insuranceLine`.

Scanner still uses Anthropic as source of truth for "what is running" and "how long has it been idle". If S2 is unreachable or returns 404 (cold session), the warning is posted without brand rather than skipped.

#### 2.2 §5 Slack warning format — message shape + field sources

Field sources: `62min` — Anthropic-derived idle duration (unchanged); `Allianz` — `brand` from **S2** via `config_mgmt_client.fetch_config(sessionId)`. No `insuranceLine` (dead field per BD); `dnt@missmp.eu` — unchanged (Firestore helper); `#demos` — unchanged (`slackChannel` from Firestore, lifecycle field).

Cold-session fallback, S2-unavailable fallback, and orphan variant are per the ADR §5 section above.

The literal string `insuranceLine` is **removed** from all scanner code paths (resolves BDC-MAL-2).

#### 2.3 §2.3 is already scoped "enrichment only"

The Anthropic-as-source-of-truth rule in §2.3 is preserved in full. The invariant that **DB drift cannot cause us to miss a live session or kill a session Anthropic already ended** is unchanged.

#### 2.4 MAL.D.4 `lastActivityAt` fallback — contingent decision

**Decision (amendment):** If the spike lands on path (c), adding `lastActivityAt: datetime` to the Session dataclass is **permitted** as a pure lifecycle field. Pre-conditions: (1) spike documents why (a) and (b) are unworkable; (2) field is written only by the SSE event handler; (3) field is read only by `ManagedSessionMonitor`; (4) SE.A.4 Session dataclass revision appends this field (Kayn coordinates).

#### 2.5 §10 handoff — test strategy

The monitor's Slack-enrichment unit test must also stub `config_mgmt_client.fetch_config` — two stubs, not one — and cover the three enrichment states (success, 404 cold, 5xx degraded). Integration test does **not** hit S2 (too much cross-service coupling) — S2 is stubbed at integration-test boundary, Anthropic is real.

#### 2.6 Module boundary — unchanged

`managed_session_monitor.py` <!-- orianna: ok — company-os future file under missmp/company-os/tools/demo-studio-v3/ --> imports `config_mgmt_client`. Per BD §3.14 (allowed callers), this module joins the allowed set. **SE.E grep-gate must not false-positive on this import.** Kayn's MAL task-file revision adds this file to the grep-gate allow-set. <!-- orianna: ok -->

### 3. OQ-MAL resolutions affected

- **OQ-MAL-1, OQ-MAL-2, OQ-MAL-3** — UNCHANGED by this amendment.
- **OQ-MAL-4 — RESOLVED by §2.1 + §2.2 above.** Strategy: fetch brand from S2 per warn/terminate event; on S2 failure render the message with brand elided rather than skip the alert.
- **OQ-MAL-5 — RESOLVED by §2.4 above.** Permitted, with the four pre-conditions listed. Triggered only if spike returns (c).
- **OQ-MAL-6 — UNCHANGED** by this amendment.

### 4. Task-file amendments Kayn must issue

1. **MAL.A.1** — add note that this primitive does NOT touch S2. Pure Anthropic.
2. **MAL.D.3 / MAL.D.4** — if spike returns (c), `lastActivityAt` field write is gated on SE.A.4 Session-dataclass extension.
3. **MAL.E.1** — rewritten: literal `insuranceLine` forbidden; cold-session and S2-5xx fallbacks are tested.
4. **MAL.E.2** — rewritten: two calls — `session_store.get_session` for slack/user, `config_mgmt_client.fetch_config` for brand. Parallel via `asyncio.gather`. Returns `SlackEnrichment` struct with `brand: str | None`. <!-- orianna: ok -->
5. **MAL.E.3** — unchanged.
6. **MAL.H.1** — add event type `slack_enrichment_degraded`.
7. **MAL.H.2** — clarify: S2 is stubbed at integration-test boundary.
8. **New MAL.E.1b sub-task** — grep-gate self-check: CI asserts `insuranceLine` absent from all touched files.
9. **OQ-MAL-4** — marked RESOLVED with pointer to this amendment.
10. **OQ-MAL-5** — marked CONDITIONALLY RESOLVED.
11. **Grep-gate allow-set coordination** — MAL task file acknowledges `managed_session_monitor.py` <!-- orianna: ok — company-os future file under missmp/company-os/tools/demo-studio-v3/ --> is added to the allow-set for `config_mgmt_client` imports. <!-- orianna: ok -->

### 5. Sequencing

- Promotes alongside the two sibling amendments.
- Does NOT gate MAL.0 (preflight spike).
- MAL.A, MAL.B, MAL.C can start once SE.A.6 (`transition_status`) lands.

### 6. Out-of-scope for this amendment

- No rewrite of the MAL ADR itself.
- No decisions about MAL.0.1 (spike) outcome.
- No changes to the scanner's Anthropic-as-source-of-truth invariant.
- No changes to MAL.C, MAL.F, MAL.G beyond minor test-strategy notes.

### 7. Handoff

- **Duong:** promote this file via the work-concern convention. Then invoke Kayn to revise the MAL task file per §4 above.
- **Kayn:** on Duong's signal, issue the task-file revision per §4. Cross-coordinate with SE.E.2 in the SE task file for the grep-gate allow-set. Commit with `chore:` prefix.
- **Orianna:** optional fact-check on four load-bearing claims: `config.brand` path shape on S2; S2 `/v1/config` <!-- orianna: ok — HTTP API path on S2 service, not a filesystem path --> returns 404 before first `set_config`; `insuranceLine` absent from S2 `DemoConfig` schema; `config_mgmt_client` exists with async `fetch_config(sessionId)`. <!-- orianna: ok -->
- **Camille:** SE.E grep-gate extends to this module's allow-set; coordinate with Kayn's SE.E.2 revision.
