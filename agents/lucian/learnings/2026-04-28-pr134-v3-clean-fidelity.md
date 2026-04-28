# 2026-04-28 — PR #134 plan-fidelity review (demo-studio-v3 mock-to-real-S3)

## Verdict
APPROVE (plan-fidelity lane). 0 BLOCKER / 0 IMPORTANT / 2 NIT.

## What was checked
- Plan: `plans/approved/work/2026-04-28-demo-studio-v3-mock-to-real-s3-migration.md` with §D4.1 canonicalized post-approval against `tools/demo-studio-factory/openapi.yaml`.
- PR head: `missmp/company-os` PR #134, branch `feat/demo-studio-v3-clean`, head `ac64112`.
- Worktree used: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-v3-clean` (already at `ac64112` after `git fetch`).

## Findings
- §D2 cherry-pick set exhaustive (agent UX + S2 client + schema endpoint + Firebase auth + preview iframe + deploy hygiene).
- §D3 drop set: zero functional refs to `factory_client_v2`, `factory_bridge_v2`, `S4_VERIFY_URL`, `/dashboard`, in-process S4 poller in `main.py`/`deploy.sh`. Residuals are comment-grade / historical-plan / fixture-only.
- §D4 new code matches canonical contract: SSE event names `{step_start, step_complete, step_error, build_complete, build_error}`, `/build` body `{"sessionId": …}`, `_TERMINAL_EVENTS = {build_complete, build_error}`, dual-auth via `require_session_or_owner`, idempotency 409 with status+lastBuildAt freshness gate, watchdog with `failure_reason="build_pipeline_timeout"`.
- Three implementation judgments (real-class subclass for fake error, watchdog on `/status` not bare `/session/{sid}`, `update_session_status` vs `update_session_field`) all APPROVED-AS-REASONABLE — no plan amendment needed.

## NITs (non-blocking)
- `tools/demo-studio-v3/docs/adr-2-t7a-s4-verify-ops.md` retains historical `S4_VERIFY_URL` text (documentation only).
- PR body lacks `Closes #N` (project tracking) — plan-link is sufficient on a draft PR.

## Process notes
- Work-scope anonymity scan in `scripts/post-reviewer-comment.sh` blocked the first draft due to agent names in cross-lane note. Removed and resubmitted clean. Lesson: when filing a Cross-lane note: in work-scope, refer to "code-quality lane" / "security lane" not the agent name.
- Used `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-v3-clean` worktree for grep — much faster than `gh pr diff` for branch-wide invariant checks.

## Review URL
https://github.com/missmp/company-os/pull/134#issuecomment-4332407639
