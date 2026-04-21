---
status: approved
orianna_gate_version: 2
complexity: normal
concern: work
owner: Kayn
created: 2026-04-21
parent_plan: 2026-04-20-managed-agent-lifecycle.md
tags:
  - demo-studio
  - service-1
  - managed-agent
  - lifecycle
  - cost-control
  - work
  - tasks
tests_required: true
---

# Task breakdown — Managed-Agent Session Lifecycle Control (MAL)

Source ADR: `plans/approved/work/2026-04-20-managed-agent-lifecycle.md` (including inlined BD amendment in §Amendments).

Branch: `feat/demo-studio-v3` (company-os worktree at `~/Documents/Work/mmp/workspace/company-os-demo-studio-v3`). Same branch as the dashboard (MAD), session-state-encapsulation (SE), and S1↔S2 boundary (BD) breakdowns — all share one PR branch per ADR §10 handoff.

Task-ID scheme: `MAL.<phase>.<n>` (matches the ADR's own inline enumeration so cross-ADR links in MAD / SE / BD task files remain valid). Every impl task is preceded on the same branch by an xfail test commit per Rule 12.

AI-minute estimates are wall-clock Sonnet-builder time per commit (test commit + impl commit counted separately). They exclude Kayn breakdown and Senna / Caitlyn review time.

## Cross-ADR dependency map (load-bearing — read first)

| Artefact | Source | Consumed by | Hard blocker? |
| --- | --- | --- | --- |
| `session_store.transition_status(sessionId, to_status, *, cancel_reason=…)` | SE.A.6 (+ SE §8 extension — `cancel_reason` kwarg resolved per OQ-MAL-6 pointer) | MAL.B.2 (terminal-state hook), MAL.D.3 (scanner flip to `cancelled`) | **YES** for MAL.B.2 and MAL.D.3. If SE slips past MAL.A: ship scanner + primitive without eager path per ADR §10. |
| `config_mgmt_client.fetch_config(sessionId) -> DemoConfig` (brand only; 404 on cold) | BD (client tasked there) | MAL.E.2 (Slack enrichment join) | **YES** for MAL.E.2 impl. If BD slips: MAL.E.2 stubs client to raise 5xx always, rendering `brand unavailable` — scanner still ships, warnings degraded. |
| Spike 1 appendix (Anthropic SDK list-filter / retrieve idle / events-list / interrupt semantics) | MAL.0.1 (own phase) | MAL.A.3/A.4 (interrupt-before-delete), MAL.D.1/D.3/D.4 (idle resolution) | **YES** — MAL.0.1 gates MAL.A.3 and all of MAL.D. |
| `MANAGED_AGENT_ID` env var | already live in `agent_proxy.py` | MAL.D.3 (agent filter) | NO — pre-existing. |
| `slack-relay` MCP bot membership in `#demo-studio-alerts` | MAL.0.2 | MAL.E.3 (post path) | **Soft blocker** — MAL.E.3 ships either way; if bot absent, warnings log but don't post. MAL.0.2 locks the channel default. |
| SE.E.2 grep-gate allow-list (BD §2 Rule 4 — `config_mgmt_client` callers) | SE.E.2 | MAL.E.2 (allowed import of `config_mgmt_client`) | **Soft blocker** — if SE.E.2 not yet extended, add allow-list entry in the MAL PR itself and flag to Camille. |

Cross-file coupling with MAD breakdown: MAD.B.2 / MAD.C.2 consume the same `stop_managed_session` primitive MAL.A.4 produces (via the `managed_session_client` wrapper MAL's Spike 1 surface drives). MAL.A.4 must merge before MAD.B/C impl starts; see §Sequencing.

---

## Phase summary & estimates

| Phase | Scope | Tasks | AI-min |
| --- | --- | --- | --- |
| MAL.0 | Preflight: Anthropic SDK spike + Slack channel/bot confirm | 2 | 135 |
| MAL.A | `stop_managed_session` primitive in `agent_proxy.py` | 4 (2 xfail + 2 impl) | 110 |
| MAL.B | Terminal-state hook in `session_store.transition_status` | 2 (1 xfail + 1 impl) | 55 |
| MAL.C | Refactor `/cancel-build` + `/close` call sites | 4 (2 xfail + 2 impl) | 75 |
| MAL.D | `ManagedSessionMonitor` class (scan loop + decision matrix) | 5 (2 xfail + 3 impl, incl. contingent D.4) | 180 |
| MAL.E | Slack warning/termination messaging + grep-gate self-check | 4 (1 xfail + 2 impl + 1 CI) | 95 |
| MAL.F | FastAPI startup/shutdown wiring | 2 (1 xfail + 1 impl) | 45 |
| MAL.G | Config plumbing + startup invariant | 2 (1 xfail + 1 impl) | 40 |
| MAL.H | Observability tests + integration (real Anthropic throwaway) | 2 (1 unit + 1 integration) | 65 |
| **TOTAL** | | **27** | **800** |

Notes:
- MAL.0.1 (Spike 1) alone is budgeted 120 AI-min (the ADR says 2h wall-clock human budget; Sonnet reads the `anthropic` package and writes the 1-page appendix inside that envelope).
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
- **What:** per ADR §3 + §4 "Spike 1": read the installed `anthropic` Python package source. Produce a 1-page appendix at `company-os/plans/2026-04-20-managed-agent-lifecycle-spike1.md` (lives in missmp/company-os, NOT this repo) covering the three rows of ADR §3 table:
  - (a) `client.beta.sessions.list()` — does it accept an `agent` filter param? If no, confirm the client-side filter fallback signature.
  - (b) retrieve / last-activity — does `retrieve()` expose `lastActivityAt` / `updated_at` equivalent? If no, does `client.beta.sessions.events.list(session_id)` exist with a `created_at` field? If neither, case (c) — Service-1-maintained `lastActivityAt` via SSE proxy.
  - (c) stop — confirm `interrupt` event name and payload shape for `running` sessions before delete.
- **Deliverable:** the spike appendix, committed in the company-os worktree with `chore:` prefix. Append a short "result" block to THIS task file (same paragraph style as MAD.0.1) naming which case (a/b/c) landed for row (b), because it drives MAL.D.4 shape.
- **Acceptance:** appendix documents each row with exactly one of: (i) exact SDK surface confirmed, (ii) named fallback, (iii) blocker requiring Duong/Azir decision.
- **TDD:** exempt — research artefact, no code change.
- **Blockers:** none.
- **AI-min:** 120 (matches ADR's 2h budget).

### MAL.0.2 — Confirm `#demo-studio-alerts` Slack channel + bot membership (ERRAND)
- **What:** verify the channel exists in the company-os Slack workspace and that the `slack-relay` MCP bot is a member. If either is false, request invite OR fall back to `#demos` with `[alert]` prefix per ADR §5. Lock the chosen default for `SLACK_ALERT_CHANNEL`.
- **Deliverable:** finding appended to the MAL.0.1 spike appendix under a "Q2 — Slack channel" heading.
- **Acceptance:** channel name locked; bot membership confirmed or fallback chosen.
- **TDD:** exempt.
- **Blockers:** none.
- **AI-min:** 15.

---

## Phase MAL.A — `stop_managed_session` primitive

Pure additive. Merges independently of MAL.B/C/D. Module boundary (primitive in `agent_proxy.py`, NOT `main.py`) is load-bearing per ADR §10.

**BD note:** this primitive is pure Anthropic — it does NOT touch S2 (BD amendment §4 item 1).

### MAL.A.1 — xfail: idempotency + 404 swallow + outcome logging (TEST)
- **What:** new `tools/demo-studio-v3/tests/test_stop_managed_session.py`. Tests:
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
- **What:** add `async def stop_managed_session(session_id: str, reason: str = "") -> bool` to `tools/demo-studio-v3/agent_proxy.py`. Signature + docstring verbatim from ADR §4. Simple path (non-`running` status): call `client.beta.sessions.delete(session_id)`; swallow `NotFoundError` → return `False`. Log success via structured event `managed_session_terminated` with `reason` field.
- **Acceptance:** MAL.A.1 tests 1–4 pass (drop xfail).
- **Commit:** `feat(demo-studio-v3): stop_managed_session primitive (MAL.A.2)`.
- **TDD:** preceded by MAL.A.1.
- **Depends on:** MAL.A.1.
- **AI-min:** 25.

### MAL.A.3 — xfail: interrupt-before-delete on `running` + 5s timeout (TEST)
- **What:** extend `test_stop_managed_session.py`. Tests:
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
- **What:** new `tools/demo-studio-v3/tests/test_transition_status_terminal_hook.py`. Tests:
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
- **What:** modify `tools/demo-studio-v3/session_store.py::transition_status` so that, after a successful Firestore CAS commit, if `to_status` is in the terminal set, await `agent_proxy.stop_managed_session(session["managedSessionId"], reason=f"transition_to_{to_status}")`. Guards per MAL.B.1 tests 3/4/5. Post-commit — a hook failure CANNOT roll back the transition. Signature unchanged.
- **Acceptance:** MAL.B.1 tests pass. SE task-file's existing `transition_status` tests still pass.
- **Commit:** `feat(demo-studio-v3): terminal-state cleanup hook in transition_status (MAL.B.2)`.
- **TDD:** preceded by MAL.B.1.
- **Depends on:** MAL.B.1, MAL.A.4, SE.A.6.
- **AI-min:** 30.

---

## Phase MAL.C — Refactor `/cancel-build` + `/close` to use primitive

### MAL.C.1 — regression xfail: `/cancel-build` equivalence (TEST)
- **What:** new `tools/demo-studio-v3/tests/test_cancel_build_uses_stop_primitive.py`. Assert: (i) `POST /session/{id}/cancel-build` returns 200 on `building` status; still sets `_stop_flags[session_id] = True`; still deletes the managed session — but via `agent_proxy.stop_managed_session` (mock target moves from `main._client.beta.sessions.delete` to `main.stop_managed_session`). (ii) Response body byte-identical to pre-refactor baseline (golden fixture). (iii) 5s timeout behaviour preserved.
- **Acceptance:** xfail strict against current inline-delete code.
- **Commit:** `chore: add regression xfail for /cancel-build refactor (MAL.C.1)`.
- **TDD:** xfail + regression commit for MAL.C.2. Required by Rule 13 (bug/regression rule; refactors on stop paths treated equivalently per ADR §10).
- **Depends on:** MAL.A.2.
- **AI-min:** 15.

### MAL.C.2 — impl: refactor `/cancel-build` handler (BUILDER)
- **What:** in `tools/demo-studio-v3/main.py` around lines 2084–2120, replace the inline `_client.beta.sessions.delete(managed_session_id)` block with `await stop_managed_session(managed_session_id, reason="cancel_build")`. Keep the 5s timeout (now enforced inside the primitive). Remove the local `_client` construction if unused at that call site.
- **Acceptance:** MAL.C.1 passes. Pre-existing `tests/test_stop_build_phase.py` passes after mock-target rewrite.
- **Commit:** `refactor(demo-studio-v3): /cancel-build uses stop_managed_session (MAL.C.2)`.
- **TDD:** preceded by MAL.C.1.
- **Depends on:** MAL.C.1.
- **AI-min:** 20.

### MAL.C.3 — regression xfail + impl: `/close` (line 2204 inline delete) (TEST + BUILDER, paired)
- **What:** same pattern as MAL.C.1 + MAL.C.2 but for `POST /session/{id}/close` route at `main.py:2204`. One xfail regression test commit + one impl commit. New test `tests/test_close_uses_stop_primitive.py`; edit `main.py:2200–2215` area. Pre-existing `test_stop_and_archive.py` mock-target rewritten.
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
- **What:** new `tools/demo-studio-v3/tests/test_managed_session_monitor.py`. Stubbed Anthropic SDK + stubbed clock. Parametric cases:
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
- **What:** new `tools/demo-studio-v3/managed_session_monitor.py`. Define:
  - `MonitorConfig` dataclass (fields from ADR §6: `managed_agent_id`, `idle_warn_minutes`, `idle_terminate_minutes`, `scan_interval_seconds`, `slack_alert_channel`, `enabled`). `.from_env()` bodied in MAL.G.2.
  - `ManagedSessionMonitor(client, session_store, slack_relay, config)` with TTL dedup cache `dict[str, float]`.
  - `async def run_forever()` loop (cancellable via `asyncio.CancelledError`).
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
  - **Case (c)** — neither available: add xfail + impl for Service-1-maintained `lastActivityAt` — written ONLY by SSE event handler in `main.py`; read ONLY by `ManagedSessionMonitor`. BD amendment §2.4 pre-conditions mandatory: (1) spike documents why (a) and (b) are unworkable (MAL.0.1); (2) writer scoping; (3) reader scoping; (4) SE.A.4 `Session` dataclass appends the field (coordinate with Kayn → SE task file amendment in same PR). **AI-min: 60 (15 test + 45 impl).**
- **Acceptance:** scan uses a deterministic idle value regardless of spike outcome.
- **Commit sequence (cases b/c):** `chore: add xfail test for idle-resolution fallback (MAL.D.4 test)` + `feat(demo-studio-v3): idle-resolution fallback per Spike 1 case X (MAL.D.4 impl)`.
- **TDD:** paired xfail (cases b/c only).
- **Depends on:** MAL.0.1. Case (c) also on SE.A.4.
- **AI-min:** 30 (budget midpoint; adjust at dispatch).

---

## Phase MAL.E — Slack warning/termination messaging

### MAL.E.1 — xfail: Slack message formatting + enrichment states (TEST)
- **What:** new `tools/demo-studio-v3/tests/test_monitor_slack_format.py`. Render each variant (warn, orphan warn, termination) with mocked enrichment per BD amendment §2.2. Tests assert exact string shape for:
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
- **What:** extend the grep-gate config (SE.E.2 produces it) so CI asserts the literal `insuranceLine` is absent from every non-test, non-migration file under `tools/demo-studio-v3/`. Pairs with SE.E.2's gate — prefer editing SE.E.2's allow-list/deny-list config file over duplicating. If SE.E.2 hasn't landed, add a standalone check `scripts/grep-gate-insurance-line.sh` and wire to CI; retire it when SE.E.2 absorbs the rule.
- **Acceptance:** CI fails if `insuranceLine` appears in any non-test / non-migration file under `tools/demo-studio-v3/`.
- **Commit:** `chore(demo-studio-v3): grep-gate CI check for insuranceLine literal (MAL.E.1b)`.
- **TDD:** N/A — CI wiring.
- **Depends on:** ideally SE.E.2 (consolidates allow-lists); can ship standalone.
- **AI-min:** 20.

### MAL.E.2 — impl: Slack formatting + two-source enrichment (BUILDER)
- **What:** add `_format_warning`, `_format_orphan_warning`, `_format_termination` helpers in `managed_session_monitor.py`. Enrichment helper makes TWO calls in parallel via `asyncio.gather(..., return_exceptions=True)`:
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
- **What:** new `tools/demo-studio-v3/tests/test_monitor_lifecycle_wiring.py`. Tests:
  1. FastAPI `startup` event instantiates `ManagedSessionMonitor` and schedules `run_forever()` as asyncio background task.
  2. `shutdown` event cancels the task cleanly (awaits cancellation; no pending-task warning).
  3. When `MANAGED_SESSION_MONITOR_ENABLED=false`, startup does NOT schedule the task.
- **Acceptance:** xfail strict against current `main.py`.
- **Commit:** `chore: add xfail tests for monitor lifecycle wiring (MAL.F.1)`.
- **TDD:** xfail commit for MAL.F.2.
- **Depends on:** MAL.D.2.
- **AI-min:** 20.

### MAL.F.2 — impl: wire monitor startup/shutdown in main.py (BUILDER)
- **What:** add startup + shutdown handlers in `tools/demo-studio-v3/main.py`. Respect `MANAGED_SESSION_MONITOR_ENABLED` env var. Kill-switch path per ADR §6 last row.
- **Acceptance:** MAL.F.1 passes.
- **Commit:** `feat(demo-studio-v3): wire ManagedSessionMonitor startup/shutdown (MAL.F.2)`.
- **TDD:** preceded by MAL.F.1.
- **Depends on:** MAL.F.1, MAL.D.3, MAL.G.2.
- **AI-min:** 25.

---

## Phase MAL.G — Config plumbing + startup invariant

### MAL.G.1 — xfail: `MonitorConfig.from_env()` + invariant (TEST)
- **What:** new `tools/demo-studio-v3/tests/test_monitor_config.py`. Tests:
  1. Reads each ADR §6 env var; applies documented defaults.
  2. `IDLE_WARN_MINUTES >= IDLE_TERMINATE_MINUTES` raises `ConfigError`.
  3. `SCAN_INTERVAL_SECONDS < 60` raises `ConfigError`.
  4. `MANAGED_SESSION_MONITOR_ENABLED` accepts `true/false/1/0` case-insensitive.
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
- **What:** new `tools/demo-studio-v3/tests/test_monitor_observability.py`. Assert every ADR §10 event type fires exactly once per triggering condition via `caplog` + JSON extractor:
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
- **What:** new `tools/demo-studio-v3/tests/integration/test_stop_managed_session_integration.py` (`@pytest.mark.integration`). Flow: create a throwaway managed session via Anthropic SDK → assert `idle` → call `stop_managed_session` → assert `retrieve()` returns `terminated` (or raises `NotFoundError`). Skip when `ANTHROPIC_API_KEY` absent. S2 stubbed at integration boundary — do NOT hit real S2 (BD amendment §2.5).
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
6. **MAL.D.4 case (c) SE.A.4 coordination.** If case (c) lands, Kayn must amend `plans/approved/work/2026-04-20-session-state-encapsulation-tasks.md` SE.A.4 in-band to append `lastActivityAt: datetime | None` to the `Session` dataclass before MAL.D.4 impl merges. Non-blocking for eager path; cross-plan edit needed in the same PR or a gating commit.

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
  - If MAL.0.1 returns case (c), amend `plans/approved/work/2026-04-20-session-state-encapsulation-tasks.md` SE.A.4 before MAL.D.4 impl starts (add `lastActivityAt: datetime | None` to `Session` dataclass).
  - Reconcile grep-gate allow-set with SE.E.2 + MAD.E.1 when both land — if SE.E.2 hasn't absorbed MAL.E.1b, promote the rule into SE.E.2's config.
- **Caitlyn (tester):** three layers per ADR §10 + observability + regression. MAL.H.1 is the single unified observability-event test to own.
- **Camille (grep-gate):** MAL.E.1b adds / consolidates the `insuranceLine` deny-rule. Coordinates with SE.E.2 allow-list.
- **Orianna:** no new fact-check hooks in this breakdown. BD amendment's six flagged facts (Azir's earlier scan) are the relevant fact-checks; not re-checked here.
- **Evelynn / dispatch:** flag MAL.D.4 AI-min re-budget at MAL.0.1 close (±30).
