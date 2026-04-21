---
date: 2026-04-22
author: aphelios
concern: work
kind: task-breakdown-refresh
parent_plan: plans/in-progress/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md
---

# Task breakdown refresh — Demo Studio v3 Vanilla Messages API Ship

Refresh of Aphelios task #80 decomposition. Parent plan is signed + in-progress + `orianna_gate_version: 2`; this doc is an assessment-side augmentation so the parent body hash stays valid. Sona may later choose to fold these gap-fills into the parent via the demote → amend → re-sign dance.

## Verdict on prior decomposition — FRESH, but incomplete vs PR #64 manual feedback

The existing inline task list (`## Tasks` + `## Task breakdown` sections of the parent) is 58 tasks across phases A–F with correct TDD ordering, explicit blocking, 60-min cap, and complete DoD hooks. Nothing needs to be torn up. Do not re-run the decomposition from scratch.

The gap relative to Duong's manual-testing notes in `assessments/work/2026-04-21-pr64-local-manual-feedback.md`:

1. **Bug 5 — CRITICAL.** `static/studio.js:225` still sets `previewFrame.src = '/session/' + sessionId + '/preview'`. That S1 route was deleted in BD.B.7/B.8; `tests/test_preview_deleted_from_s1.py` asserts 404. The vanilla-API plan does not touch this wiring. The iframe will 404 on every session open unless phase C rewires the src to `S5_BASE/preview/<id>`.
2. **`load_dotenv(override=True)` papercut in `main.py`.** Fights shell env at service launch; forced Ekko to monkey-patch during manual testing. Needs flipping to `override=False` or dropping entirely for Cloud Run.
3. **Anthropic error pass-through leak.** `POST /session/{id}/chat` surfaces raw Anthropic 401 error body including `request_id` to the browser. The vanilla-API rewrite is the right moment to wrap this — `agent_proxy.run_turn` owns the error surface now.

None of these block Rakan from starting xfails on phases A/B, but (1) and (3) must land before Akali's E2E smoke (phase E) or E2E scenarios 2 + 3 will fail.

## Wave structure for Viktor (serial execution, one wave at a time)

Sona's dispatch discipline is serial. Viktor runs one wave; Rakan authors the xfails for that wave one commit ahead (Rule 12); Vi slots integration tests behind each wave. Ekko gets deploy hooks at Waves D and F.

### Wave 1 — Conversation store + system prompt lift (Phase A, part 1)

**Rakan xfails first (same branch, committed first per Rule 12):**
`T.A.1` (conv_store round-trip), `T.A.3` (SYSTEM_PROMPT wiring)

**Viktor implements:**
`T.A.2a` → `T.A.2b` → `T.A.2c` → `T.A.2d` → `T.A.4` → `T.A.9`

**Acceptance:** `ConversationStore.append/load/load_since/truncate_for_model` pass unit tests against Firestore emulator; `SYSTEM_PROMPT` imports from `agent_proxy.py`, not `setup_agent.py`; boundary invariant grep returns one file; Firestore composite index declared or explicitly deferred to Wave F.

**Vi integration hook:** none yet (no HTTP surface touched). Optional: a two-session concurrency integration test on top of TS.A.6.

**Ekko deploy hook:** none.

**Exit → Wave 2 gate:** emulator round-trip + TDD gate green.

---

### Wave 2 — Stream translator + agent_proxy.run_turn core (Phase A, part 2)

**Rakan xfails:** `T.A.5a–f`, `T.A.7a–c` (9 xfail cases)

**Viktor implements:** `T.A.6a` → `T.A.6b` → `T.A.8a` → `T.A.8b` → `T.A.8c`

**Acceptance:** single-turn conversation runs end-to-end with no tools against staging Messages API; SSE text deltas stream to a harness; `MAX_TURNS=20` cap enforced; `UnexpectedStopReason` raised on unknown stop reasons; structured log lines per turn (Q5 pick a) present.

**Vi integration hook:** TS.A.12 (round-trip via `run_turn` twice in sequence, confirms message state reloads from Firestore between calls).

**Ekko deploy hook:** none. Local dev + emulator only.

**Exit → Wave 3 gate:** single-turn no-tool staging conversation works in a browser-facing SSE consumer.

---

### Wave 3 — Tool-dispatch registry + five handlers (Phase B)

**Rakan xfails:** `T.B.1a`, `T.B.1b`, `T.B.3`, `T.B.5a`, `T.B.5b`, `T.B.7`

**Pre-flight (Sona):** grep TS MCP `server.ts` for the exact error strings per OQ-B1; publish inventory to the branch before `T.B.6`.

**Viktor implements:** `T.B.2a` → `T.B.2b` → `T.B.4` → `T.B.6` → `T.B.8` → `T.B.9`

**Acceptance:** round-trip `set_config` → S2 reflects write within 2 s (parent §8 phase-B gate); unknown tool returns `is_error: true` without crashing the loop; `HANDLERS` has exactly 4 keys; `web_search_20241022` in `TOOLS` but absent from `HANDLERS`.

