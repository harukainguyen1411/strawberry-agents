---
status: in-progress
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

<!-- Aphelios refinement 2026-04-23 — additive: track: annotations, explicit Files:, blockedBy: chain, worktree setup, grep-sweep verification, split PR-vs-deploy tasks. All paths below are relative to `~/Documents/Work/mmp/workspace/company-os/tools/slack-triage/` unless otherwise noted. Repo: `github.com/missmp/company-os`. -->

- [ ] **T.0** — Create worktree for slack-triage removal branch in `company-os` (Rule 3, never raw `git checkout`). estimate_minutes: 5. Files: n/a (git plumbing only). DoD: worktree at `~/Documents/Work/mmp/workspace/company-os-slack-triage-demo-removal/` tracking a new branch `chore/slack-triage-demo-studio-removal` off `origin/main`; `git worktree list` shows it. track: deploy-track (Ekko). blockedBy: none.

- [ ] **T.1** — Xfail regression test (Rule 12; xfail-first discipline). Assert `not hasattr(main, "create_demo_studio_session")`, `not hasattr(main, "_handle_demo_request_v2")`, `"DEMO_STUDIO_URL" not in main.__dict__`, and `"DEMO_STUDIO_ENABLED" not in main.__dict__`. Use `pytest.mark.xfail(strict=True, reason="T.2 not yet applied")` so the test flips green only after deletion. estimate_minutes: 15. Files: `tools/slack-triage/tests/test_demo_studio_removed.py` (new). DoD: 4 xfail assertions committed in a standalone commit referencing plan `2026-04-23-slack-triage-demo-studio-removal`; `pytest tools/slack-triage/tests/test_demo_studio_removed.py` shows 4 XFAIL (not XPASS, not PASS); commit pushed. track: normal-track (Sonnet builder). blockedBy: T.0.

- [ ] **T.2** — Delete `create_demo_studio_session` (main.py:271-302), `_handle_demo_request_v2` (main.py:523-570), the v2 routing branch (main.py:513-516), and env reads for `DEMO_STUDIO_URL` (main.py:36) + `DEMO_STUDIO_ENABLED` (main.py:35). Verify `handle_message_event` still compiles and the v1 fall-through path is reached unconditionally for `demo_request` classifications. estimate_minutes: 20. Files: `tools/slack-triage/main.py`. DoD: (a) T.1's 4 xfails flip to XPASS-with-strict → PASS (remove the xfail marker in the same commit since strict=True otherwise errors on XPASS), (b) `python -c "import main"` succeeds inside the service dir, (c) existing `pytest` collection succeeds. track: normal-track (Sonnet builder). blockedBy: T.1.

- [ ] **T.3** — Delete `tools/slack-triage/tests/test_triage_v2.py` entirely (per §5 OQ-1.a — every non-trivial test patches the deleted symbol and the skip-gate would skip all). estimate_minutes: 5. Files: `tools/slack-triage/tests/test_triage_v2.py` (deletion). DoD: file absent from working tree; `pytest tools/slack-triage/` collects zero tests from that path and the remaining test set passes. track: normal-track (Sonnet builder). blockedBy: T.2.

- [ ] **T.4** — Prune README Demo Studio mentions. Current README has no explicit Demo Studio sentence (verified 2026-04-23: only the `DEMO_RUNNER_URL` env var is documented, no `DEMO_STUDIO_URL`). Task reduces to a grep-confirm + no-op unless hidden prose is found. estimate_minutes: 5. Files: `tools/slack-triage/README.md`. DoD: `grep -i "demo studio\|DEMO_STUDIO" tools/slack-triage/README.md` returns zero lines; if any text is removed it's in a dedicated commit. track: normal-track (Sonnet builder). blockedBy: T.3.

- [ ] **T.5** — Repo-wide grep sweep (verification gate). Confirm the tokens `DEMO_STUDIO_URL`, `DEMO_STUDIO_ENABLED`, `create_demo_studio_session`, `_handle_demo_request_v2` do not appear anywhere under `tools/slack-triage/` (source + tests + README + Dockerfile + requirements.txt). Pin the grep output (expected: empty) to the PR body as a verification block. estimate_minutes: 5. Files: n/a (verification only; output pasted into PR description). DoD: `grep -rE "DEMO_STUDIO_URL|DEMO_STUDIO_ENABLED|create_demo_studio_session|_handle_demo_request_v2" tools/slack-triage/` returns zero matches; grep command + empty output captured in PR body under a `## Verification` heading. track: normal-track (Sonnet builder). blockedBy: T.4.

- [ ] **T.6** — Open PR against `missmp/company-os` main. Title `chore: slack-triage — remove Demo Studio handoff (parent Loop 2d)`. Body links parent plan `plans/in-progress/work/2026-04-23-firebase-auth-loop2d-slack-removal.md` T.COORD.5, this plan, and the Verification block from T.5. Request review from a non-author identity (Rule 18 — `strawberry-reviewers` or `strawberry-reviewers-2`). Non-UI, non-user-flow → `QA-Waiver: slack-triage is a backend-only Slack webhook service, no user-facing UI changes` per Rule 16. estimate_minutes: 10. Files: n/a (PR body + GH metadata). DoD: PR open; review requested; CI green (note: `company-os` has only `ci-demo-config-mgmt.yml` which does not touch `tools/slack-triage/` — expect no CI runs on this PR, which satisfies Rule 15 vacuously; call this out in the PR body so the reviewer knows). track: deploy-track (Ekko). blockedBy: T.5.

