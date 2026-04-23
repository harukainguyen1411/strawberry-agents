---
date: 2026-04-22
author: lucian
concern: work
kind: pr-review-plan-fidelity
pr: missmp/company-os#32
branch: feat/demo-studio-v3
head: 899db2f436444131c5edb810a7ebee52b8d4304b
parent_plan: plans/in-progress/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md
prior_review: assessments/work/2026-04-22-lucian-pr32-option-b-plan-fidelity.md
verdict: GO-WITH-NITS
---

# Lucian — PR #32 hotfix re-review (post 45702a8 / 097b0e1 / 7abd989)

Scope: all 10 commits since prior-review head `35112aa` — xfails (`05000b8`),
C1 (`da09787`), F-C1/C4/C5 + BUG-A2 (`0b3947d`, `817a638`, `930b4a2`,
`c138203`), blocker #0 (`45702a8`), C2/H1/H2/H4 (`097b0e1`), test align
(`7abd989`), F-C2/BUG-B2 (`899db2f`).

## Q1 — Waves 4–6 + cutover match?

Yes. Wave 4 vanilla SSE wired (`main.py:2296 _vanilla_sse_generator`,
`:1787 _vanilla_dispatch_chat`). H2 double-invocation fix restores the
"run_turn fires once per user message" invariant T.C.2 demands. The
behavioural cutover — both `/session/new` UI and Slack `/session`
skipping `create_managed_session` — is live; it actually landed in
pre-hotfix commits, not in 45702a8. 45702a8 itself only strips
`MANAGED_AGENT_MCP_INPROCESS=1` from `deploy.sh`, completing the
env-var piece.

## Q2 — Plan invariants

All §3/§5 invariants hold; hotfixes add three net wins:

- **C2 (097b0e1):** `agent_proxy.run_turn` now persists real
  `get_assistant_blocks()` for both `end_turn` and `tool_use`
  stop-reasons. Honors §5.3 Anthropic content-block contract — which
  was silently violated on the prior-review branch (`"[streamed]"`
  placeholder).
- **H1:** `tool_dispatch._map_error` returns `"content": code`, not
  `str(exc)`. Aligns with §3.4 tool_result never-leak rule.
- **H4:** `stream_translator.handle_stream_error` and `_managed_stream`
  catch both sanitise to `{code, message}` per §3.5.

Rule 12 holds — `05000b8` xfail precedes `da09787` and `097b0e1` impls
on the same branch; `7abd989` flips xfails to green with rationale.

## Q3 — Wave 6 deletion sweep

Not complete; correctly deferred. `setup_agent.py`,
`managed_session_client.py`, `managed_session_monitor.py`,
`tools/demo-studio-mcp/` still present. `main.py:44` still imports
`create_managed_session`; lines 1744–1766 retain managed-path
backward-compat with explicit "Wave 6 will delete" comment. Matches
plan §4 + §D.1 scheduling.

## Q4 — deploy.sh envelope

Matches the Wave-4/5-complete, pre-Wave-6 state. `MANAGED_AGENT_MCP_INPROCESS`
stripped. Remaining `MANAGED_AGENT_ID`, `MANAGED_ENVIRONMENT_ID`,
`MANAGED_VAULT_ID`, `DEMO_STUDIO_MCP_*` scheduled for T.D.4 in Wave 6
(plan line 651). Correct interim state.

## Drift notes

**DR-1 (carried):** PR title/body still stale. Unchanged.

**DR-5 (new):** `45702a8` commit-message rot. Body describes edits to
session routes, dashboard.html, index.html — actual diff is deploy.sh
only (1 line). Other edits landed in c138203 / 817a638 / 930b4a2.
Misleading for bisect and release-please changelog. No amend (new-commit
rule); surface in PR body.

**DR-6 (new):** `test_chat_lazy_create_title_s2.py` BD.C.3 tests
xfailed `strict=False` (7abd989) with rationale "BD.C.4 can re-introduce
if managed path is revisited." Follow-up untracked — add to Wave-6 task
list so the xfail does not calcify.

## Verdict

**GO** — hotfix stack tightens plan fidelity. C2 restores an invariant
the prior-review branch silently violated; H1/H4 close concrete contract
leaks; H2 enforces the once-per-turn run_turn contract. No new structural
divergence. DR-5 and DR-6 are documentation/tracking drift, not code
drift.

— Lucian
