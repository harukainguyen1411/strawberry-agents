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
  - lifecycle
  - cost-control
  - work
tests_required: true
---

# ADR: Managed-Agent Session Lifecycle Control (Demo Studio v3 Service 1)

Date: 2026-04-20
Scope: `company-os/tools/demo-studio-v3` (Service 1 only)
Related: `secretary/agents/azir/learnings/2026-04-20-session-api-adr.md` (session-state-encapsulation ADR)

## 1. Context

Anthropic Managed Agent sessions created under `MANAGED_AGENT_ID=agent_011Ca9Dk3H4m6DYcA6e489Ew` can run indefinitely. Idle but unclosed sessions continue to be billed at an hourly rate (confirmed by Anthropic docs; see section 3). Cost grows per active session.

Today, Service 1 creates a managed session in two places and almost never tears one down:

- `agent_proxy.py::create_managed_session` — called during session bootstrap.
- `main.py` line 2046-area — wires the managed session into Firestore and hands it to the browser SSE proxy.
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
| (a) List active sessions for an `agent_id` | `client.beta.sessions.list()` — paginated, returns `{id, status}` | **Docs do not show an `agent` filter param.** Fallback: list all, then either (i) filter client-side by retrieving each session's `agent.id` via `retrieve()`, or (ii) persist the managed_session_id -> agent_id map in Firestore and filter using our own data. Implementers (Kayn) must confirm the SDK signature by reading `anthropic` Python package source before finalising. |
| (b) Get session with last activity timestamp | `client.beta.sessions.retrieve(session_id)` returns status and other fields | **`lastActivityAt` is not shown in docs.** The statuses listed are `{idle, running, rescheduling, terminated}`. Fallback: compute idle via events — `client.beta.sessions.events.list(session_id)` (or equivalent) sorted by `created_at` desc; idle duration = `now - latest_event.created_at`. Implementers must verify the events-list endpoint name and `created_at` field during Spike 1 (see section 4). If events list is also unavailable, second fallback: persist `lastActivityAt` ourselves on every inbound SSE event in Service 1, accepting the DB-drift risk on this one field only. |
| (c) Stop / end a session | `client.beta.sessions.delete(session_id)` (documented; already used in `main.py:2113`) | Deleting a `running` session requires an interrupt event first. `stop_managed_session()` must send an `interrupt` event before delete when status is `running`, or catch the error and retry. |

**Blocker assessment:** Gap (a) is solvable with a client-side filter at our current session volume (<100 concurrent). Gap (b) is the real risk: if neither `lastActivityAt` nor an events-list endpoint exposes a usable timestamp, we fall back to Service-1-maintained idle tracking, which reintroduces DB-drift risk for the scanner's core input. This is flagged as Q1 below and must be resolved before implementation.

## 4. Module shape

New file: `company-os/tools/demo-studio-v3/managed_session_monitor.py` <!-- orianna: ok — future file in missmp/company-os -->

- `ManagedSessionMonitor` class with async `run_forever()` loop.
- TTL dedup cache: `dict[str, float]` keyed by `managed_session_id`, value = expiry epoch. Warnings suppressed if entry is present and not expired.
- Started as an asyncio background task in `main.py` FastAPI `startup` event. Cancelled on `shutdown` event.
- Single-instance assumption: Cloud Run Service 1 runs `--min-instances=1 --max-instances=1`. If that changes, a second instance would double-scan; collision is safe (deletes are idempotent) but warnings could duplicate. Mitigation: migrate dedup cache to Firestore if we ever scale out. Out of scope for this ADR.

New function in `agent_proxy.py`:

```python
async def stop_managed_session(session_id: str, reason: str = "") -> bool:
    """Idempotently terminate a managed session.

    Returns True if deleted, False if already gone. Handles `running` state by
    sending an interrupt event first. Swallows 404. Logs all outcomes.
    """
```

Terminal-state wiring: `session_store.transition_status` (per session-state-encapsulation ADR) calls `stop_managed_session` as a post-commit hook inside the same code path that fires status-change webhooks. The hook is `await`-ed but wrapped in a per-call timeout (5s, matching the existing `cancel_build` pattern in `main.py:2112`) so a slow Anthropic response cannot block the transition.

### Spike 1 (before implementation)

Kayn's executor must spike the two SDK gaps (a) and (b) in section 3 and attach the findings to this ADR as an appendix before writing production code. Budget: 2 hours.

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

