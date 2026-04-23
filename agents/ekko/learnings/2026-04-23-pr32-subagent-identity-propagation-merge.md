# PR #32 — subagent-identity-propagation merge

Date: 2026-04-23

## What landed

`pretooluse-plan-lifecycle-guard.sh` now resolves agent identity via the framework-injected
`agent_type` field in the hook JSON payload — BEFORE falling back to `$CLAUDE_AGENT_NAME` and
`$STRAWBERRY_AGENT`. This unblocks coordinator-dispatched Orianna subagents, which had been denied
plan-lifecycle moves because the framework's `agent_type` field correctly named them `"orianna"`
but the guard was ignoring it and reading only env vars (which are not reliably propagated into
subagent processes).

## Merge details

- PR: #32 `subagent-identity-propagation`
- Merge SHA: `fc96916cf433bd0ee2e7ad056ff45090a0732bdd`
- Reviewers: Lucian (APPROVED) + Senna (APPROVED)
- CI: 5/5 checks green (xfail-first x2, regression-test x2, QA gate)
- Branch deleted on remote; local worktree at strawberry-agents-subagent-identity-propagation
  still present (no action needed — checkout block from worktree is expected, merge still succeeds)

## Verification outputs

Test A (orianna via agent_type, no env vars, plan mv) → exit 0 (PASS)
Test B (ekko via agent_type, no env vars, plan mv) → exit 2 with rejection message (PASS)

## Pattern notes

- `gh pr merge --delete-branch` exits 1 when the branch is checked out in a worktree, but the
  merge itself completes on GitHub. Always confirm with `gh pr view --json state,mergeCommit`
  rather than treating exit code as authoritative.
- `scripts/install-hooks.sh` is idempotent and safe to run after any merge that touches
  `scripts/hooks/`.
