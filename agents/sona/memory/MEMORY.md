# Sona (Head coordinator — migrated into strawberry 2026-04-20)

## Sessions
- **2026-04-20 (session 2, agent-OS unification day):** migrated INTO strawberry-agents as canonical home. Scope: Sona folder fully, 55 learnings from 14 other agents, strawberry agent defs untouched. Lux's Spike 1 resolved both SDK gaps for managed-agent lifecycle (native `agent_id` filter + `updated_at` timestamp; appendix on lifecycle ADR). Ekko's TDD-gate PR landed as #46 after #45 cleanup (Jhin caught 34 out-of-scope files). Azir+Kayn produced unification ADR and task list. Recovery incident: 25 agent defs wiped by `git reset --hard`, restored from reflog tag `recovery-point-2026-04-20`. Full summary in `last-session.md`.

## Active decisions
- **Canonical home is strawberry-agents.** Workspace is domain/data only going forward.
- **Two secretaries, shared roster:** Sona (work) here, Evelynn (personal) already here. Memory and learnings are shared across both concerns; only `plans/`, `architecture/`, `assessments/` split into `work/` + `personal/` subtrees.
- **Retired work-only agents:** jhin, karma, nami, nautilus, thresh, zilean, demo-agent, janna, orianna (workspace version). Jhin's PR-review role → Senna.
- **Context-injection:** subagents receive concern via `[concern: work]` or `[concern: personal]` prompt-prefix (per unification ADR).

## Key knowledge
- **Workspace deny-all gitignore:** `~/Documents/Work/mmp/workspace/` ignores `*` with allowlist. Never `git add -A` there — `.claude/` and `secretary/` are untracked and will be wiped by `git reset --hard` if ever force-staged. Tag `recovery-point-2026-04-20` in workspace reflog preserves pre-reset state.
- **AI-native time estimates:** budgets are minutes, not hours. Translate human-authored plans before passing to agents.
- **PR scope discipline:** always `gh pr diff --name-only` before declaring a PR done; fresh branch cherry-picks beat ad-hoc cleanups when a branch drifted.
- **Closed PRs are permanent:** no GitHub API/UI to delete. Only Support can remove.
- **Coordinator ≠ errand runner:** Sona's session-close, memory, and learnings are first-person Sona work, not Yuumi work.

## Pointers
- [2026-04-20 Agent-OS unification day](../learnings/2026-04-20-agent-os-unification-day.md) — process learnings from the migration.
- Unification ADR (still in workspace until Phase 4): `~/Documents/Work/mmp/workspace/company-os/plans/2026-04-20-agent-os-unification.md`.
- Task decomposition: same folder, `...-agent-os-unification-tasks.md`.
- Paused ADRs (to move under `plans/work/`): managed-agent-lifecycle, managed-agent-dashboard-tab, session-state-encapsulation (all dated 2026-04-20).

## Open threads
- **Next session priority:** wire strawberry routing — "Hey Sona" → work concern → `secretary/sona/` startup.
- Phase 9.5: Skarner audit of merged learnings indexes once migration settles.
- PR #46 (`missmp/company-os`) open for teammate; strawberry's own TDD gate still governs strawberry repos separately.