- **Kayn / Aphelios:** break into tasks. Spike 1 (SDK gap confirmation) is the first task and gates the rest. The module boundary in section 4 is load-bearing — do not merge `stop_managed_session` into `main.py`.
- **Depends on:** `2026-04-20-session-api-adr.md` (session-state-encapsulation). Terminal-state hook in section 2.1 lives inside that ADR's `transition_status`. If that ADR slips, ship scanner without the eager path and accept the degraded cost floor.
- **Test strategy (for Caitlyn):** three layers. (i) Unit: `stop_managed_session` idempotency, interrupt-before-delete when running, 404 swallow. (ii) Unit: `ManagedSessionMonitor` decision logic with a stubbed SDK (< warn = no-op, warn-only = 1 slack call, terminate = delete + slack + Firestore). The enrichment unit test must stub both `session_store.get_session` (for slack/user fields) and `config_mgmt_client.fetch_config` (for brand), covering three enrichment states (success, 404 cold, 5xx degraded). (iii) Integration: real Anthropic SDK against a throwaway session; S2 stubbed at the integration-test boundary (no cross-service HTTP).
- **Regression test for existing `/cancel-build` <!-- orianna: ok — HTTP route name, not a filesystem path --> path:** existing call site at `main.py:2111-2115` inlines the delete. Refactor it to call `stop_managed_session` and add a test asserting equivalence (no behaviour change for end users).
- **Observability:** structured logs with event types `managed_session_warned`, `managed_session_terminated`, `orphan_terminated`, `scan_cycle_complete` (with counts), `slack_enrichment_degraded`. Feed to existing `logger` in `main.py`. No new metrics infra.

## Appendix: Files touched

- NEW `company-os/tools/demo-studio-v3/managed_session_monitor.py` <!-- orianna: ok — future file in missmp/company-os; does not exist until MAL.D.2 -->
- MODIFY `company-os/tools/demo-studio-v3/agent_proxy.py` — add `stop_managed_session`.
- MODIFY `company-os/tools/demo-studio-v3/main.py` — wire monitor startup/shutdown; refactor `cancel_build` to use `stop_managed_session`.
- MODIFY `company-os/tools/demo-studio-v3/session_store.py` <!-- orianna: ok — company-os file; exists at feat/demo-studio-v3 per SE ADR; terminal-state hook (MAL.B) depends on SE.A.6 --> — add terminal-state hook (per session-state-encapsulation ADR).
- MODIFY `company-os/tools/demo-studio-v3/tests/` — new test files per section 10 test strategy.

## Tasks

_Source: `company-os/plans/2026-04-20-managed-agent-lifecycle-tasks.md` in `missmp/company-os`. Inlined verbatim._ <!-- orianna: ok — cross-repo task file; future file in missmp/company-os -->

**ADR:** `plans/proposed/work/2026-04-20-managed-agent-lifecycle.md`
**Branch:** `feat/demo-studio-v3` <!-- orianna: ok — git branch name in missmp/company-os; not a filesystem path -->
**Repo:** `missmp/company-os`, all work under `tools/demo-studio-v3/`. <!-- orianna: ok — cross-repo path prefix; all tools/demo-studio-v3/ refs in this Tasks section refer to missmp/company-os -->
**Sister plans on the same branch:**
- `plans/proposed/work/2026-04-20-session-state-encapsulation.md` + `…-tasks.md` (SE) — provides `session_store.py` and `session_store.transition_status`. MAL's terminal-state hook (ADR §2.1) plugs into SE.A.6 `transition_status`.
- `plans/proposed/work/2026-04-20-s1-s2-service-boundary.md` (BD — approved) — S1 is session-lifecycle + agent-hosting only. Identity fields (`brand`, `market`, `languages`, `shortcode`) are NOT on the S1 session doc.

**TDD gate active:** every impl task must be preceded on the same branch by an xfail test commit referencing the task ID. Pre-push hook enforces; agents may not bypass.
**Regression-test rule:** the refactor of `/cancel-build` <!-- orianna: ok — HTTP route name, not a filesystem path --> (MAL.C.2) must carry a paired regression test (see MAL.C.1) per universal invariant 13 — behaviour must be preserved end-to-end.
**Conventional-commit prefix:** impl commits under `tools/demo-studio-v3/**` <!-- orianna: ok — glob pattern referring to missmp/company-os/tools/demo-studio-v3/; not a local filesystem path --> use `feat:` / `refactor:` / `fix:`; test-only commits use `chore:`; plan edits use `chore:`.

### Scope and sequencing rationale

This decomposition translates ADR §2–§7 into pairwise TDD tasks. The ADR is explicit that Spike 1 (SDK gap confirmation, §3+§4) gates all implementation work — idle-detection design is not decidable until Q1 is answered. MAL.0 is therefore not optional: it produces the appendix that unblocks MAL.D.

The work splits into two sub-ADRs that ship independently:
- **Eager path (MAL.A + MAL.B + MAL.C):** terminal-state cleanup. Shippable without the scanner. Depends on SE.A.6 (`transition_status`).
- **Safety-net path (MAL.D + MAL.E + MAL.F + MAL.G):** in-process `ManagedSessionMonitor`. Shippable behind `MANAGED_SESSION_MONITOR_ENABLED=false` kill-switch regardless of eager path state.

### Task ID scheme

