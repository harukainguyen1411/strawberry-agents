# Project-Based Context Doctrine

A **project** is a rich-yet-simple statement of intent authored by Duong (or a coordinator on his
behalf, ratified by him) that gives every downstream plan, ADR, and task a shared context: goal,
definition of done, deadline, budget, and focus areas.

---

## 2.1 Directory layout

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

Mirrors the `plans/` concern split. Filenames: `<slug>.md` (no date prefix — projects are
long-lived; dates live in frontmatter). Slugs are **stable identifiers** referenced by every
contributing plan via the `project:` frontmatter field. Renaming a project slug is a high-cost
operation (search-and-replace across all `project:` fields). Pick carefully at proposal time.

---

## 2.2 Schema

YAML frontmatter (canonical shape, taken from Duong's worked example):

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

Body sections (all required, kept short — "rich yet simple"):

| Section | Content |
|---------|---------|
| `## Goal` | One paragraph, prose. The "why." |
| `## Definition of Done` | Bulleted list of testable conditions. |
| `## Constraints` | Deadline, budget, risk, scope restated in narrative form. |
| `## Decisions` | Running log of project-level choices (not per-plan; only those that bind multiple plans). |
| `## Out of scope` | Explicit non-goals. |

**Target length: 1–2 pages.** If a project doc balloons past 2 pages it is probably trying to be a
plan; collapse it back.

---

## 2.3 Plan ↔ project linking

Every plan may declare a `project: <slug>` field in its frontmatter:

```yaml
project: agent-network-v1
```

**Orianna gate v2 behaviour (from this ADR's promotion date):**

- Plan has no `project:` field → Orianna emits a **warning** (not a reject) for the first two
  weeks; promotes to reject after the retroactive sweep lands.
- Plan has `project: <slug>` → Orianna verifies that
  `projects/<concern>/active/<slug>.md` OR `projects/<concern>/proposed/<slug>.md` exists.
  Missing project file → reject.

Already-approved plans that belong to `agent-network-v1` are tagged in a follow-up retroactive
sweep (out of scope for this ADR).

---

## 2.4 Agent prompt access

Two integration points:

### Coordinator dispatch

When Sona or Evelynn dispatches a subagent on a task that belongs to an active project, the
dispatch prompt's first line includes both:

```
[concern: personal]
[project: agent-network-v1]
```

Subagents that receive `[project: <slug>]` read
`projects/<concern>/active/<slug>.md` **before acting** as step 0 of context loading. This is
wired in `.claude/agents/_shared/quick-planner.md` and equivalent heavy-planner shared role
files.

### Coordinator boot

Sona's and Evelynn's startup chains include a step: read `projects/<concern>/active/*.md` to know
what's in-flight. Memorize project goals and DoD into working context for the session. Surfaced in
`agents/sona/CLAUDE.md` and `agents/evelynn/CLAUDE.md`.

---

## 2.5 Lifecycle

| Transition | From | To | Trigger | Authority |
|-----------|------|----|---------|-----------|
| Draft | (new) | `proposed` | Duong drafts | Duong |
| Ratify | `proposed` | `active` | Duong confirms, work begins | Duong (or coordinator on his ack) |
| Complete | `active` | `completed` | DoD met | Coordinator proposes, Duong confirms |
| Archive | `completed` | `archived` | Retrospection done | Coordinator |
| Cancel | any | `archived` | Obsoleted/cancelled | Duong |

**No Orianna gate.** Projects are top-level intents, not derivative work. The Orianna gate exists
to keep derivative artifacts honest — that does not apply here. Moves are `git mv` by the
coordinator (or Duong). The `pretooluse-plan-lifecycle-guard.sh` does **NOT** cover `projects/**`
and must not be extended to do so.

---

## 2.6 Integration notes

- **Plan-of-plans ADR** — `/backlog` skill groups plans by `project:` field as a primary axis
  (concern × project × priority). Per-project staleness tier may differ. Implementation deferred
  to `/backlog` skill v1.1.
- **Synthesis ADR** — this doctrine lands as **Wave W0** so Wave W1+ plans can already be authored
  with `project: agent-network-v1`.
- **Frontend ADR** — a project's `less_focus_on:` listing UI/UX provides automatic waiver
  authority for non-UI projects. The PreToolUse hook gating Seraphine/Soraka reads the active
  project's `less_focus_on:` and auto-waives when UI/UX is listed.

---

## Related

| Item | Purpose |
|------|---------|
| `architecture/agent-network-v1/plan-lifecycle.md` | Plan lifecycle — Orianna gate interactions |
| `architecture/agent-network-v1/plan-frontmatter.md` | Plan YAML frontmatter spec — `project:` field definition |
| `agents/evelynn/CLAUDE.md` | Evelynn boot step — reads `projects/personal/active/*.md` |
| `agents/sona/CLAUDE.md` | Sona boot step — reads `projects/work/active/*.md` |
| `projects/personal/active/agent-network-v1.md` | First bootstrapped project |
| `plans/approved/personal/2026-04-25-project-based-context-doctrine.md` | Originating ADR |
