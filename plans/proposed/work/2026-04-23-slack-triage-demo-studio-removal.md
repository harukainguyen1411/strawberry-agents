---
status: proposed
complexity: normal
concern: work
owner: swain
created: 2026-04-23
orianna_gate_version: 2
tags:
  - slack-triage
  - demo-studio
  - removal
  - work
tests_required: true
---

# slack-triage — delete `create_demo_studio_session` and Demo Studio handoff

<!-- orianna: ok -- all bare module/path tokens in this plan (main.py, tests/test_triage_v2.py, tests/pytest.ini, README.md, Dockerfile, requirements.txt) reference files inside the missmp/company-os work workspace under company-os/tools/slack-triage/, not strawberry-agents -->
<!-- orianna: ok -- env-var tokens (DEMO_STUDIO_URL, DEMO_STUDIO_ENABLED, INTERNAL_SECRET) are runtime env names, not filesystem -->
<!-- orianna: ok -- identifier tokens (create_demo_studio_session, _handle_demo_request_v2, handle_message_event, trigger_demo_runner, _handle_active_conversation, DEMO_STUDIO_ENABLED, DEMO_STUDIO_URL) are Python symbols, not filesystem -->
<!-- orianna: ok -- parent plan `plans/in-progress/work/2026-04-23-firebase-auth-loop2d-slack-removal.md` is a local plan file that exists on disk -->

## 1. Context

Parent plan `plans/in-progress/work/2026-04-23-firebase-auth-loop2d-slack-removal.md` W3 deletes demo-studio-v3's `POST /session` endpoint. That is slack-triage's only dependency on demo-studio. Parent §5.b chose "kill Slack bot entirely from the Demo Studio surface" and parent T.COORD.5 (slack-triage removal) is a **hard gate** for parent T.W0.1 (W3 unblock after 24h observation).

Today (`company-os/tools/slack-triage/main.py`):

- `DEMO_STUDIO_URL` env var (line 36) — base URL target for the handoff.
- `DEMO_STUDIO_ENABLED` env var (line 35) — gates v2 routing branch.
- `create_demo_studio_session` (lines 271-302) — async POST to `{DEMO_STUDIO_URL}/session` with `{slackUserId, slackChannel, slackThreadTs, initialContext}` and `X-Internal-Secret` header; returns `studioUrl` on 201.
- `_handle_demo_request_v2` (lines 523-570) — the v2 demo_request flow: Gemini extraction → call `create_demo_studio_session` → post studio URL into thread.
- `handle_message_event` lines 513-516 — routing branch: `if DEMO_STUDIO_ENABLED and category == "demo_request": await _handle_demo_request_v2(...)`. If disabled or miss, falls through to v1 spec-gathering + `trigger_demo_runner` (unrelated to demo-studio, targets demo-runner).
- `tests/test_triage_v2.py` — ~10 tests patching `create_demo_studio_session`; all under a module-level `pytestmark = pytest.mark.skipif(not _MODULE_AVAILABLE, ...)` gate that keys on `hasattr(_main_mod, "create_demo_studio_session")`.

No other symbol references `DEMO_STUDIO_URL` / `DEMO_STUDIO_ENABLED` / `create_demo_studio_session`. The removal is localised.

## 2. Decision

Delete the Demo Studio handoff surface from slack-triage entirely:

1. **Delete `create_demo_studio_session`** (lines 271-302) — sole caller of demo-studio's `POST /session`.
2. **Delete `_handle_demo_request_v2`** (lines 523-570) — only caller of `create_demo_studio_session`.
3. **Delete the v2 routing branch** in `handle_message_event` (lines 513-516); demo_request messages fall through to the v1 spec-gathering / `trigger_demo_runner` path that already handles them.
4. **Delete env-var reads** for `DEMO_STUDIO_URL` (line 36) and `DEMO_STUDIO_ENABLED` (line 35) — no consumer remains.
5. **Delete `tests/test_triage_v2.py`** — every non-trivial test in the file patches `create_demo_studio_session`; the xfail-skip gate (`_MODULE_AVAILABLE = hasattr(_main_mod, "create_demo_studio_session")`) would flip every test to skip anyway. Clean deletion is faithful to the symbol removal.
6. **Prune `README.md`** — drop any sentence mentioning Demo Studio handoff. `trigger_demo_runner` → demo-runner description stays.

**Demo Studio role after this PR:** none. slack-triage has no code path that references demo-studio. The Slack-era nudge ("go sign in at demo-studio.missmp.tech") is **not** added as a hardcoded literal — per task-brief constraint that `DEMO_STUDIO_URL` must not exist as a string in slack-triage, and per parent §5.b ("the Slack bot retains no session-creation authority"). Users who want Demo Studio navigate there directly; discovery is out of scope for slack-triage.

**Unrelated surfaces untouched:** `trigger_demo_runner`, `_handle_active_conversation`, `_update_specs_from_action`, `_thread_specs`, Gemini classification, HubSpot lookups, Slack signature verification. All remain functional. The v1 flow continues to serve demo_request classifications through spec-gathering + demo-runner trigger.

## 3. Architecture

