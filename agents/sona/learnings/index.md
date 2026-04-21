# Sona — Learnings Index

Chronological index of Sona's session learnings. Newest first.

## 2026-04

- [2026-04-21 Conftest stub must mirror exception hierarchy](2026-04-21-conftest-stub-must-mirror-exception-hierarchy.md) — exception classes referenced in `except` clauses must exist on the test conftest stub even if never raised; missing stubs produce AttributeError at test collection, not at runtime.
- [2026-04-21 Fastlane pattern for post-impl plan promotion](2026-04-21-fastlane-pattern-for-post-impl-plan-promotion.md) — when impl is verified and ship time is constrained, coordinator may fastlane `approved→in-progress→implemented` transitions under explicit Duong directive using plain `Duongntd` identity + commit trailer audit trail. `proposed→approved` still requires Orianna gate or `harukainguyen1411` bypass.
- [2026-04-21 Admin bypass spiritual vs mechanical enforcement](2026-04-21-admin-bypass-spiritual-vs-mechanical-enforcement.md) — Rule 19 is a system-wide invariant even when `pre-commit-plan-promote-guard.sh` doesn't fire on downstream transitions; agents correctly refuse fastlane requests even on mechanically unguarded transitions.
- [2026-04-21 Bash deny is builder-specific not session-wide](2026-04-21-bash-deny-builder-specific-not-session-wide.md) — Bash unavailability on Viktor/Jayce is sandbox-profile-specific to builder agents; tester and devops agents (Vi, Rakan, Ekko, Heimerdinger) may have Bash available in the same session. Try tester/devops agents before concluding Bash is session-unavailable.
- [2026-04-21 Signing ceremony cost scales with body edits](2026-04-21-signing-ceremony-cost-scales-with-body-edits.md) — body-edit distance since last signature multiplies sign iterations; recently-edited ADRs warrant separate Ekko dispatches even within the ≤2 ADR limit. Also documents `.orianna-sign-stderr.tmp` hygiene gap.
- [2026-04-21 Integration branch as cross-ADR unblocker](2026-04-21-integration-branch-as-unblocker.md) — deliberate integration branch (topological merge order + Viktor pytest pass) surfaces cross-ADR compatibility failures before any branch hits remote; prevents N-simultaneous triage on first shared-branch merge.
- [2026-04-21 Ekko signing context ceiling](2026-04-21-ekko-signing-context-ceiling.md) — signing-heavy loops burn Ekko's context fast (173 and 263 tool uses before "Prompt is too long"); partition multi-ADR signing into batches of ≤2 ADRs per Ekko dispatch.
- [2026-04-21 Phase leads implementation](2026-04-21-phase-leads-implementation.md) — flip ADR approved→in-progress at first impl-agent dispatch, same coordinator turn, not after. Phase must lead or match reality; never lag. Standing Yuumi delegation.
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
