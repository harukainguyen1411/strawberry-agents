---
date: 2026-04-22
author: lucian
concern: work
kind: pr-review-plan-fidelity
pr: missmp/company-os#32
branch: feat/demo-studio-v3
head: 35112aa7132d20399ed02b171bfdfd14843a0c69
parent_plan: plans/in-progress/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md
task_breakdown: assessments/work/2026-04-22-aphelios-vanilla-api-ship-wave-refresh.md
verdict: GO-WITH-NITS
---

# Lucian — PR #32 plan/ADR fidelity review (Swain Option B vanilla Messages API ship)

## Scope recap

PR #32 is the long-lived `feat/demo-studio-v3` branch. The 21 most recent commits
on top of the prior managed-agent waterline are the Option-B vanilla-Messages-API
ship (Waves 1–5 of Aphelios's wave refresh). Waves 6–8 (setup_agent.py deletion,
demo-studio-mcp retirement, MAL/MAD revert ADRs, E2E smoke, prod cutover) are
intentionally deferred to follow-up work per the plan.

Note on commit count: the delegation prompt cited "13 commits ahead of main";
actual count is 558 because this branch has carried the pre-Option-B history.
The 21 commits that implement Option B start at `bc6b15c` (xfail groundwork)
and end at `35112aa` (test-results regen). I reviewed those 21.

## Architecture invariants — all PASS

| invariant | plan ref | status |
|---|---|---|
| `anthropic.messages.stream(model="claude-sonnet-4-6", ...)` as chat loop | §2, §5.3 | PASS — `agent_proxy.py:119 _MODEL = "claude-sonnet-4-6"`, `messages.stream(...)` at :290 and :325 |
| Tool dispatch is client-side Python registry (not MCP) | §3.4, §5.2 | PASS — `tool_dispatch.py` exports `TOOLS` (5) and `HANDLERS` (4) |
| Tool set: `get_schema`, `get_config`, `set_config`, `trigger_factory`, `web_search` | §3.4, §5.2 | PASS — all 5 in `TOOLS`; `web_search_20241022` correctly absent from `HANDLERS` (Anthropic-hosted) |
| SSE event contract: `text_delta \| tool_use \| tool_result \| turn_end \| error` (+ `cancelled`) | §3.5 | PASS — `stream_translator.py:4-9` docstring enumerates the exact set; `main.py` vanilla-stream path emits only these |
| SYSTEM_PROMPT lifted verbatim from `setup_agent.py` | §5.4 option (a) | PASS — byte-identical 3649-char string in `agent_proxy.py:28` vs `setup_agent.py:43` (verified by diff) |
| `ConversationStore` API: `append/load/load_since/truncate_for_model` | §5.1 | PASS — all four methods present in `conversation_store.py` |
| Firestore subcollection schema `demo-studio-sessions/{id}/conversations/{seq}` | §3.3 | PASS (module implements the single-boundary invariant; Firestore backend optional, in-memory default) |
| `MAX_TURNS=20` cap + `UnexpectedStopReason` + `MaxTurnsExceeded` | §5.3 | PASS — covered by Wave-2 tests flipped green in 27f9d71 |

## Wave-boundary discipline — PASS

Plan (Aphelios wave refresh) requires Waves 1–5 in scope, Waves 6–8 deferred.
Commits map cleanly:

| wave | xfail commit | impl commit | matches plan |
|---|---|---|---|
| Wave 1 | f9a17aa | 775a05a | yes — ConversationStore + SYSTEM_PROMPT lift + run_turn core |
| Wave 2 | 4202dac | 27f9d71 | yes — stream_translator + run_turn tool-use loop |
| Wave 3 | f57c774 | 69ff3d4 | yes — tool_dispatch registry + 4 handlers + error wrapping |
| Wave 4 | 2fcd3fb | c7b5c33 | yes — `/session/{id}/stream` SSE rewire + vanilla path in `main.py` |
| Wave 5 (gap-fill) | 3e90d82 | 2938c6a, edafb0b | yes — Bug 5 preview wiring + dotenv papercut |
| Wave 6 | — | — | correctly deferred: `setup_agent.py`, `managed_session_client.py`, `tools/demo-studio-mcp/` all still present |
| Wave 7 | — | — | correctly deferred (Akali E2E lane) |
| Wave 8 | — | — | correctly deferred (Ekko deploy lane) |

## Rule 12 / Rule 13 compliance — PASS

- Every wave's implementation commit is preceded on the same branch by an xfail
  commit citing the plan.
- T.GAP.2 dotenv fix (edafb0b) is preceded by its regression test (8131fab) with
  `Rule 13: regression test committed before fix` called out in the body. The
  commit is tagged `bug: PR64-dotenv`, matching PR-template expectations.
- T.GAP.1b session.html injection (2938c6a) preceded by Wave-5 xfail skeleton
  (3e90d82). Tagged `bug: PR64-bug5`.
- Four `setup_agent.py` tests xfail'd (6af5458) with explicit Wave-6 rationale
  in commit body. Consistent with plan §4 (setup_agent.py scheduled for deletion).
- `test_chat_returns_json_ack_no_streaming` and `test_chat_body_has_no_sse_framing`
  xfail'd (ccc2402) with "managed-agent SSE path not yet deleted — Wave 6 cleanup"
  rationale. Matches plan deferral.

## PR #64 manual feedback coverage — PASS

