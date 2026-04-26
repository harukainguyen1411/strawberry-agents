---
date: 2026-04-26
topic: stale-branch-housekeeping
---

# Stale Branch Housekeeping

## What was done

Full merged-branch sweep across local + remote refs after `git fetch --prune`.

## Local branches deleted (21)

aphelios/plan-of-plans-breakdown, aphelios/structured-qa-pipeline-breakdown,
aphelios/uiux-in-process-breakdown, camille-pr-dispatch-t5,
chore/aphelios-reviewer-tooling-breakdown, chore/plan-of-plans-phase-b,
chore/universal-worktree-iso, feedback-docs-tasks,
fix/cross-repo-workflow-three-gate-tautology, frontend-ux-stream-b-xfail,
frontend-ux-stream-e-xfail, orianna-gate-simplification, rakan/retro-dashboard-xfail,
retro-dashboard-phase23-breakdown, retro-dashboard-test-plan, talon/rule-19-guard-hole,
talon/t4-lucian-amendments, test-branch-inv3a-69735,
xayah-coordinator-decision-feedback-test-plan, xayah-feedback-system-test-plan,
feat/t3-senna-amend.

## Remote branches deleted (32)

architecture-consolidation-wave-0, architecture-consolidation-wave-1,
camille-pr-dispatch-t5, chore/plan-of-plans-phase-b, chore/pre-orianna-plan-archive,
chore/universal-worktree-iso, clean-jsonl-since-last-compact,
feat/coordinator-memory-two-layer-boot, feat/orianna-substance-rescope,
feat/prelint-shift-left, feat/rule-16-akali-playwrightmcp-user-flow, feat/t3-senna-amend,
feedback-docs-tasks, feedback-system-T7a, feedback-system-T7b,
fix/cross-repo-workflow-three-gate-tautology, fix/subagent-identity-leak,
frontend-ux-stream-b-xfail, ops/delete-vestigial-workflows-round2, orianna-gate-simplification,
orianna-identity-alignment, physical-guard, rakan/retro-dashboard-xfail,
retro-dashboard-phase23-breakdown, statusline-claude-usage, subagent-identity-propagation,
talon/coordinator-routing-discipline, talon/orianna-claim-contract-work-repo-prefixes,
talon/resolved-identity-enforcement, talon/t4-lucian-amendments,
viktor-rakan/dashboard-phase-1, watcher-arm-source-gate.

## Worktrees removed

All in-repo worktrees under chore/, rakan/, talon/ for the above branches.
Also external worktrees at /private/tmp/ and ~/Documents/Personal/strawberry-worktrees/ for merged branches.

## Anomalies

- `worktree-agent-a9730d726564625c6` (locked worktree at .claude/worktrees/agent-a9730d726564625c6) — cannot delete the local branch because the worktree is locked. Branch tip is reachable from main. Left in place. Duong can remove with `git worktree remove --force` then `git branch -d`.
- `rakan/frontend-ux-stream-b-xfail` worktree had untracked `.claude/logs/` — removed with `--force` since no committed changes.
- Hard skips preserved: `feedback-system-T8` (PR #87 open), `dashboard-T.P2.2` (Viktor in-flight).

## Pattern note

`git branch --merged main` returns far more than "4 breakdown branches" — the audit undercount was because the flagged dirs (chore/, rakan/, talon/, monitor-arming-gate-bugfixes/) visible in git status were worktree parent directories, not individual branches. Full sweep done.