- `MAL.0.*` — preflight (SDK spike, Slack bot membership check)
- `MAL.A.*` — `stop_managed_session` primitive in `agent_proxy.py`
- `MAL.B.*` — terminal-state hook in `session_store.transition_status`
- `MAL.C.*` — refactor `/cancel-build` <!-- orianna: ok — HTTP route name --> and `/close` <!-- orianna: ok — HTTP route name --> call sites to use the primitive
- `MAL.D.*` — `ManagedSessionMonitor` class (scan loop, dedup cache, decision logic)
- `MAL.E.*` — Slack warning/termination messaging
- `MAL.F.*` — `main.py` startup/shutdown wiring
- `MAL.G.*` — config plumbing + startup invariant check
- `MAL.H.*` — integration tests + observability

---

### MAL.0 — Preflight

#### MAL.0.1 — Spike 1: confirm Anthropic SDK surface for list + retrieve + events
- **What:** read the installed `anthropic` Python package source and produce a 1-page appendix covering ADR §3 table rows (a), (b), (c). Attach findings as `company-os/plans/2026-04-20-managed-agent-lifecycle-spike1.md` <!-- orianna: ok — future artefact in missmp/company-os, not yet created -->. Budget: 2 hours.
- **Where:** new file `company-os/plans/2026-04-20-managed-agent-lifecycle-spike1.md`. <!-- orianna: ok — future file; does not exist until Kayn runs the spike -->
- **Why:** ADR §3 "Blocker assessment" — Gap (b) is the real risk.
- **Acceptance:** appendix documents each of the three rows with one of: (i) exact SDK surface confirmed, (ii) a named fallback, (iii) a blocker requiring a Duong/Azir decision.
- **TDD:** exempt — research artefact, no code change.
- **Depends on:** none.

#### MAL.0.2 — Confirm `#demo-studio-alerts` Slack channel + bot membership
- **What:** verify the target Slack channel exists and that the `slack-relay` <!-- orianna: ok — internal MCP server name in missmp/company-os --> MCP bot is a member. If not, either request invite or fall back to `#demos` with `[alert]` prefix per ADR §5 fallback.
- **Where:** append finding to `company-os/plans/2026-04-20-managed-agent-lifecycle-spike1.md`. <!-- orianna: ok — same future file as MAL.0.1 -->
- **Why:** ADR §5 / Q2. Without bot membership, MAL.E.2 fails silently in prod.
- **Acceptance:** channel name locked in for `SLACK_ALERT_CHANNEL` default; bot membership confirmed or fallback chosen.
- **TDD:** exempt — ops confirmation, no code change.
- **Depends on:** none.

---

### MAL.A — `stop_managed_session` primitive

Merges independently. Pure additive; no call-site changes yet.

#### MAL.A.1 — xfail tests for `stop_managed_session` idempotency + 404 swallow
- **What:** create `tools/demo-studio-v3/tests/test_stop_managed_session.py` <!-- orianna: ok — company-os future test file --> with four tests covering: delete on idle status, 404 swallow, idempotent second call, outcome logging.
- **Where:** new test file in `missmp/company-os`.
- **Why:** ADR §4 module shape — locks the idempotency contract before impl.
- **Acceptance:** tests import `agent_proxy.stop_managed_session` and fail with `AttributeError` or `ImportError`. Marked `@pytest.mark.xfail(reason="MAL.A.2", strict=True)`.
- **TDD:** xfail commit for MAL.A.2.
- **Depends on:** none.

#### MAL.A.2 — Implement `stop_managed_session` idempotent delete path
- **What:** add `async def stop_managed_session(session_id: str, reason: str = "") -> bool` in `tools/demo-studio-v3/agent_proxy.py` <!-- orianna: ok — company-os file -->. Signature and docstring verbatim from ADR §4. For the simple path (non-running status): call `client.beta.sessions.delete(session_id)`. Swallow `NotFoundError` → return `False`. Log success as structured event `managed_session_terminated` with `reason` field.
- **Where:** `tools/demo-studio-v3/agent_proxy.py`. <!-- orianna: ok — company-os file; missmp/company-os/tools/demo-studio-v3/agent_proxy.py -->
- **Why:** ADR §4 — primitive owned by `agent_proxy`, not `main.py`. Module boundary is load-bearing per ADR §10 handoff.
- **Acceptance:** MAL.A.1 tests 1, 2, 3, 4 pass.
- **TDD:** preceded by MAL.A.1.
- **Depends on:** MAL.A.1.

#### MAL.A.3 — xfail tests for interrupt-before-delete on `running` status
- **What:** extend `test_stop_managed_session.py` with tests covering: interrupt event sent before delete on running status, retry after delete error on running, 5s timeout.
- **Where:** same file as MAL.A.1.
- **Why:** ADR §3 Gap (c) + §4 "5s timeout matching `cancel_build` pattern".
- **Acceptance:** new tests fail (impl does not yet send interrupt); xfail/strict → MAL.A.4. Exact interrupt SDK call comes from MAL.0.1 spike appendix.
- **TDD:** xfail commit for MAL.A.4.
- **Depends on:** MAL.A.2, MAL.0.1.

