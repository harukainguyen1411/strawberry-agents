# PR #79 (missmp/company-os) — slack-triage Demo Studio removal — fidelity review

**Date:** 2026-04-23
**Plan:** `plans/in-progress/work/2026-04-23-slack-triage-demo-studio-removal.md` (T.0-T.6)
**Parent:** `plans/in-progress/work/2026-04-23-firebase-auth-loop2d-slack-removal.md` T.COORD.5
**Verdict (advisory):** APPROVE — blocked from posting by sandbox (external-org write)

## What passed
- Rule 12 xfail-first chain: e16059e (four strict xfails) → c9118dc (deletion, xfails flip to PASS) → 91ff83c (v2 test file deletion). Clean ordering on branch.
- Diff exactly matches plan §2 deletion surface: `create_demo_studio_session` (main.py:271-302), `_handle_demo_request_v2` (main.py:523-570), v2 routing branch (main.py:513-516), env reads `DEMO_STUDIO_URL`+`DEMO_STUDIO_ENABLED` (main.py:35-36). Nothing extraneous touched.
- v1 fall-through preserved — `handle_message_event` unconditionally routes non-ignore to `_handle_active_conversation` (matches plan §3).
- `INTERNAL_SECRET` retained per plan "Out of scope" item 4.
- OQ-1.a honored (delete v2 test file rather than retarget).
- OQ-2.a honored (no Demo Studio URL literal fallback).
- Verification grep in PR body reproducible; zero hits confirmed.
- QA-Waiver rationale correct (Rule 16).

## Drift notes (non-blocking)
- PR base branch is `feat/demo-studio-v3` (not `main` as literal plan T.6 reads). Aligns with parent Loop 2d integration-branch convention — plan wording is stale but intent honored.
- Rule 15 satisfied vacuously: no CI workflow covers `tools/slack-triage/`. Called out in PR body. Rule 12/14 rely on agent discipline here.

## Lesson
- Sandbox (Opus subagent) denies posting APPROVE reviews to external orgs (missmp/*) even under `scripts/reviewer-auth.sh`. User must whitelist `gh pr review --approve` for `missmp/` in settings, OR the calling coordinator (Sona) posts on Lucian's behalf. Flag to Sona: when delegating external-org PR reviews to Lucian, expect the post step may be blocked and plan to relay findings through Sona's identity or user confirmation.
- T.1 xfail commit used `pytest.mark.xfail(strict=True)` as plan specified; T.2 removed the markers in the same commit as deletion (the test file is rewritten not amended), avoiding XPASS-strict error. Clean pattern for a pure-deletion task.