Before: `handle_message_event` → v2 branch (`DEMO_STUDIO_ENABLED` + `demo_request`) → `_handle_demo_request_v2` → `create_demo_studio_session` POSTs to demo-studio-v3 `/session` → posts studio URL into thread. Else → v1 spec-gathering → `trigger_demo_runner` (targets demo-runner, unrelated to demo-studio).

After: v2 branch deleted. `handle_message_event` falls straight through to v1 spec-gathering → `trigger_demo_runner`. Three symbols gone, two env reads gone, one test file gone. Net diff: ~-110 lines `main.py`, ~-380 lines `tests/test_triage_v2.py`, ~-2 lines `README.md`. Single-wave single-PR removal.

## Test plan

- **Unit W1** (existing) `tests/test_triage_v1.py` — the v1 spec-gathering tests, if any, continue to pass unchanged. If the file does not exist, no change; v1 is exercised implicitly by `handle_message_event` end-to-end tests that remain.
- **Grep assertion W1** — after the PR lands, `grep -r "DEMO_STUDIO_URL\|DEMO_STUDIO_ENABLED\|create_demo_studio_session\|_handle_demo_request_v2" company-os/tools/slack-triage/` returns zero hits. Enforced manually in PR review (no automated grep gate exists for slack-triage).
- **Smoke W1** — after deploy, send a Slack `demo_request`-classified message into a test channel and confirm slack-triage routes through the v1 spec-gathering flow (posts the gathering question, not a studio URL). Ekko runs.
- **Regression xfail (Rule 12)** — before implementation lands, commit a test that asserts `not hasattr(main, "create_demo_studio_session")` and that `DEMO_STUDIO_URL` is absent from `main.__dict__`. Flip green after the deletion commit.

## 5. Open questions

**Duong's answers (2026-04-23, auto-mode):** `1a 2a 3a` — all Swain picks accepted (aligned with parent Loop 2d ADR §5.b already approved).


1. **Delete v2 tests or retarget?** a: delete `tests/test_triage_v2.py` — every test patches a deleted symbol; pytestmark skip-gate would skip them all anyway. **Pick.** b: retarget to v1-fallback assertions — lower value, v1 tests already cover v1.
2. **Keep a bare Demo Studio nudge?** a: no URL mentioned — clean deletion, aligns with parent §5.b + task-brief string constraint. **Pick.** b: hardcode literal `https://demo-studio.missmp.tech/` — violates task-brief.
3. **Keep `DEMO_STUDIO_ENABLED` gate as dead no-op?** a: delete the gate and branch; fall through to v1 unconditionally. **Pick.** b: keep for rollback ergonomics — rejected, rollback is `git revert` not a flag.

## Out of scope

- Any rewrite of v1 spec-gathering or `trigger_demo_runner`.
- Reintroducing a Demo Studio link in any form (future ADR if re-requested).
- Changes to demo-studio-v3 itself (tracked in parent `2026-04-23-firebase-auth-loop2d-slack-removal.md`).
- Deleting `INTERNAL_SECRET` — it is still used by `trigger_demo_runner` (line 452) and `update_thread_state` (line 727-728).

## Architecture impact

- `main.py` — delete 3 symbols (`create_demo_studio_session`, `_handle_demo_request_v2`, v2 routing branch) + 2 env reads (`DEMO_STUDIO_URL`, `DEMO_STUDIO_ENABLED`). `handle_message_event` signature unchanged.
- `tests/test_triage_v2.py` — deleted.
- `README.md` — prune Demo Studio sentence; `trigger_demo_runner` → demo-runner description stays.
- `requirements.txt`, `Dockerfile`, `pytest.ini` — unchanged. No env/IAM changes. No data migration.

## Tasks

<!-- Aphelios will refine post-Orianna-approval. Tasks below are coordination-level skeletons; executor tiers added at decomposition time. -->

- [ ] **T.1** — Xfail regression test: assert `create_demo_studio_session` absent from `main` module and no env read of `DEMO_STUDIO_URL` / `DEMO_STUDIO_ENABLED` occurs at import (Rule 12). estimate_minutes: 10. Files: tests/test_slack_triage_demo_studio_removed.py. DoD: 2 xfails committed before T.2 lands.
- [ ] **T.2** — Delete `create_demo_studio_session`, `_handle_demo_request_v2`, v2 routing branch, `DEMO_STUDIO_URL` / `DEMO_STUDIO_ENABLED` env reads. estimate_minutes: 15. Files: main.py. DoD: T.1 xfails flip green; `grep DEMO_STUDIO\|create_demo_studio_session\|_handle_demo_request_v2` returns zero; existing v1 tests still pass.
- [ ] **T.3** — Delete `tests/test_triage_v2.py`. estimate_minutes: 5. Files: tests/test_triage_v2.py. DoD: file gone; `pytest` collects and passes the remaining test set.
- [ ] **T.4** — Prune README Demo Studio mentions. estimate_minutes: 5. Files: README.md. DoD: no "Demo Studio" token remains in the file.
- [ ] **T.5** — PR + non-author review + merge + deploy. estimate_minutes: 20 (author time; wall-clock includes reviewer + deploy). Files: n/a. DoD: PR merged; prod revision live; parent T.W0.1 can open its 24h observation window.

Total active-agent time: ~55 min. Wall-clock (incl. deploy + 24h parent gate): ~25h.

## Orianna approval

_Pending._