#### MAL.A.4 — Implement interrupt-before-delete + 5s timeout
- **What:** extend `stop_managed_session` to: (i) call `retrieve(session_id)` first; (ii) if `status == "running"`, send interrupt event per spike appendix, then delete; (iii) wrap the whole call in `asyncio.wait_for(..., timeout=5.0)`; (iv) on timeout, log `managed_session_stop_timeout` and return `False`.
- **Where:** `tools/demo-studio-v3/agent_proxy.py`. <!-- orianna: ok — company-os file -->
- **Why:** ADR §3 Gap (c), §4 timeout requirement.
- **Acceptance:** MAL.A.3 tests all pass.
- **TDD:** preceded by MAL.A.3.
- **Depends on:** MAL.A.3.

---

### MAL.B — Terminal-state hook in `session_store.transition_status`

Depends on SE.A.6 (`session_store.transition_status` exists). If SE slips, MAL.B parks; eager path unavailable and scanner alone ships per ADR §10.

#### MAL.B.1 — xfail test for terminal-state hook invocation
- **What:** create `tools/demo-studio-v3/tests/test_transition_status_terminal_hook.py` <!-- orianna: ok — company-os future test file -->. Tests covering: hook called on transition to each terminal status in `{completed, cancelled, qc_failed, build_failed, built}`; hook NOT called on transition to non-terminal status; hook failure does not block the transition; 5s timeout bound.
- **Where:** new test file in `missmp/company-os`.
- **Why:** ADR §2.1 + §4 "post-commit hook … wrapped in a per-call timeout".
- **Acceptance:** tests fail because the hook does not exist yet; xfail/strict → MAL.B.2.
- **TDD:** xfail commit for MAL.B.2.
- **Depends on:** SE.A.6 (`transition_status` implemented).

#### MAL.B.2 — Wire post-commit hook inside `transition_status`
- **What:** modify `tools/demo-studio-v3/session_store.py::transition_status` <!-- orianna: ok — company-os file --> so that, after a successful Firestore CAS commit, if `to_status` is in the terminal set, it awaits `agent_proxy.stop_managed_session(session["managedSessionId"], reason=f"transition_to_{to_status}")`. Guard against: (a) `managedSessionId is None` — skip hook, log `terminal_hook_skipped_no_managed_session`; (b) hook exception — swallow + log `terminal_hook_failed`; (c) 5s timeout per MAL.A.4 already inside `stop_managed_session`. Hook is post-commit — a hook failure cannot roll back the transition.
- **Where:** `tools/demo-studio-v3/session_store.py`. <!-- orianna: ok — company-os file -->
- **Why:** ADR §2.1 eager cleanup.
- **Acceptance:** MAL.B.1 tests all pass. `transition_status` signature unchanged. SE task-file's existing `transition_status` tests still pass.
- **TDD:** preceded by MAL.B.1.
- **Depends on:** MAL.B.1, MAL.A.4, SE.A.6.

---

### MAL.C — Refactor `/cancel-build` <!-- orianna: ok — HTTP route name --> and `/close` <!-- orianna: ok — HTTP route name --> to use primitive

Both routes currently inline `_client.beta.sessions.delete(...)`. Refactor to call `agent_proxy.stop_managed_session`. Required for DRY and so the interrupt-before-delete behaviour (MAL.A.4) applies uniformly.

#### MAL.C.1 — Regression test for `/cancel-build` <!-- orianna: ok — HTTP route name --> equivalence
- **What:** add `tests/test_cancel_build_uses_stop_primitive.py` <!-- orianna: ok — future company-os test; path relative to tools/demo-studio-v3/ -->. Tests assert (i) `POST /session/{id}/cancel-build` <!-- orianna: ok — HTTP route, not a filesystem path --> still returns 200 on `building` status, still sets `_stop_flags[session_id] = True`, still deletes the managed session — but now via `agent_proxy.stop_managed_session` (mock target moves from `main.Anthropic` / `_client.beta.sessions.delete` to `main.stop_managed_session`); (ii) the response body is byte-identical to the pre-refactor baseline; (iii) 5s timeout behaviour preserved.
- **Where:** new test file.
- **Why:** universal invariant 13 — refactor touching the stop path needs a regression test.
- **Acceptance:** tests xfail against current inline-delete code; xfail/strict → MAL.C.2.
- **TDD:** xfail + regression commit for MAL.C.2.
- **Depends on:** MAL.A.2.

#### MAL.C.2 — Refactor `/cancel-build` <!-- orianna: ok — HTTP route name --> handler to call `stop_managed_session`
- **What:** in `tools/demo-studio-v3/main.py` <!-- orianna: ok — company-os file --> around lines 2084–2120, replace the inline `_client.beta.sessions.delete(managed_session_id)` block with `await stop_managed_session(managed_session_id, reason="cancel_build")`. Keep the 5s timeout (now enforced inside the primitive). Remove the local `_client` construction if no longer used at that call site.
- **Where:** `tools/demo-studio-v3/main.py`. <!-- orianna: ok — company-os file -->
- **Why:** ADR §10 handoff. DRY with scanner path and MAL.B hook.
- **Acceptance:** MAL.C.1 passes. Pre-existing `tests/test_stop_build_phase.py` <!-- orianna: ok — pre-existing company-os test file; path relative to tools/demo-studio-v3/ --> passes after mock-target rewrite.
- **TDD:** preceded by MAL.C.1.
- **Depends on:** MAL.C.1.

