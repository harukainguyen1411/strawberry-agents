# Learning: strawberry-agents infra sync via rsync

Date: 2026-04-19
Topic: syncing agent-infra state between two checkouts

## What happened

`harukainguyen1411/strawberry-agents` was cloned fresh at A3 push (`b4735d4`). All commits
to `Duongntd/strawberry` after that point (session closes, learnings, new plans, agent
memory updates) were never pushed to the new canonical repo.

## Approach that worked

`rsync -av --delete <src>/<dir>/ <dst>/<dir>/` per directory — explicit per-dir invocation
keeps the scope tight and makes it easy to verify no app code leaked. Ran for:
`agents/`, `plans/`, `architecture/`, `assessments/`, `.claude/agents/`, `.claude/skills/`.

## Guardrail check

Post-rsync `git status` showed 66 modified + new files. Manual scan confirmed all paths
were within the allowed agent-infra dirs. No `apps/`, `dashboards/`, or `.github/workflows/`
entries. Safe to commit.

## Result

Commit `6858d16` — 126 files changed (rsync brought in more untracked files than the
short-form git status count), pushed to `harukainguyen1411/strawberry-agents` main.
