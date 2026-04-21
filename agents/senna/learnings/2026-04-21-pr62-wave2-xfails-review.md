# PR #62 (missmp/company-os) — Wave 2 xfail skeletons review

**Date:** 2026-04-21
**PR:** https://github.com/missmp/company-os/pull/62
**Author:** duongntd99 (Rakan, agent lane)
**Target branch:** `feat/demo-studio-v3`
**Verdict:** LGTM (comment, non-blocking). Posted as PR comment (not formal review) because `strawberry-reviewers-2` lacks access to `missmp/company-os`.

## Review pattern established for tests-only Wave-2 PRs

For a large tests-only xfail PR (35 xfails + 3 skips), the right Senna review playbook:

1. **Verify counts match PR body.** Grep `@pytest.mark.xfail` and `@pytest.mark.skip` counts against the stated total. Rakan's count was exact.
2. **Check plan-slug + TS.GOD case ID in every reason string.** This is Xayah's coverage ledger — if a reason string drops the case ID, the matrix audit won't map test→requirement.
3. **Verify strict=True on every xfail.** Non-strict xfails can silently hide XPASS regressions.
4. **Verify the claimed "missing" symbols actually are missing on the target branch.** Clone the branch shallow (`gh repo clone --depth 1 --branch <target>`) and grep each patch point. If an impl seam patched in the xfail already exists, the test may accidentally PASS → XPASS-strict failure.
5. **Verify the xfail catches the right failure mode (AttributeError / ImportError / assertion).** `patch("main.foo")` with a non-existent `foo` raises `AttributeError` — xfail catches. Import of a non-existent module raises `ImportError` — xfail catches. Both yield clean xfailed results.
6. **Verify conftest stubs + anyio_backend are inherited.** Root + tests/ conftests stub firestore/google/anthropic/mcp and define `anyio_backend = "asyncio"`. Files in `tests/` inherit these. Outside that directory, they don't.
7. **For "reformulated" xfails, check name-vs-assertion fidelity.** Rakan flagged 3 reformulated tests; 2 had name ≠ assertion drift (test name suggests behavior A, body asserts behavior B). Non-blocking since the xfail still passes, but makes green-flip confusing.

## Concrete findings from PR 62

- Typo: `assert resp.status_code in (503, 500, 503)` — 503 duplicated (TS.GOD.21 test).
- TS.GOD.28 regression test reformulated to test `hasattr(sess, "set_verification_result")` — does NOT exercise the BD ADR "S1 never writes config-domain fields" invariant that TS.GOD.28 is officially about. The docstring acknowledges this.
- TS.GOD.29 `_UPDATABLE_FIELDS` test includes `projectId` in required set, but that field is already present on baseline. Error message will be misleading when impl partially lands.
- TS.GOD.21 MCP lifespan fault-injection test is structurally fragile: patches `main.mount_mcp_sub_router` during request, but ASGITransport lifespan runs once at app module import — patch may miss the real seam once impl lands.
- `X-Internal-Secret: dev-internal-secret` header used in new tests, but repo-wide canonical is `test-internal-secret` (from root conftest). No-op today because `verify_internal_secret` is patched, but a footgun for later tests.

## Auth lane note (persistent)

`missmp/company-os` (work concern repo) does NOT have `strawberry-reviewers-2` (Senna lane) as a collaborator. The `strawberry-reviewers` (Lucian lane) status is unknown — possibly also excluded. For **work-concern PRs**, Senna may need to post as a **PR comment from `duongntd99`** rather than a formal review, because:

- `gh pr review --approve` from `duongntd99` on a `duongntd99`-authored PR = self-approval (Rule 18 violation).
- `scripts/reviewer-auth.sh --lane senna gh pr review` = 404 Not Found on this repo.
- `gh pr comment` (not a review vote, just a comment) = safe on author's own PR.

**Task prompts for work-concern PRs should explicitly state the expected auth path** (e.g. "gh on duongntd99. Post review as a comment on the PR"). PR 62's prompt did exactly that. Future work-concern Senna reviews should check for the same instruction — or escalate to the coordinator if the Senna lane is missing from the repo collaborator list.

## Files / signals confirmed on baseline (`feat/demo-studio-v3`)

- `tools/demo-studio-v3/session.py` — `_UPDATABLE_FIELDS` exists, has `projectId`, missing `verificationStatus` / `verificationReport` / `lastBuildAt`. No `set_verification_result` function.
- `tools/demo-studio-v3/main.py` — has `create_managed_session`, `verify_internal_secret`, `factory_bridge_v2.trigger_factory_v2`; MISSING `start_s4_poller`, `run_s4_poller`, `poll_s4_verify`, `s3_build_sse_stream`, `verification_event_queue_stream`, `emit_sse_event`, `mount_mcp_sub_router`, `create_session` (bare), `delete_session`, `update_session_field`.
- `tools/demo-studio-v3/mcp_app.py` — no `get_tool_registry`.
- `tools/demo-studio-v3/setup_agent.py` — no `get_mcp_url` (MCP URL derivation is inline in `main()`).
- `tools/demo-studio-v3/agent_proxy.py` — no `send_chat_message`, no `anthropic_client`.
- `tools/demo-studio-v3/templates/` — only `preview.html`; NO session template. So TS.GOD.7/8 template-scan xfails will fail on "No session template found" not on the iframe/fullview assertion itself. Still xfails cleanly, but once the session template lands, the first assertion (any file with "session" in name) will find it — and then the iframe/fullview content assertion becomes the real gate.
- `tools/demo-studio-v3/pytest.ini` uses `asyncio_mode = auto`; tests use `@pytest.mark.anyio` + `anyio_backend = "asyncio"` fixture. Mixed-mode but consistent with the rest of the repo.
- No `mcp_tools.py` on baseline — correct per Karma's MCP-merge scope separation.

## Total review time: ~45 minutes
Shallow clone + targeted greps + skim of all 35 xfails. Deep read of conftest, main.py relevant routes, session_store.py, and 4 existing tests for pattern comparison.
