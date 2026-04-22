# PR #32 hotfix re-review — commit-message-vs-diff drift

## Context

Re-ran plan-fidelity on feat/demo-studio-v3 after Viktor's blocker-#0 +
C2/H1/H2/H4 hotfixes. Branch not pushed; reviewed via `git log`/`git show`
against `missmp/company-os` worktree at
`~/Documents/Work/mmp/workspace/company-os`.

## Key learning — commit message rot without amend

`45702a8` had a long commit body describing 5 separate fixes (session
routes, dashboard.html, index.html, preview sandbox, deploy.sh env strip).
Actual diff: `deploy.sh` only, 1 line. The other fixes had already landed
in earlier commits (c138203 / 817a638 / 930b4a2 / 0b3947d). Easy to miss
this drift if you only read the commit body and stat line — always check
the actual diff against the narrative.

Post-push amend is not available (new-commit rule + prior commit means
history rewrite would affect Viktor's signed work). Surfacing the
discrepancy in PR body is the best mitigation. Filed as DR-5.

## Pattern — "scheduled deferral" invariants

Plan §D.1 schedules managed-artifact deletion for Wave 6. Current branch
retains `setup_agent.py`, `managed_session_client.py`, `demo-studio-mcp/`.
Per prior-review acceptance this is correct. When re-reviewing, verify
the *comments* in the source still say "Wave 6 will delete" (main.py:1728,
1747 etc.) — stale comments would be drift worth flagging.

## Invariant gain in hotfix

C2 fix is worth noting: previous branch was silently violating the
Anthropic content-block invariant (stored `"[streamed]"` instead of real
`get_assistant_blocks()`). A working prior-review verdict of GO missed
this because the symptom surfaces only on turn-2+ of tool-using sessions,
which the Wave-1/2/3 unit tests didn't exercise. Reminder: the xfail
test suite added in 05000b8 caught it. TDD working as intended.

## Files referenced

- `plans/in-progress/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md`
- `assessments/work/2026-04-22-lucian-pr32-option-b-plan-fidelity.md`
- `assessments/work/2026-04-22-lucian-pr32-hotfix-plan-fidelity.md`
- `tools/demo-studio-v3/{main.py, agent_proxy.py, stream_translator.py,
  tool_dispatch.py, deploy.sh}` (in company-os worktree)
