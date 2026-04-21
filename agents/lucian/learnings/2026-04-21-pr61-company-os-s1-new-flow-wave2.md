# 2026-04-21 — PR #61 company-os S1-new-flow Wave 2 (phases A-I)

## Verdict
Comment-only fidelity review. No structural blocks. Posted via PR-author gh identity because `strawberry-reviewers` lacks repo access on `missmp/company-os` (known gap — see `2026-04-21-pr57-company-os-reviewer-access-gap.md`).

## Review URL
https://github.com/missmp/company-os/pull/61#issuecomment-4288718418

## Key findings
- All 9 phases A-I present, matching ADR §2 surface inventory.
- Zero-config S1 invariant (BD ADR) honored: SAMPLE_CONFIG seeding removed; `initial_context = {}`; agent init message stripped of brand/market.
- MCP in-process invariant (MCP-merge ADR) honored: `get_last_verification` added to FastMCP server on `/mcp`, not a separate service.
- S3 project reuse (S3-reuse ADR) honored: stored projectId forwarded via `trigger_factory_v2(project_id=...)`; returned projectId persisted.
- `/session/{id}/build` remains the single build trigger (no new build route).
- Rule 12 TDD ordering: xfail-first on every phase A-E and F-I (via merged Rakan xfail branch `test/s1-new-flow-xfails-wave2`). PR body's "Phase B exception" is factually wrong in the author's favor — commit log shows `df381c4d` (xfail B) precedes `eb12a01f` (impl B).

## Drift notes (tracked in comment)
- T.S1.17 INTEGRATION=1 contract test — unit-only coverage in PR; follow-up.
- T.S1.18 SSE multiplex-under-load — claimed as TS.GOD.30 but backpressure scenario not in tests.
- T.S1.19 migration dry-run CI step — script supports --dry-run; no CI workflow wiring.
- T.S1.21 slack-relay PR URL missing from PR body — required before prod flip per ADR §2.

## Trap: transition_status vs transition_session_status
Nearly flagged as SE-ADR divergence. The SE kwarg-only constraint is on `transition_status` (per `plans/implemented/work/2026-04-20-session-state-encapsulation.md:146`); main.py calls `transition_session_status` positionally. Different function — not a violation. Always grep for the exact symbol the ADR constrains before firing a structural-block finding.

## Reviewer-auth gap repeat
Second time `strawberry-reviewers` has been repo-blind on company-os (previous: PR #57, #59). Posting as PR-comment via author gh is the current workaround. Formal `--approve`/`--request-changes` verdicts impossible until the reviewer identity gets repo access.