**Vi integration hook:** tool-dispatch integration against staging S2 (not S2 mock) for the three config handlers + `trigger_factory` against staging S3. Short-circuit at tool-result assertion; do not run full build chain yet.

**Ekko deploy hook:** confirm staging S2 (`demo-config-mgmt`) reachable from S1 staging revision; no deploy action yet.

**Exit → Wave 4 gate:** `set_config` → S2 write green in integration; unknown-tool path green.

---

### Wave 4 — SSE route rewire + browser event set (Phase C)

**Rakan xfails:** `T.C.1a`, `T.C.1b`, `T.C.3`

**Viktor implements:** `T.C.2a` → `T.C.2b` → (conditional) `T.C.4`

**Acceptance:** `/session/{id}/stream` emits only `text_delta | tool_use | tool_result | turn_end | error`; `/session/{id}/chat` persists user message and triggers `run_turn`; browser chat view renders deltas smoothly. T.C.4 is a no-op if translator preserves existing event names.

**Vi integration hook:** FastAPI TestClient end-to-end: POST chat → GET stream → assert SSE event sequence shape matches §3.5.

**Ekko deploy hook:** none.

**Exit → Wave 5 gate:** browser-side chat demo works locally end-to-end against staging Anthropic + staging S2.

---

### Wave 5 — Gap-fill from PR #64 manual feedback (new; slot before Phase E)

**These three tasks are new. They do not exist in the parent plan's inline task list. Sona: decide whether to fold into the parent (demote → amend → re-sign) or carry as Wave-5 off-plan. Recommendation: carry off-plan to keep Orianna signature intact; the parent plan's phase D is the natural home for them if a re-sign is warranted.**

Branch: the same vanilla-api integration branch used in Waves 1–4.

- [ ] **T.GAP.1a** — Rakan xfail: `previewFrame.src` points at S5, never S1. kind: test | estimate_minutes: 30 | blocked_by: none | files: `company-os/tools/demo-studio-v3/tests/test_preview_wiring.py` (new). DoD: xfail asserts rendered `session.html` has no `'/session/' + sessionId + '/preview'` wiring and that `previewFrame.src` resolves against `window.__s5Base` (or `S5_BASE` injected into the template). References `assessments/work/2026-04-21-pr64-local-manual-feedback.md` Bug 5 and `tests/test_preview_deleted_from_s1.py`.
- [ ] **T.GAP.1b** — Viktor (or Talon) impl: wire `static/studio.js` + session.html to `S5_BASE`. kind: feat | estimate_minutes: 45 | blocked_by: T.GAP.1a | files: `company-os/tools/demo-studio-v3/static/studio.js`, `company-os/tools/demo-studio-v3/session.html`, `company-os/tools/demo-studio-v3/main.py` (inject `S5_BASE` into template context). DoD: iframe loads S5 preview for any session id in local browser test; T.GAP.1a flips green; "Open in new tab" and inline iframe both use the same base.
- [ ] **T.GAP.2** — Viktor: `load_dotenv(override=False)` in `main.py`. kind: fix | estimate_minutes: 15 | blocked_by: none | files: `company-os/tools/demo-studio-v3/main.py`. DoD: a subprocess test with shell-exported `BASE_URL=http://a` and a `.env` containing `BASE_URL=http://b` resolves `os.environ["BASE_URL"] == "http://a"`. Parent plan `tests/test_dotenv_precedence.py` (new).
- [ ] **T.GAP.3a** — Rakan xfail: `/session/{id}/chat` never surfaces raw Anthropic error body. kind: test | estimate_minutes: 30 | blocked_by: none | files: `company-os/tools/demo-studio-v3/tests/test_chat_error_handling.py` (new). DoD: xfail injects a mocked 401 from `messages.stream`; response body contains neither `request_id` nor `authentication_error`; returns a sanitized `{"error": "upstream_unavailable"}` (or similar) with 502; Anthropic detail logged server-side only.
- [ ] **T.GAP.3b** — Viktor impl: wrap Anthropic errors in `agent_proxy.run_turn`. kind: feat | estimate_minutes: 30 | blocked_by: T.GAP.3a, T.A.8c | files: `company-os/tools/demo-studio-v3/agent_proxy.py`, `company-os/tools/demo-studio-v3/main.py`. DoD: T.GAP.3a flips green; Senna security review sign-off that no upstream identifiers leak to browser.

**Vi integration hook (Wave 5):** Playwright headless test opens a session and asserts the preview iframe network request returns 200, not 404. Covers regression guard for Bug 5.

**Ekko deploy hook:** none yet. Wave 6 (= Phase D) is next.

**Exit → Wave 6 gate:** local browser open on a fresh session shows live preview iframe + clean chat with no raw Anthropic error leak.

---

