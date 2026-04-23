---
title: Parallel subagent writes on shared working tree
area: agent-orchestration
surfaced_at: 2026-04-23
source_session: 2026-04-23 Evelynn CLI session (memory-flow ADR breakdown)
status: deferred
plan: plans/proposed/personal/2026-04-23-subagent-worktree-and-edit-only.md
likelihood: medium
impact: moderate
---

## Context

Today, dispatching Aphelios and Xayah in parallel on the memory-flow ADR breakdown surfaced two distinct failure modes. Both share a root: subagents have fewer guardrails than coordinators — no flock-based serialization, no structural restriction on which tools they may use to touch the filesystem.

## Failure 1 — No subagent-level git serialization

- **Problem:** Multiple subagents dispatched in parallel share one working tree. Each commits to main independently. The flock-based coordinator lock (PR #22, adjacent to `scripts/hooks/inbox-watch-bootstrap.sh`) serializes coordinators (Evelynn vs Sona), not subagents within one coordinator session.
- **Symptom today:** Low-grade `.git/index.lock` contention and potential push rejections when 2+ agents push to main within seconds. In this session: Ekko (pr-lint patch) + Aphelios + Xayah all live at once. No actual corruption hit, but the risk surface is real.
- **Symptom possible:** One agent pulls mid-flight and commits atop another's local-but-unpushed work; the second agent's push rejects; retry loop adds noise. Worst-case edge: two agents race on the same file, one's edit silently clobbered.
- **Mitigation today:** Coordinator discipline — pass `isolation: "worktree"` on each Agent call. Easy to forget (forgotten today).
- **Fix direction:** Hook-based auto-worktree for breakdown/test-plan agent types. See linked plan.
- **Likelihood / Impact:** Medium / moderate.
- **Status:** Deferred. Plan: `plans/proposed/personal/2026-04-23-subagent-worktree-and-edit-only.md`.

## Failure 2 — Breakdown/test-plan agents create sibling files instead of editing ADR inline

- **Problem:** Convention is single-file plans (ADR + Tasks + Test plan sections inline). Breakdown agents (Aphelios, Kayn) and test-plan agents (Xayah, Caitlyn) have the `Write` tool in their agent defs, so they can and sometimes do create `-tasks.md` / `-tests.md` siblings. Xayah's D1A shared-rules discipline held today; Aphelios needed a mid-run SendMessage correction.
- **Symptom today:** Evelynn briefed both agents with the old sibling pattern. Duong caught it. Xayah refused via shared-rules; Aphelios was in flight when caught.
- **Fix direction:** Remove `Write` tool from these 4 agent defs. Restrict to `Read/Edit/Glob/Grep/Bash`. They can modify the ADR, but not create new files. Structural guardrail > coordinator memory.
- **Likelihood / Impact:** Medium / moderate (pattern-drift risk on every ADR session).
- **Status:** Deferred. Plan: `plans/proposed/personal/2026-04-23-subagent-worktree-and-edit-only.md`.

## Workarounds available now

- Coordinators: always pass `isolation: "worktree"` when dispatching Aphelios/Kayn/Xayah/Caitlyn.
- Coordinators: brief breakdown/test-plan agents to edit the ADR inline, never siblings.
- Shared rules in `.claude/agents/_shared/test-plan.md` already enforce inline for test plans — extend same pattern to task breakdowns.

## Fix status

Deferred. Plan authored in parallel: `plans/proposed/personal/2026-04-23-subagent-worktree-and-edit-only.md` (Karma quick-lane). Once approved and implemented, this residual can be marked resolved.
