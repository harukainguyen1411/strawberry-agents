# Learning: Plan triage — 6 proposed personal plans (2026-04-23)

## Context

Read-only triage of 6 proposed personal plans awaiting Duong's batch-review decision.
Produced `assessments/plan-triage/2026-04-23-proposed-personal-6-plans.md` and pushed commit `6657b91`.

## Key observations

1. **pre-lint-rename-aware** is the most actionable plan in the batch — quick, no blockers, unblocks every future plan promotion. Should be first to promote.

2. **coordinator-decision-feedback** is well-authored and its primary dependency (memory-consolidation) is now implemented. The main friction is that T9/T10 (coordinator agent-def edits) are harness-denied for Ekko. Needs OQ resolution and task annotation before promoting.

3. **daily-audit-routine depends on Claude Code Routines** — the plan was written assuming this feature exists in Claude Code's web infrastructure. This needs a verification spike before committing to the ~750-min implementation. If the feature doesn't exist or works differently, the orchestration design needs rethinking (launchd cron + `claude` CLI would be a fallback).

4. **agent-feedback-system is coupled to Plans 3 and 5** — the T12 task directly edits the audit-routine plan; the consolidation infrastructure depends on audit-routine's Routines setup. Cannot land cleanly until Plan 3's architecture is verified.

5. **retrospection-dashboard is overscoped for its current state** — it depends on `subagent-task-attribution` (itself unimplemented), requires a new sibling repo, and is a multi-month greenfield project. Better split into "retro-ingestor" + "retro-SPA" phases.

6. **subagent-permission-reliability** is quick and high-value — the only blocking question is whether `PostToolUse` fires for subagent tool calls vs. parent only. A one-paragraph OQ resolution note should unblock it.

## Triage directory pattern

`assessments/plan-triage/` is a new subdirectory (no prior files). Follow the same markdown format as `assessments/plan-fact-checks/` — date-prefixed filename, no YAML frontmatter, human-readable sections.