### Wave 6 — Deletion sweep (Phase D, runs parallel-ish with Waves 1–5 but blocks E)

**Runs parallel with Waves 1–5 on a separate child branch, merges to the integration branch before Wave 7.**

**No xfail preamble required** (all tasks are `chore` deletes or ADR authoring).

**Viktor / Ekko executes:** `T.D.1` → `T.D.2a` → `T.D.2b` → `T.D.3` → `T.D.4` → `T.D.5` → `T.D.6a` → `T.D.6b` → `T.D.7`

**Acceptance:** S1 boots with neither MCP env nor managed-agent env set; grep sweep per T.D.7 returns zero hits for `managedSessionId`, `create_managed_session`, `setup_agent`, `MANAGED_`, `demo-studio-mcp` outside the retirement ADRs; MAL-retirement and MAD-retirement ADRs live in `plans/implemented/work/`.

**Vi integration hook:** S1 startup smoke (FastAPI TestClient boot + hit `/healthz`) with no managed env set.

**Ekko deploy hook:** validate staging deploy succeeds with the pruned env config (`T.D.4` output), keep prior revision retained for rollback. Light rehearsal for Wave 7.

**Exit → Wave 7 gate:** Phase D exit criteria + Wave 5 gap-fills merged.

---

### Wave 7 — E2E smoke v2 (Phase E)

**Depends on:** Waves 4, 5, 6 all merged.

**Vi implements off Xayah's test plan:** `T.E.1` → `T.E.2a` → `T.E.2b` → `T.E.2c` → `T.E.2d` → `T.E.2e` → `T.E.3`

**Acceptance:** 8/8 Playwright scenarios green back-to-back in a single recorded staging run; video + screenshots captured; QA report attached under `assessments/qa-reports/`.

**Ekko deploy hook:** staging Cloud Run revision healthy; Firestore composite index from `T.A.9` / `T.F.2` created if deferred; staging secrets populated.

**Exit → Wave 8 gate:** 8/8 green + Akali UI regression pass (Rule 16).

---

### Wave 8 — Prod cutover + MCP service deletion (Phase F)

**Sequence:** `T.F.1` → `T.F.2` (Ekko executes, Heimerdinger advises) → `T.F.3` → `T.F.4`

**Ekko primary.** Commit-prefix `ops:` per Rule 5.

**Rollback:** prior Cloud Run revision retained (parent §9); Rule 17 auto-rollback on prod smoke failure.

**Exit:** plan transitions to `implemented/`; MAL + MAD retirement ADRs committed; `demo-studio-mcp` Cloud Run service + DNS record gone.

## Rakan unblock status

**Rakan can start immediately on Wave-1 xfails.** Nothing in the gap-fill (Wave 5) blocks the Wave-1 xfails. Wave-1 xfails are:

- `T.A.1` (conversation_store round-trip)
- `T.A.3` (SYSTEM_PROMPT constant import)

Both target files are new (`tests/test_conversation_store.py`, `tests/test_system_prompt.py`) — no existing test conflicts.

Suggested Rakan sequencing across all waves:
1. Wave 1 xfails (T.A.1, T.A.3) — immediate.
2. Wave 2 xfails (T.A.5a–f + T.A.7a–c, 9 cases) — can author in parallel with Viktor's Wave-1 implementation.
3. Wave 3 xfails (T.B.1a/1b, T.B.3, T.B.5a/5b, T.B.7) — after Wave 2 xfails land.
4. Wave 4 xfails (T.C.1a, T.C.1b, T.C.3) — after Wave 3.
5. Wave 5 gap-fill xfails (T.GAP.1a, T.GAP.3a) — can slot in anywhere after Wave 1 since they touch independent files.

Rakan does not need the parent plan re-signed to start; xfails cite the parent plan slug in the test docstring and that satisfies `tdd-gate.yml`.

## Decisions still needed from Sona / Duong

- **Fold gap-fills into parent plan?** Default: no (keep signature intact; carry Wave 5 off-plan). If Sona prefers the parent-as-single-source-of-truth posture, demote → amend → re-sign is the mechanic; that costs one Orianna signature cycle.
- **Talon vs Viktor for T.GAP.1b?** Duong's feedback file named Talon as the owner candidate (frontend-adjacent wiring). If Talon is not available tonight, Viktor can absorb it since he's already in `main.py` for `T.C.2b`.
- **Firebase auth + dashboard overhaul (compass stretch goals)** — out of scope for the Swain Option B ship. Separate ADR once this ships.

## Cross-reference

- Parent plan: `plans/in-progress/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md`
- Compass: `assessments/work/2026-04-22-overnight-ship-plan.md`
- PR #64 feedback: `assessments/work/2026-04-21-pr64-local-manual-feedback.md`
- Xayah test plan: inlined in parent plan (`## Test plan (Xayah — inlined ...)` at line 719)
- Prior decomposition: inlined in parent plan (`## Task breakdown (Aphelios — inlined ...)` at line 534)