- [ ] **T.7** — Non-author review + merge. A reviewer identity other than the PR author approves; agent author then merges (no `--admin`, no `--no-verify`, Rule 18). estimate_minutes: 10 (active author time; reviewer wall-clock extra). Files: n/a. DoD: PR merged to `origin/main` with squash or merge commit; merge SHA recorded. track: deploy-track (Ekko + reviewer). blockedBy: T.6.

- [ ] **T.8** — Deploy to Cloud Run prod. **Manual deploy step** — company-os has no GitHub Actions workflow that auto-deploys `tools/slack-triage/` (only `ci-demo-config-mgmt.yml` exists; see Coordination concerns below). Ekko builds the Docker image, pushes to Artifact Registry, and runs `gcloud run deploy slack-triage --image <new-tag> --region <region>` against the prod project. Smoke-test: send a test Slack `demo_request` message to a test channel and confirm slack-triage routes through v1 spec-gathering (posts the gathering question, **not** a studio URL). estimate_minutes: 20 (active time; deploy propagation adds a few minutes wall-clock). Files: n/a (deploy artifact + Cloud Run revision). DoD: new prod Cloud Run revision live and serving traffic; smoke-test message routed through v1 path; prod revision ID recorded on this plan under an "Executor notes" block. track: deploy-track (Ekko). blockedBy: T.7.

- [ ] **T.9** — 24h observation window (parent T.W0.1 gate). Query Cloud Logging for any `POST /session` references originating from slack-triage over a rolling 24h window post-deploy. If zero hits, sign off; if any hits, investigate (expected: zero — the code path is gone). estimate_minutes: 15 (active log-query time; wall-clock 24h). Files: n/a (Cloud Logging query output pasted as a comment under parent T.W0.1). DoD: 24h log window shows zero `create_demo_studio_session` / `POST /session` emissions from slack-triage; parent plan T.W0.1 marked satisfied. track: deploy-track + verification (Ekko). blockedBy: T.8.

**Task count:** 10 tasks (T.0–T.9). Active-agent time: ~110 min. Wall-clock: ~25h (dominated by T.9's 24h observation window).

### TDD infra note (Rule 12 applicability)

`company-os` does **not** carry the strawberry-agents `tdd-gate.yml` CI workflow or any pre-push hook enforcing xfail-first. The sole workflow present is `ci-demo-config-mgmt.yml`, scoped to `tools/demo-studio-config-mgmt/**` only. Rule 12 therefore applies as **agent discipline** (xfail-first commit T.1 before implementation commit T.2) but is not machine-enforced on this PR. The reviewer should visually confirm the T.1 commit precedes T.2 on the branch.

### Coordination concerns (flagged to Sona / parent plan owner)

1. **No automated deploy pipeline for slack-triage.** `company-os` lacks a Cloud Run deploy workflow for `tools/slack-triage/`. T.8 is a **manual** `gcloud run deploy` against prod. If an existing operational runbook governs slack-triage deploys (check with Duong / Ekko memory), link it into T.8's executor note. **Recommendation:** parent plan T.W0.1 should explicitly note that the 24h observation window starts at **T.8 completion**, not at T.7 (merge).

2. **Cross-repo worktree discipline.** T.0 creates the worktree in the `company-os` workspace. The executor must not `git checkout` directly; use `scripts/safe-checkout.sh` if available in `company-os`, else raw `git worktree add` as the Rule 3 fallback.

3. **No strawberry-agents pre-push hook coverage.** The hooks installed via `scripts/install-hooks.sh` live in strawberry-agents. `company-os` may carry its own hook install script — not audited in this breakdown. If `company-os` pre-push hooks don't exist, Rule 12/13/14 are agent-discipline only on this PR.

4. **Rule 16 (QA) applicability.** slack-triage is a backend-only Slack webhook service with no browser UI; `QA-Waiver:` is the correct path (noted in T.6 DoD). Akali not invoked.

5. **Parent plan dep chain.** This plan's T.8 satisfies parent `2026-04-23-firebase-auth-loop2d-slack-removal.md` T.COORD.5. Parent T.W0.1 then consumes T.9's 24h sign-off to unblock parent W3.

### Open questions surfaced during breakdown

**Sona auto-mode answers (2026-04-23):** OQ-A1 = default (Ekko follows README pointer); OQ-A2 = default (colocated under `tools/slack-triage/tests/`).

- **OQ-A1** — Is there an existing Cloud Run deploy runbook or Makefile for slack-triage that T.8 should follow verbatim, or does Ekko author the deploy commands from scratch? Default assumption: Ekko reads `tools/slack-triage/README.md` "GCP Cloud Functions deployment commands" reference (pointed at in README §Deploy) and executes accordingly.
- **OQ-A2** — Should T.1's xfail file live at `tools/slack-triage/tests/test_demo_studio_removed.py` (colocated) or under a top-level `tests/` tree in `company-os`? Default: colocated — matches the existing `test_triage_v2.py` pattern.

## Orianna approval

APPROVED 2026-04-23 by Orianna (fact-check gate v2).
All load-bearing claims verified against current repo state.
blocks: 0, warns: 0, infos: 6.

## Orianna promotion — approved → in-progress

Promoted 2026-04-23 by Orianna.
All load-bearing claims re-verified against repo state at promotion time.
Parent plan exists at `plans/in-progress/work/2026-04-23-firebase-auth-loop2d-slack-removal.md`.
Symbols `create_demo_studio_session`, `_handle_demo_request_v2`, `DEMO_STUDIO_ENABLED`, `DEMO_STUDIO_URL` confirmed in `company-os` working branch (`feat/demo-studio-v3`) at stated line numbers.
`tests/test_triage_v2.py` skip-gate pattern confirmed.
blocks: 0, warns: 0, infos: 0.
