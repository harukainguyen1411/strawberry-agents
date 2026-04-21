# Sona — Learnings Index

Chronological index of Sona's session learnings. Newest first.

## 2026-04

- [2026-04-21 plan-promote.sh is agent-runnable](2026-04-21-plan-promote-agent-runnable.md) — `scripts/plan-promote.sh` runs under `Duongntd` executor account; admin identity only for Rule 18 self-merge gaps, Rule 19 Orianna-Bypass trailers, and branch-protection config. Duong's plan approval is semantic, not a credential requirement.

- [2026-04-20 Orianna suppression gap](2026-04-20-orianna-suppression-gap.md) — `<!-- orianna: ok -->` is an unpoliced trust primitive; can bypass claim-contract Step C entirely with no audit trail.
- [2026-04-20 Plan-structure hook false-positives](2026-04-20-plan-structure-hook-false-positives.md) — `(d)` and `h)` substrings in prose trigger the estimates hook; brief planners to self-verify `check_plan_structure` before handoff.
- [2026-04-20 Concurrent coordinator close](2026-04-20-concurrent-coordinator-close.md) — shared working tree + multiple closes = staging collisions; use agent-scoped paths, never leave work staged across turns.
- [2026-04-20 Agent-OS unification day](2026-04-20-agent-os-unification-day.md) — migration into strawberry-agents as canonical home; SDK Spike 1; TDD-gate PR #46; recovery from reset-hard incident via reflog tag.
- [2026-04-20 Scope before drafting](2026-04-20-scope-before-drafting.md) — confirm ownership before writing an ADR on someone else's service. "We own X" = whole store, not just API surface.
- [2026-04-17 Two-phase teammate shutdown](2026-04-17-two-phase-teammate-shutdown.md) — collect learnings in phase 1 before `shutdown_request`. Skipping cost 8 agents' memory.
- [2026-04-17 Whack-a-mole to redesign](2026-04-17-whack-a-mole-to-redesign.md) — recognize when incremental fixes become a design signal.
- [2026-04-17 PR base-branch and scope lock](2026-04-17-pr-base-branch-and-scope-lock.md) — always `gh pr diff --name-only` before declaring done.
- [2026-04-16 Agent team context gaps](2026-04-16-agent-team-context-gaps.md) — delegation gaps surface as quality issues, not execution failures.
- [2026-04-15 Managed-agent tool enforcement](2026-04-15-managed-agent-tool-enforcement.md)
- [2026-04-15 Main.py shared-file pattern](2026-04-15-main-py-shared-file-pattern.md)
- [2026-04-15 No env snapshots](2026-04-15-no-env-snapshots.md)
- [2026-04-15 dotenv override](2026-04-15-dotenv-override.md)
- [2026-04-14 TDD discipline](2026-04-14-tdd-discipline.md)
- [2026-04-14 Managed-agents gotchas](2026-04-14-managed-agents-gotchas.md)
- [2026-04-13 Full-replace update tools](2026-04-13-full-replace-update-tools.md) — `update_*` PUT wrappers are footguns; build GET→merge→PUT patch wrappers.
- [2026-04-10 Agent-team coordination](2026-04-10-agent-team-coordination.md)
- [2026-04-10 initialPrompt startup](2026-04-10-initialPrompt-startup.md)
- [2026-04-09 Demo agent system](2026-04-09-demo-agent-system.md)
