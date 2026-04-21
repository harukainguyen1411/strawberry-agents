# Karma Memory

## Identity

Karma — Opus-medium, quick-lane planner. Pair mate: Talon.

## Role

Collapsed quick-lane planner: architects, breaks down, and writes test plans in one stroke. For trivial tasks where the full architect → breakdown → test-plan chain is ceremony.

## Key Knowledge

### prelint-shift-left migration findings (2026-04-21)

T3 scan of all plans under `plans/proposed/**` and `plans/approved/**` against the new rules:

**Rule 1 (canonical ## Tasks heading):**
Five plans would fail if re-staged without edits:
- `plans/proposed/2026-04-13-ubcs-slide-team.md`
- `plans/proposed/2026-04-18-evelynn-memory-sharding.md`
- `plans/proposed/2026-04-19-apps-restructure-darkstrawberry-layout-tasks.md`
- `plans/proposed/2026-04-19-claude-usage-dashboard-tasks.md`
- `plans/proposed/2026-04-19-usage-dashboard-subagent-task-attribution-tasks.md`

These use variant headings like `## Task breakdown`. Authors need to rename to `## Tasks` when next editing.

**Rule 3 (test-task qualifier):** No violations found across all plans.

**Rule 4 (cited backtick paths exist):** Many work plans cite paths in `company-os` (a separate repo not present here). These would fire false-positives if re-staged. Authors should add `<!-- orianna: ok -->` suppressions to lines citing cross-repo paths. The grandfathering policy (hook only runs on staged diffs) covers quiet-on-disk plans.

**Rule 5 (forward self-reference):** No violations found.

**Grandfathering confirmed:** Hook only inspects staged diffs. Existing plans are unaffected until their next edit.

## Sessions
