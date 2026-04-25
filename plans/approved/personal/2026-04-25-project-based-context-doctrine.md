---
status: approved
concern: personal
owner: karma
created: 2026-04-25
tests_required: false
complexity: quick
qa_plan: none
qa_plan_justification: process/doctrine ADR — no user-observable surface; introduces a new top-level `projects/` directory, a frontmatter field on plans, and a coordinator-boot read. Implementation work (retroactive tagging, Skarner integration) is downstream.
orianna_gate_version: 2
priority: P1
last_reviewed: 2026-04-25
project: agent-network-v1
tags: [architecture, process, projects, context, plan-frontmatter, coordinator-boot, canonical-v1, wave-w0]
related:
  - plans/approved/personal/2026-04-25-unified-process-synthesis.md
  - plans/approved/personal/2026-04-25-plan-of-plans-and-parking-lot.md
  - plans/approved/personal/2026-04-25-architecture-consolidation-v1.md
  - plans/in-progress/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
  - architecture/agent-network-v1/plan-lifecycle.md
  - architecture/agent-network-v1/coordinator-boot.md
  - architecture/plan-frontmatter.md
  - CLAUDE.md
architecture_changes:
  - architecture/agent-network-v1/projects.md
  - architecture/agent-network-v1/plan-lifecycle.md
  - architecture/plan-frontmatter.md
---

# Project-Based Context Doctrine — `projects/<concern>/<slug>.md` as the rich-yet-simple top-level intent

## 1. Context

Today, plans, ADRs, and ideas accumulate in `plans/` and `ideas/` without a unifying notion of the *project* they serve. Coordinators dispatch subagents with `[concern: personal|work]` framing, but a subagent receives no statement of the *goal*, *DoD*, *deadline*, or *budget* of the larger initiative the task belongs to. Plans cross-reference each other via `related:` lists, but there is no canonical "this plan exists to advance project X" link. The agent-network-v1 effort itself — a multi-week, multi-wave program comprising 30+ ADRs — has no single document Duong can hand to an agent and say "this is what we're building."

Duong's directive (verbatim, 2026-04-25): *"one more small thing I want to add to the process. I think we should work project based. The idea is that I would give the project a rich yet simple context of the goal, requirements, DoD, budget, deadline etc. This will then be fed into the process so that agents working on it can have a better look of what exactly they're building."* And separately: *"simple Karma lane, just some additive to the process, but make sure it's well documented and not overlooked in the plans."*

