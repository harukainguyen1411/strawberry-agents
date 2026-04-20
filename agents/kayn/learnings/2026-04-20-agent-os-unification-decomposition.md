---
date: 2026-04-20
topic: Agent OS unification — task decomposition
---

# Learnings — Agent OS Unification task decomposition

## What I did

Decomposed Azir's 2026-04-20 agent-os-unification ADR into an executable task list with 9 live phases + 1 deferred follow-up phase. Output: `company-os/plans/2026-04-20-agent-os-unification-tasks.md`.

## Key takeaways

- This migration is **mostly file ops**, not code. Owners skew toward Yuumi (file moves), Camille (git/destructive), Ekko (dirs/scaffolding). Vi writes the invariant tests. Jayce only touches one script (`memory-merge.sh`).
- TDD applies even to shell-script migrations. Every script change got a test-first annotation. Tests are grep-based smoke tests against fixture trees.
- Cross-filesystem migration has **hard safety gates** at 8 points. Duong must approve before destructive ops (deleting agent defs, symlinking workspace `.claude/`, removing `workspace/secretary/`). Non-destructive work can run ahead in parallel.
- Parallelism cut serial 155 min down to ~85 min wall-clock.
- Managed-agent in-flight ADRs pause mid-flight and re-home to `plans/work/proposed/` with a `paused: true` flag — no new implementation work on them.
- Jhin's removal means Senna absorbs PR review. All grep-tests for retired-agent references must also cover `secretary/sona/CLAUDE.md` after porting.

## Gotchas I caught

- The ADR task self-migrates (it's a file in `workspace/company-os/plans/` that must move to `strawberry-agents/plans/work/`). Phase 4.7 excludes the ADR and this task file until last, then copies them in at the end.
- Workspace `.claude/settings.json` may have unique project config. Phase 6.4 checks before `rm -rf` of `workspace/.claude/`.
- Orianna port (earlier cancelled) must NOT be resumed — explicit note in Phase 10 register.
- PR #46 stays open — not ours to close; it's also for Duong's teammate.

## Patterns worth remembering for future decomps

- **Gate notation:** put `[GATE N]` between phases where Duong validates. Makes the execution flow unambiguous when a builder reads the list.
- **Destructive register:** separate table listing every destructive op at the bottom of the task list. Makes approval-tracking trivial.
- **TDD summary table:** collect every test-first pair in one table at the bottom so Vi can execute sequentially without scanning.
- **Wall-clock math:** include a serial-vs-parallel comparison and the dependency ASCII graph. Helpful for Sona scheduling.