| bug | remediation | commit(s) |
|---|---|---|
| Bug 5 — preview iframe 404 (studio.js wired to deleted S1 route) | studio.js:222–239 uses `window.__s5Base + '/v1/preview/'`; main.py:1677 injects `__s5Base`; templates/session.html documents the contract | 3e90d82 (xfail), 2938c6a (impl) |
| dotenv `override=True` stomping shell env | main.py:4 `load_dotenv(override=False)` with comment `shell env (Cloud Run) always wins over .env (dev-only)` | 8131fab (test), edafb0b (fix) |
| Anthropic raw-error leak (T.GAP.3) | auth-error wrapping in `agent_proxy.run_turn` per 69ff3d4 body ("T.GAP.3a parts 1+4 (run_turn auth error wrapping) green"); parts 2+3 (HTTP route sanitization) xfail'd pending Wave 4 — later xfail flipped green in c7b5c33 ("test_anthropic_error_logged_server_side" flipped) | 69ff3d4, c7b5c33 |

Bug 5 and dotenv: both addressed with TDD preamble as plan required.
T.GAP.3 (error sanitization): addressed across Waves 3–4 with xfail-first.

## Plan-slug citation — PASS (20/21)

20 of 21 Option-B commits carry the `plan: 2026-04-21-demo-studio-v3-vanilla-api-ship`
trailer. The one exception (`bc6b15c chore(tests): xfail 13 pre-existing obsolete-subsystem
failures`) references the plan slug in prose instead of a formal trailer:
`"scheduled for Wave 6 deletion per plan 2026-04-21-demo-studio-v3-vanilla-api-ship"`.
Acceptable — the intent and traceability are clear, just not in the conventional
trailer slot.

## Drift notes (negotiable, not blocking)

### DR-1 — PR #32 body/title predate the Option-B pivot

The PR title is still "feat: demo-studio v3 — Managed Agents + MCP architecture"
and the body describes the *old* managed-agent + MCP design. No mention of:
- The vanilla Messages API pivot
- The Option-B plan (`plans/in-progress/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md`)
- Explicit deferral of Waves 6–8
- Rule 16 QA report link (will be added by Akali before merge)

This is a PR-hygiene gap, not a code-correctness gap. Strong recommendation:
Sona rewrite the PR body before merge to reflect what actually ships, cite the
parent plan, and explicitly enumerate Waves 6–8 as follow-up. Without this,
downstream reviewers and the release-please changelog will misdescribe the change.

### DR-2 — Wave-5 gap-fills carried off-plan, not folded into parent

Per the wave-refresh doc, Sona chose to "carry Wave 5 off-plan to keep Orianna
signature intact" (option (a) from the assessment's "Decisions still needed"
section). That's a legitimate choice, but it means the parent plan's phase list
(§8) does not mention T.GAP.1/2/3. A reader arriving at the implemented plan
later will not find these tasks in the inline task list. Suggest a one-line
pointer in the parent plan's final-amend pass at Wave-8 cutover, citing this
assessment as the canonical breakdown.

### DR-3 — Preview `test_onload_set_before_src_assignment` xfail regex rot

Commit 75a1c7c xfail'd `test_ui_fixes.py::TestPreviewAutoLoad::test_onload_set_before_src_assignment`
because the test's regex searches for the deleted S1 route pattern
`/session/.../preview`. Rationale: "The test's pattern needs to be updated
to the S5 URL in a follow-up." That follow-up should be explicit — file a ticket
or add a Wave-6 task so the regex gets refreshed rather than the xfail calcifying.

### DR-4 — MCP service retirement ADR not yet authored

Plan §6 requires `managed-agent-lifecycle-retirement.md` and
`managed-agent-dashboard-retirement.md` to land in `plans/implemented/work/`
during phase D / Wave 6. This PR does not author them, which is correct
for a Waves-1–5 scope — but the follow-up should be tracked so MAL/MAD do
not sit in `implemented/` without their retirement supersedes marker.

## Follow-ups (to be tracked elsewhere; not blocking this PR)

1. Rewrite PR #32 body + title to reflect Option-B reality (DR-1).
2. Wave 6: delete `setup_agent.py`, `managed_session_client.py`, `tools/demo-studio-mcp/`,
   and flip the 4 Wave-6-rationale xfails (6af5458) to proper deletion.
3. Wave 6: author MAL-retirement and MAD-retirement ADRs (DR-4).
4. Wave 6: refresh `test_onload_set_before_src_assignment` regex to S5 URL (DR-3).
5. Wave 6: drop the `ccc2402` "managed-agent SSE path not yet deleted" xfails
   once that path is deleted.
6. Parent plan amend at Wave-8 cutover to cite the off-plan Wave-5 gap-fill
   breakdown (DR-2).

## Out-of-scope / deferred to other reviewers

- Code quality, error-handling ergonomics, defensive-programming posture: Senna.
- Playwright E2E scenarios, QA report per Rule 16: Akali.
- Cloud Run revision health, prod smoke, rollback rehearsal: Ekko.

## Verdict

**GO** — approve with the 4 drift notes as negotiable follow-ups. The code on
this branch honors the Option-B plan's architectural decisions, respects wave
boundaries, preserves the SSE contract and tool registry exactly as specified,
lifts SYSTEM_PROMPT verbatim, and addresses the PR #64 manual-testing bugs
with TDD preamble as the plan required. Waves 6–8 deferrals are explicit
in commit bodies. PR-body rewrite (DR-1) is the only item I would strongly
recommend before Duong sees the merged diff in the changelog.

— Lucian