This ADR establishes the project doctrine: where project docs live, the canonical schema (taken from Duong's worked example for agent-network-v1), how plans link to projects (a `project:` frontmatter field), how agents access project context (coordinator dispatch tag + boot-time read of active projects), and the lifecycle (`proposed → active → completed → archived`, no Orianna gate — projects are Duong-authored top-level intents). It also bootstraps the first project, `agent-network-v1`, by writing Duong's verbatim example into `projects/personal/active/agent-network-v1.md` so Wave W0 lands the doctrine and the first project simultaneously.

## 2. Decision

Add a new top-level concept — **project** — sitting *above* the plan lifecycle. A project is a rich-yet-simple statement of intent authored by Duong (or a coordinator on his behalf, ratified by him) that gives every downstream plan/ADR/task a shared context: goal, DoD, deadline, budget, focus areas.

### 2.1 Where projects live

```
projects/
├── personal/
│   ├── proposed/        # drafted but not started
│   ├── active/          # currently being worked
│   ├── completed/       # DoD met, awaiting archival
│   └── archived/        # historical record
└── work/
    ├── proposed/
    ├── active/
    ├── completed/
    └── archived/
```

Mirrors `plans/` concern split. Filenames: `<slug>.md` (no date prefix — projects are long-lived; dates live in frontmatter). Slugs are stable identifiers referenced by every contributing plan, so renaming a project is a high-cost operation (search-and-replace across `project:` fields). Pick the slug carefully at proposal time.

### 2.2 Schema (canonical, taken from Duong's worked example)

YAML frontmatter:

```yaml
---
slug: agent-network-v1
status: active                    # proposed | active | completed | archived
concern: personal                 # personal | work
scope: [personal]                 # subset; "both" rendered as [personal, work]
owner: duong                      # always Duong for v1
created: 2026-04-25
deadline: 2026-04-26              # ISO date or freeform ("EOD Sunday")
claude_budget: resourceful        # resourceful | moderate | conservative | strict
tools_budget: limited             # unlimited | limited | strict
risk: minimal                     # minimal | moderate | significant
user: duong-only                  # personalization scope
focus_on:
  - simple yet structured
  - well designed and documented
  - data transparency and accuracy
less_focus_on:
  - frontend / UI / UX (v1)
related_plans: []                 # auto-populated by /backlog or Skarner
---
```

Body (sections, all required, kept short — "rich yet simple"):

- `## Goal` — one paragraph, prose. The "why."
- `## Definition of Done` — bulleted list of testable conditions.
- `## Constraints` — deadline, budget, risk, scope restated in narrative form.
- `## Decisions` — running log of project-level choices (not per-plan; only those that bind multiple plans).
- `## Out of scope` — explicit non-goals.

Total target length: 1–2 pages. If a project doc balloons past 2 pages, it is probably trying to be a plan; collapse it back.

### 2.3 Plan ↔ project linking

Add a `project: <slug>` frontmatter field to the plan template. Validated by the Orianna gate v2 (amendment): if a plan is authored after this ADR's promotion date and has no `project:` field, Orianna emits a warning (not a reject — some plans are genuinely project-less infrastructure). If `project:` is set, Orianna verifies that `projects/<concern>/active/<slug>.md` OR `projects/<concern>/proposed/<slug>.md` exists.

Already-approved plans that belong to `agent-network-v1` are tagged in a follow-up sweep (out of scope for this plan; see §6 follow-ups).

### 2.4 Agent prompt access

Two integration points:

1. **Coordinator dispatch.** When the coordinator (Sona/Evelynn) dispatches a subagent on a task that belongs to an active project, the dispatch prompt's first line includes both `[concern: <c>]` and `[project: <slug>]`. Subagents reading their startup chain include "if `[project: ...]` is set, read `projects/<concern>/active/<slug>.md` before acting" as step 0 of context loading. Wired in `agents/_shared/quick-planner.md` and the analogous heavy-planner shared role file.

2. **Coordinator boot.** Sona's and Evelynn's startup chains add a step: read `projects/<concern>/active/*.md` to know what's in-flight. Memorize project goals/DoD into working context for the session. Surfaced in `agents/sona/CLAUDE.md` and `agents/evelynn/CLAUDE.md`.

### 2.5 Lifecycle

Four states: `proposed → active → completed → archived`. Transitions:

| From | To | Trigger | Authority |
|------|----|---------|-----------|
| (new) | `proposed` | Duong drafts | Duong |
| `proposed` | `active` | Duong ratifies, work begins | Duong (or coordinator on his ack) |
| `active` | `completed` | DoD met | Coordinator proposes, Duong confirms |
| `completed` | `archived` | retrospection done | Coordinator |
| any | `archived` | obsoleted/cancelled | Duong |

**No Orianna gate.** Projects are top-level intents, not derivative work; the gate exists to keep derivative artifacts honest, which does not apply here. Moves are `git mv` by the coordinator (or Duong) — in particular, the plan-lifecycle PreToolUse guard (`scripts/hooks/pretooluse-plan-lifecycle-guard.sh`) does NOT cover `projects/**` and must not be extended to do so.

### 2.6 Integration with existing ADRs

- **Plan-of-plans ADR** (`plans/approved/personal/2026-04-25-plan-of-plans-and-parking-lot.md`): the `/backlog` skill groups plans by `project:` field as a primary axis (concern × project × priority). Per-project staleness tier may differ — active project's plans get strict staleness, archived project's plans get lenient or auto-archived. Implementation deferred to /backlog skill v1.1.
- **Synthesis ADR** (`plans/approved/personal/2026-04-25-unified-process-synthesis.md`) §6 wave plan: this ADR lands as **Wave W0**, *before* Wave W1+ runs, so Wave W1 plans can be authored already-tagged with `project: agent-network-v1`.
- **Frontend ADR** (`plans/approved/personal/2026-04-25-frontend-uiux-in-process.md`) §UX Spec gate: a project's `less_focus_on:` listing UI/UX provides automatic waiver authority for non-UI projects. The PreToolUse hook gating Seraphine/Soraka reads the active project's `less_focus_on:` and auto-waives when UI/UX is listed.

### Scope — out

- Retroactive `project:` tagging of already-approved plans (follow-up sweep).
- Skarner dashboard rendering of project-grouped backlog (defer to dashboard v1.1).
- Per-project budget burndown / Claude usage attribution (defer; out of scope for doctrine).
- Project-level retrospection format (out of scope; current retrospection format suffices for v1).
- Auto-archival staleness automation (already deferred by plan-of-plans ADR).

## 3. Risks & rollback

- **Adoption friction.** New `project:` field on plans risks being silently omitted. Mitigation: Orianna gate warning (not reject) for first 2 weeks post-promotion; promote to reject after the retroactive sweep lands. Coordinator dispatch templates include `[project: ...]` slot by default.
- **Slug churn.** Renaming a project is high-cost. Mitigation: §2.1 explicit warning; coordinator should challenge any project doc whose slug is not stable.
- **Orianna parallel-promotion race.** Observed in PR-batch tonight: 6 parallel Orianna instances clobbered each other's commit messages because each ran `git commit -am` against a shared index. Mitigation discovered: explicit-pathspec `git commit -- <paths>` per Orianna run. **Deployment caveat for this ADR**: do NOT dispatch parallel Oriannas for project-doctrine + sibling Wave-W0 ADRs in the same minute; serialize, or wait for the per-instance scoped-commit pattern to land. (Tracking that fix is out of scope for content here; flagged for the Orianna maintenance plan.)
- **Rollback.** Doctrine-only — revert is `git revert` of the doctrine commit and `rm -rf projects/`. No data migrations, no live services touched. The `projects/personal/active/agent-network-v1.md` bootstrap file becomes orphan content recoverable from git history.

## 4. Tasks

- [ ] T1 — `kind: docs`, `estimate_minutes: 15`. Files: `architecture/agent-network-v1/projects.md` (new). <!-- orianna: ok -->
  Write the canonical projects doctrine doc: directory layout (§2.1), schema (§2.2), plan linking (§2.3), agent access (§2.4), lifecycle (§2.5), integration notes (§2.6). Cross-link from `architecture/agent-network-v1/README.md` index.
  **DoD**: file exists with all six sections; README links to it; `grep -r "projects/" architecture/agent-network-v1/` returns the new doc.

- [ ] T2 — `kind: docs`, `estimate_minutes: 5`. Files: `architecture/plan-frontmatter.md` (existing).
  Add `project:` to the canonical plan frontmatter spec; mark optional-with-warning for v1, scheduled to become required after retroactive sweep.
  **DoD**: spec lists `project:` with description, allowed values ("must reference an existing `projects/<concern>/{proposed,active}/<slug>.md`"), and current enforcement level (warn).

- [ ] T3 — `kind: docs`, `estimate_minutes: 5`. Files: `architecture/agent-network-v1/plan-lifecycle.md` (existing).
  Add a §"Project linking" subsection: plans declare `project:`; Orianna gate v2 verifies referenced project file exists; this ADR's promotion date marks the cutover.
  **DoD**: subsection added; cross-references `architecture/agent-network-v1/projects.md`.

- [ ] T4 — `kind: bootstrap`, `estimate_minutes: 5`. Files: `projects/personal/active/agent-network-v1.md` (new). <!-- orianna: ok -->
  Write the first project doc using Duong's verbatim example as the body. Slug `agent-network-v1`, status `active`, concern `personal`, scope `[personal, work]`, deadline "EOD Sunday", claude_budget `resourceful`, tools_budget `limited`, risk `minimal`, user `duong-only`. `## Goal`, `## DoD`, `## Constraints`, `## Decisions` (empty placeholder), `## Out of scope`.
  **DoD**: file exists; frontmatter validates against §2.2 schema; body uses Duong's wording verbatim where he gave it.

- [ ] T5 — `kind: code`, `estimate_minutes: 10`. Files: `agents/sona/CLAUDE.md`, `agents/evelynn/CLAUDE.md` (existing).
  Append a "Project context loading" startup step: on boot, list `projects/<concern>/active/*.md` and read each. When dispatching a subagent on project-aligned work, prepend `[project: <slug>]` to the dispatch prompt.
  **DoD**: both coordinator CLAUDE.md files have the new step; step references `projects/<concern>/active/`.

- [ ] T6 — `kind: code`, `estimate_minutes: 5`. Files: `.claude/agents/_shared/quick-planner.md` (existing).
  Add a step-0 to the startup chain: "if dispatch prompt contains `[project: <slug>]`, read `projects/<concern>/active/<slug>.md` before authoring. The project's goal/DoD/constraints frame the plan."
  **DoD**: shared file updated; sync via `scripts/sync-shared-rules.sh` (T7).

- [ ] T7 — `kind: code`, `estimate_minutes: 3`. Files: shared-rules sync.
  Run `scripts/sync-shared-rules.sh` to propagate the T6 update into all agent defs that include the shared file.
  **DoD**: `git diff .claude/agents/` shows updated synced blocks; no agent def is out of sync.

- [ ] T8 — `kind: docs`, `estimate_minutes: 3`. Files: `CLAUDE.md` (existing).
  Add a "Projects" entry to the File Structure table: `projects/<concern>/{proposed,active,completed,archived}/<slug>.md` — top-level intent docs, Duong-authored, no Orianna gate.
  **DoD**: table row added; reference to `architecture/agent-network-v1/projects.md`.

## 5. Test plan

`tests_required: false`. No code surface; all changes are doctrine docs, two CLAUDE.md edits, one shared-rules sync, and a bootstrap content file. Verification is structural:

- `find projects/personal/active -name '*.md'` returns `agent-network-v1.md` after T4.
- `grep -l "project:" plans/proposed/personal/2026-04-25-project-based-context-doctrine.md` matches (this plan is self-tagged).
- `scripts/sync-shared-rules.sh --check` (or equivalent) returns clean after T7.
- Manual smoke: spawn a fresh Evelynn session; confirm she reads `projects/personal/active/agent-network-v1.md` during boot (visible in transcript).

No invariant tests required — the doctrine doesn't add a new universal rule, just a new optional artifact and a coordinator boot read. The §3 Orianna-warning becomes a real test surface only when promoted to reject in the follow-up sweep.

## 6. Follow-ups (out of scope for this plan)

- **Retroactive sweep** — tag every already-approved plan that belongs to `agent-network-v1` with `project: agent-network-v1`. Author: Aphelios; trigger: after this ADR is approved.
- **Orianna `project:` reject promotion** — flip the warning to reject after the retroactive sweep lands.
- **Skarner dashboard v1.1** — render backlog grouped by project.
- **`/backlog` skill v1.1** — group by `project:` axis; per-project staleness tier.
- **Frontend ADR hook integration** — Seraphine/Soraka PreToolUse hook reads active project's `less_focus_on:` for auto-waiver.
- **Orianna per-instance scoped-commit pattern** — `git commit -- <paths>` mitigation for parallel-promotion race (separate ADR).

## 7. References

- `plans/approved/personal/2026-04-25-unified-process-synthesis.md` — Wave W0 placement
- `plans/approved/personal/2026-04-25-plan-of-plans-and-parking-lot.md` — backlog grouping by project
- `plans/approved/personal/2026-04-25-frontend-uiux-in-process.md` — `less_focus_on:` waiver authority
- `plans/in-progress/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md` — Skarner integration target
- `architecture/agent-network-v1/plan-lifecycle.md` — lifecycle interaction
- Duong's directive, 2026-04-25 (quoted §1)

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has a clear owner (karma) and Duong-direct authority quoted verbatim. Tasks T1-T8 are concretely scoped with files, kinds, estimates, and DoD per task. Scope-out and follow-ups are explicit; risks (adoption friction, slug churn, parallel-Orianna race) are acknowledged with mitigations. tests_required:false is appropriately justified — the change surface is doctrine + two CLAUDE.md edits + a bootstrap content file, no executable invariant. Self-tags `project: agent-network-v1` consistent with its own §2.3 doctrine.