#### MAL.C.3 — Regression test + refactor for `/close` <!-- orianna: ok — HTTP route name --> (line 2204 inline delete)
- **What:** same pattern as MAL.C.1+C.2 but for the `/session/{id}/close` <!-- orianna: ok — HTTP route, not a filesystem path --> route at `main.py:2204`. One xfail regression test + one impl commit.
- **Where:** new test `tests/test_close_uses_stop_primitive.py`; edit `tools/demo-studio-v3/main.py:2200–2215` area. <!-- orianna: ok — company-os file paths -->
- **Why:** same as MAL.C.2 — DRY and timeout uniformity.
- **Acceptance:** regression test passes; `test_stop_and_archive.py` <!-- orianna: ok — pre-existing company-os test file relative to tools/demo-studio-v3/tests/ --> mock-target rewritten and passing.
- **TDD:** xfail-paired test commit precedes impl.
- **Depends on:** MAL.A.2. Independent of MAL.C.2.

---

### MAL.D — `ManagedSessionMonitor` class

#### MAL.D.1 — xfail tests for `ManagedSessionMonitor` decision matrix
- **What:** create `tools/demo-studio-v3/tests/test_managed_session_monitor.py` <!-- orianna: ok — company-os future test file -->. Stubbed Anthropic SDK + stubbed clock. Parametric cases: idle < warn → no-op; warn ≤ idle < terminate → one Slack warning; idle ≥ terminate → stop + Slack + Firestore transition; no Firestore row (orphan) → stop + orphan Slack; agent filter: only acts on `MANAGED_AGENT_ID` ones; scan cycle logs `scan_cycle_complete`.
- **Where:** new test file in `missmp/company-os`.
- **Why:** ADR §2.2 + §10 test strategy layer (ii).
- **Acceptance:** tests fail because class does not exist; xfail/strict → MAL.D.2 + D.3.
- **TDD:** xfail commit for MAL.D.2 and MAL.D.3.
- **Depends on:** MAL.0.1.

#### MAL.D.2 — Implement `ManagedSessionMonitor` class scaffold + TTL dedup cache
- **What:** create `tools/demo-studio-v3/managed_session_monitor.py` <!-- orianna: ok — company-os future file --> with: Class `ManagedSessionMonitor(client, session_store, slack_relay, config: MonitorConfig)`, TTL dedup cache, Config dataclass `MonitorConfig` with fields from ADR §6, `async def run_forever()` loop, `async def scan_once()` — empty stub.
- **Where:** new file `tools/demo-studio-v3/managed_session_monitor.py`. <!-- orianna: ok — company-os future file -->
- **Why:** ADR §4 module shape.
- **Acceptance:** import tests pass; `run_forever` cancels on `asyncio.CancelledError`. MAL.D.1 tests still xfail (scan logic empty).
- **TDD:** preceded by MAL.D.1.
- **Depends on:** MAL.D.1.

#### MAL.D.3 — Implement `scan_once()` decision logic
- **What:** body out `scan_once()` per ADR §2.2. For each active session: (i) resolve idle duration via the mechanism chosen in MAL.0.1; (ii) apply decision matrix from MAL.D.1; (iii) for terminations call `agent_proxy.stop_managed_session` + attempt `session_store.transition_status(..., to_status="cancelled", cancel_reason="idle_timeout")` — swallow transition failure, Anthropic is authoritative; (iv) emit `scan_cycle_complete` log with counts.
- **Where:** `tools/demo-studio-v3/managed_session_monitor.py`.
- **Why:** ADR §2.2, §2.3.
- **Acceptance:** MAL.D.1 tests all pass.
- **TDD:** preceded by MAL.D.1.
- **Depends on:** MAL.D.2, MAL.A.4, SE.A.6.

#### MAL.D.4 — xfail test + impl for idle-timestamp resolution fallback
- **What:** depending on MAL.0.1 outcome, one of:
  - (a) spike confirms `retrieve().last_activity_at` — no fallback task needed; fold into MAL.D.3.
  - (b) spike confirms `events.list()` — add xfail + impl for "fetch latest event timestamp and compute idle = now - latest.created_at".
  - (c) spike shows neither — add xfail + impl for "Service-1-maintained `lastActivityAt` on every inbound SSE event in Service 1, write to session doc via `session_store.update_session`". **BD-consistency note:** permitted as a pure lifecycle field (per BD amendment §2.4 pre-conditions) if spike returns (c).
- **Where:** either `managed_session_monitor.py` (cases a/b) or `agent_proxy.py` + `main.py` SSE proxy (case c).
- **Why:** ADR §3 Gap (b) is the real risk.
- **Acceptance:** scan uses a deterministic idle value regardless of spike outcome.
- **TDD:** paired xfail test.
- **Depends on:** MAL.0.1.

---

### MAL.E — Slack warning/termination messaging

#### MAL.E.1 — xfail tests for Slack message formatting
- **What:** `tools/demo-studio-v3/tests/test_monitor_slack_format.py` <!-- orianna: ok — company-os future test file -->. Tests render each of the message variants (warn, orphan warn, termination) with mocked enrichment data per BD amendment §2.2 field sources. Tests assert exact string shape. The literal `insuranceLine` must NOT appear in any format string or test assertion (BD grep-gate compliance).
- **Where:** new test file in `missmp/company-os`.
- **Why:** ADR §5 message shape, as amended by BD amendment §2.2.
- **Acceptance:** tests fail — formatting helpers don't exist yet; xfail/strict → MAL.E.2.
- **TDD:** xfail commit for MAL.E.2.
- **Depends on:** MAL.D.2.

#### MAL.E.1b — Grep-gate self-check for `insuranceLine`
- **What:** CI asserts the literal `insuranceLine` is absent from every file Kayn's decomposition touches under `tools/demo-studio-v3/` <!-- orianna: ok — grep-gate scope string referring to missmp/company-os/tools/demo-studio-v3/; not a local filesystem path -->. Pairs with SE.E.2's grep-gate.
- **Where:** CI check (wired alongside SE.E.2's grep-gate).
- **Why:** BD §2 Rule 4 + BDC-MAL-2 resolution.
- **Acceptance:** CI fails if `insuranceLine` appears in any non-test, non-migration file.
- **TDD:** N/A — CI wiring.

#### MAL.E.2 — Implement Slack messaging + enrichment lookup
- **What:** add `_format_warning`, `_format_orphan_warning`, `_format_termination` helpers in `managed_session_monitor.py`. The enrichment helper makes **two** calls in parallel (`asyncio.gather`): (a) `session_store.get_session(sessionId)` → slack/user fields; (b) `config_mgmt_client.fetch_config(sessionId)` → brand. Returns a `SlackEnrichment` struct with `brand: str | None` where `None` signals 404 (render "config not yet set") or 5xx (render "brand unavailable", log `slack_enrichment_degraded`). Note: `config_mgmt_client` import in this module is permitted per BD §2 Rule 4 allowed-set; add `# azir: config-boundary` comment on the import line.
- **Where:** `tools/demo-studio-v3/managed_session_monitor.py`. <!-- orianna: ok — company-os file -->
- **Why:** ADR §5; BD amendment §2.1 + §2.2 (two-source join).
- **Acceptance:** MAL.E.1 tests pass. Literal `insuranceLine` is absent from all scanner code paths.
- **TDD:** preceded by MAL.E.1.
- **Depends on:** MAL.E.1.

#### MAL.E.3 — Wire monitor → slack-relay MCP <!-- orianna: ok — slack-relay is an internal MCP server name used in missmp/company-os context -->
- **What:** add `post_slack(channel, message)` helper that calls the existing `slack-relay` MCP. Monitor invokes it on warn / orphan / terminate branches.
- **Where:** `tools/demo-studio-v3/managed_session_monitor.py`. <!-- orianna: ok — company-os file -->
- **Why:** ADR §5.
- **Acceptance:** integration test in MAL.H.2 exercises this path.
- **TDD:** exempt — thin wrapper over existing MCP client, covered by MAL.H.2.
- **Depends on:** MAL.E.2.

---

### MAL.F — FastAPI startup/shutdown wiring

#### MAL.F.1 — xfail test for monitor lifecycle binding
- **What:** `tests/test_monitor_lifecycle_wiring.py` <!-- orianna: ok — future company-os test file relative to tools/demo-studio-v3/ -->. Tests: FastAPI `startup` event instantiates `ManagedSessionMonitor` and schedules `run_forever()` as an asyncio background task; `shutdown` event cancels that task; when `MANAGED_SESSION_MONITOR_ENABLED=false`, startup does NOT schedule the task.
- **Where:** new test file.
- **Why:** ADR §4 startup/shutdown model.
- **Acceptance:** tests fail against current `main.py`; xfail/strict → MAL.F.2.
- **TDD:** xfail commit for MAL.F.2.
- **Depends on:** MAL.D.2.

#### MAL.F.2 — Wire monitor into `main.py` startup/shutdown
- **What:** in `tools/demo-studio-v3/main.py` <!-- orianna: ok — company-os file -->, add startup + shutdown event handlers for the monitor. Respect the `MANAGED_SESSION_MONITOR_ENABLED` env var.
- **Where:** `tools/demo-studio-v3/main.py`. <!-- orianna: ok — company-os file -->
- **Why:** ADR §4.
- **Acceptance:** MAL.F.1 passes.
- **TDD:** preceded by MAL.F.1.
- **Depends on:** MAL.F.1, MAL.D.3, MAL.G.2.

---

### MAL.G — Config plumbing + startup invariant check

#### MAL.G.1 — xfail test for `MonitorConfig.from_env()` + invariant
- **What:** `tests/test_monitor_config.py` <!-- orianna: ok — future company-os test file relative to tools/demo-studio-v3/ -->. Tests: reads each ADR §6 env var with listed default; `IDLE_WARN_MINUTES >= IDLE_TERMINATE_MINUTES` raises `ConfigError`; `SCAN_INTERVAL_SECONDS < 60` raises `ConfigError`; `MANAGED_SESSION_MONITOR_ENABLED` accepts `true/false/1/0` case-insensitive.
- **Where:** new test file.
- **Why:** ADR §6 invariant check.
- **Acceptance:** tests fail — `MonitorConfig.from_env()` does not exist; xfail/strict → MAL.G.2.
- **TDD:** xfail commit for MAL.G.2.
- **Depends on:** MAL.D.2.

#### MAL.G.2 — Implement `MonitorConfig.from_env()` + invariant
- **What:** body out the `from_env()` classmethod on `MonitorConfig`. Raise `ConfigError` (subclass of `ValueError`) on invariant violation. Log loaded config at startup.
- **Where:** `tools/demo-studio-v3/managed_session_monitor.py`. <!-- orianna: ok — company-os file -->
- **Why:** ADR §6.
- **Acceptance:** MAL.G.1 passes. Startup fails fast on misconfiguration.
- **TDD:** preceded by MAL.G.1.
- **Depends on:** MAL.G.1.

---

### MAL.H — Integration test + observability

#### MAL.H.1 — Structured-log event assertions (unit)
- **What:** `tests/test_monitor_observability.py` <!-- orianna: ok — future company-os test file relative to tools/demo-studio-v3/ -->. Assert that every ADR §10 event type fires exactly once per triggering condition: `managed_session_warned`, `managed_session_terminated`, `orphan_terminated`, `scan_cycle_complete`, `terminal_hook_failed`, `terminal_hook_skipped_no_managed_session`, `slack_enrichment_degraded` (new per BD amendment §2.5). Use `caplog` with a JSON log extractor.
- **Where:** new test file.
- **Why:** ADR §10 observability bullet.
- **Acceptance:** all log events discoverable by `event_type`.
- **TDD:** test-only task; safe to land after MAL.B.2 + MAL.D.3 + MAL.E.2.
- **Depends on:** MAL.B.2, MAL.D.3, MAL.E.2.

#### MAL.H.2 — Integration test against real Anthropic SDK
- **What:** `tests/integration/test_stop_managed_session_integration.py` <!-- orianna: ok — future company-os integration test relative to tools/demo-studio-v3/ -->. Creates a throwaway managed session, confirms it's `idle`, calls `stop_managed_session`, then asserts `retrieve()` returns `terminated` (or `404`). S2 stubbed at integration-test boundary (no cross-service HTTP). Skipped when `ANTHROPIC_API_KEY` is absent.
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

**Resolution (per BD amendment §2.4):** Permitted as a pure lifecycle field if the spike returns case (c), with four pre-conditions: (1) spike documents why (a) and (b) are unworkable; (2) field is written only by the SSE event handler in `main.py`; (3) field is read only by `ManagedSessionMonitor`; (4) SE.A.4 Session dataclass revision appends this field (Kayn coordinates). Resolves OQ-MAL-5 conditionally.

---

### Open questions

- **OQ-MAL-1 — OPEN.** Idle-timestamp source. Resolved by MAL.0.1 spike.
- **OQ-MAL-2 — OPEN.** Slack channel `#demo-studio-alerts` vs `[alert]`-prefixed `#demos`. Ops/Duong decides.
- **OQ-MAL-3 — OPEN.** Terminate managed sessions on Service 1 shutdown. Lean: do NOT. Flagged for Duong.
- **OQ-MAL-4 — RESOLVED** by BD amendment §2.1/§2.2. Fetch brand from S2 per warn/terminate event; on S2 failure (404 cold or 5xx unavailable) render the message with brand elided rather than skip the alert.
- **OQ-MAL-5 — CONDITIONALLY RESOLVED** by BD amendment §2.4. Permitted with four pre-conditions (triggered only if spike returns case c).
- **OQ-MAL-6 — OPEN.** Extend SE.A.6 `transition_status` signature with optional `cancel_reason` kwarg vs separate `update_session` call. Kayn-internal decomposition question; resolves when MAL terminal-state-hook task is integrated with SE.A.6 acceptance criteria.

### Grep-gate allow-set for `config_mgmt_client` (cumulative across all BD amendments)

- `main.py`
- `factory_bridge*.py` handful (per BD §2 Rule 4)
- `managed_session_monitor.py` (this amendment)
- Dashboard handler for `GET /api/managed-sessions` <!-- orianna: ok — HTTP route, not a filesystem path --> (dashboard amendment §4)

Kayn must consolidate this list in the SE.E.2 task acceptance criteria.

## Test plan

Three layers per ADR §10 test strategy (Caitlyn):

- **I1 — `stop_managed_session` idempotency:** MAL.A.1/A.2 unit tests cover idle-status delete, 404 swallow, idempotent second call, and outcome logging; MAL.A.3/A.4 extend to interrupt-before-delete on `running` status and 5-second timeout.
- **I2 — `ManagedSessionMonitor` decision matrix:** MAL.D.1/D.2/D.3 unit tests with a stubbed Anthropic SDK and stubbed clock cover all four decision outcomes — idle below warn threshold (no-op), warn-only, terminate with matched Firestore row, terminate orphan — plus agent-filter correctness and `scan_cycle_complete` log emission.
- **I3 — Slack enrichment coverage:** MAL.E.1/E.2 assert all three enrichment states (success, 404 cold, 5xx degraded) for each message variant; `insuranceLine` literal is absent from all scanner code paths (MAL.E.1b grep-gate).
- **I4 — Integration against real Anthropic SDK:** MAL.H.2 creates a throwaway managed session, confirms it is idle, calls `stop_managed_session`, and asserts the session is terminated; skipped when `ANTHROPIC_API_KEY` is absent.

## Amendments

_Source: `company-os/plans/2026-04-20-managed-agent-lifecycle-bd-amendment.md` in `missmp/company-os`. Inlined verbatim._ <!-- orianna: ok — cross-repo amendment file; exists in missmp/company-os -->

**Date:** 2026-04-20 (s3)
**Author:** Sona (coordinator, fastlane edit)
**Scope:** names the sections of `plans/2026-04-20-managed-agent-lifecycle.md` <!-- orianna: ok — self-ref under company-os plan naming; this plan is at plans/proposed/work/ in this repo --> (and tasks in `plans/2026-04-20-managed-agent-lifecycle-tasks.md` <!-- orianna: ok — future task file in missmp/company-os -->) that change as a consequence of the §11 resolutions in `plans/2026-04-20-s1-s2-service-boundary.md` <!-- orianna: ok — inlined from amendment; plan exists at plans/proposed/work/ in this repo --> (BD ADR).

### 1. Why this amendment exists

Aphelios' decomposition of the lifecycle ADR flagged three BD-consistency concerns:

- **BDC-MAL-1** — ADR §2.3 and §5 prescribe reading `config.brand` / `config.insuranceLine` off the **S1 session doc** for Slack-warning enrichment. BD-1 strict: those fields are not on the S1 session doc.
- **BDC-MAL-2** — ADR §5 Slack-format examples contain the literal string `insuranceLine`. BD §2 Rule 4 grep gate rejects any non-test PR containing that literal anywhere in `tools/demo-studio-v3/`. <!-- orianna: ok — cross-repo path in inlined amendment; refers to missmp/company-os -->
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

`managed_session_monitor.py` imports `config_mgmt_client`. Per BD §3.14 (allowed callers), this module joins the allowed set. **SE.E grep-gate must not false-positive on this import.** Kayn's MAL task-file revision adds this file to the grep-gate allow-set.

### 3. OQ-MAL resolutions affected

- **OQ-MAL-1, OQ-MAL-2, OQ-MAL-3** — UNCHANGED by this amendment.
- **OQ-MAL-4 — RESOLVED by §2.1 + §2.2 above.** Strategy: fetch brand from S2 per warn/terminate event; on S2 failure render the message with brand elided rather than skip the alert.
- **OQ-MAL-5 — RESOLVED by §2.4 above.** Permitted, with the four pre-conditions listed. Triggered only if spike returns (c).
- **OQ-MAL-6 — UNCHANGED** by this amendment.

### 4. Task-file amendments Kayn must issue

1. **MAL.A.1** — add note that this primitive does NOT touch S2. Pure Anthropic.
2. **MAL.D.3 / MAL.D.4** — if spike returns (c), `lastActivityAt` field write is gated on SE.A.4 Session-dataclass extension.
3. **MAL.E.1** — rewritten: literal `insuranceLine` forbidden; cold-session and S2-5xx fallbacks are tested.
4. **MAL.E.2** — rewritten: two calls — `session_store.get_session` for slack/user, `config_mgmt_client.fetch_config` for brand. Parallel via `asyncio.gather`. Returns `SlackEnrichment` struct with `brand: str | None`.
5. **MAL.E.3** — unchanged.
6. **MAL.H.1** — add event type `slack_enrichment_degraded`.
7. **MAL.H.2** — clarify: S2 is stubbed at integration-test boundary.
8. **New MAL.E.1b sub-task** — grep-gate self-check: CI asserts `insuranceLine` absent from all touched files.
9. **OQ-MAL-4** — marked RESOLVED with pointer to this amendment.
10. **OQ-MAL-5** — marked CONDITIONALLY RESOLVED.
11. **Grep-gate allow-set coordination** — MAL task file acknowledges `managed_session_monitor.py` is added to the allow-set for `config_mgmt_client` imports.

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
- **Orianna:** optional fact-check on four load-bearing claims: `config.brand` path shape on S2; S2 `/v1/config` <!-- orianna: ok — HTTP API path on S2 service, not a filesystem path --> returns 404 before first `set_config`; `insuranceLine` absent from S2 `DemoConfig` schema; `config_mgmt_client` exists with async `fetch_config(sessionId)`.
- **Camille:** SE.E grep-gate extends to this module's allow-set; coordinate with Kayn's SE.E.2 revision.
