# Plan Lifecycle — Phases and Promotion

This document describes how a plan moves through the lifecycle and how the Orianna
agent gates each transition.

---

## Phases

A plan moves through five sequential phases. The directory name reflects the current phase:

| Phase | Directory | Status value |
|-------|-----------|--------------|
| Authoring | `plans/proposed/` | `proposed` |
| Approved | `plans/approved/` | `approved` |
| In progress | `plans/in-progress/` | `in-progress` |
| Implemented | `plans/implemented/` | `implemented` |
| Archived | `plans/archived/` | `archived` |

---

## How to promote a plan

Invoke the Orianna agent with the plan path and target stage:

```
Agent: .claude/agents/orianna.md
Input:
  PLAN_PATH: plans/proposed/personal/2026-04-22-foo.md
  TARGET_STAGE: approved
```

Orianna will:
1. Read the plan.
2. Render **APPROVE** or **REJECT** with rationale.
3. On APPROVE: append a cosmetic `## Orianna approval` block, update `status:`, `git mv`
   the file to the target stage directory, commit with `Promoted-By: Orianna` trailer,
   and push.
4. On REJECT: return the rejection rationale. No file is moved.

---

## Authorization

### Physical enforcement (PreToolUse hook — sole gate)

`scripts/hooks/pretooluse-plan-lifecycle-guard.sh` is wired into `.claude/settings.json`
as a PreToolUse hook for the `Bash` and `Write|Edit|NotebookEdit` tool matchers. It fires
**before** any tool executes, enforcing the following rules for non-Orianna agents:

**Blocked** (non-Orianna agents):
- `Bash` commands that reference protected paths (git mv, mv, cp, rm, etc.)
- `Write` to a **non-existing** file inside a protected directory (new-file creation)

**Permitted** (non-Orianna agents):
- `Edit` or `NotebookEdit` on an **existing** file in a protected directory — agents
  such as Aphelios and Xayah must be able to append Tasks/Test-plan sections to
  in-progress plans.
- `Write` to an **existing** file in a protected directory (overwrite = edit semantics).

Protected directories:
- `plans/approved/`
- `plans/in-progress/`
- `plans/implemented/`
- `plans/archived/`

Identity is resolved in order: framework `agent_type` (Agent-tool subagent dispatch)
→ `CLAUDE_AGENT_NAME` env var → `STRAWBERRY_AGENT` env var → fail-closed. If no
identity can be resolved, the guard rejects access to protected paths. Duong's admin
identities (`harukainguyen1411`, `Duongntd`) are the only bypass; there is no
`Orianna-Bypass:` trailer mechanism and no `_orianna_identity.txt` file.

`plans/proposed/` and its subtrees remain freely writable by any agent (plan authoring).

The PreToolUse guard is the primary enforcement layer. The earlier commit-phase guards
(`pre-commit-plan-promote-guard.sh`, `commit-msg-plan-promote-guard.sh`) were archived
to `scripts/hooks/_archive/v2-commit-phase-plan-guards/` by
`plans/implemented/personal/2026-04-23-plan-lifecycle-physical-guard.md` — at the commit
layer, identity is cheaply spoofable (the Ekko incident, 2026-04-23). The physical
layer prevents the move before it ever reaches git.

### Defence-in-depth at commit phase — pre-staged moves are also gated

`scripts/hooks/pre-commit-plan-lifecycle-guard.sh` runs as a pre-commit hook (auto-picked
up by the strawberry dispatcher). It inspects `git diff --cached --name-status -M` for
plan-lifecycle mutations — renames, additions, deletions, and copies touching a protected
root — and rejects the commit if the calling identity is not Orianna.

Identity is resolved from `$CLAUDE_AGENT_NAME` → `$STRAWBERRY_AGENT`. If both are empty
and `$STRAWBERRY_AGENT_MODE` is also unset, the commit is treated as a human/admin Duong
operation and is permitted. Pure modifications (M status) to already-tracked files in
protected roots are always permitted — this preserves the edit-in-place semantics that
agents like Aphelios and Xayah rely on to append Tasks sections to in-progress plans.

This hook closes the gap where a plan-file move could be pre-staged by an earlier tool
call and then committed via `git commit` without the PreToolUse hook observing the move
directly.

### Bypass detection (post-hoc, non-blocking)

`scripts/orianna-bypass-audit.sh` walks protected plan directories and checks that each
plan file was last introduced by an Orianna-authored commit. It reports orphan files to
stdout and always exits 0. This is detection only — it does not re-introduce a second
gate. Run locally: `bash scripts/orianna-bypass-audit.sh`.

---

## Approval block format

On APPROVE, Orianna appends to the plan:

```markdown
## Orianna approval

- **Date:** YYYY-MM-DD
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** <2-5 sentence rationale>
```

No body-hash signatures. No fact-check artifacts. The approval is captured in the
commit message body and the cosmetic block.

---

## Project linking

Plans may declare a `project: <slug>` field in their frontmatter linking them to an entry under
`projects/<concern>/active/<slug>.md` (or `proposed/`). This is the primary mechanism that
connects a plan to a project's goal, DoD, and budget.

Orianna gate v2 behaviour (from 2026-04-25 onward):

- **No `project:` field** on a plan authored after 2026-04-25 → Orianna emits a **warning** at
  `proposed → approved`. Promote-to-reject once the retroactive sweep lands.
- **`project:` set** → Orianna verifies `projects/<concern>/active/<slug>.md` OR
  `projects/<concern>/proposed/<slug>.md` exists. Missing → reject.

The gate is intentionally lenient (warn-not-reject) for the first adoption window to avoid
blocking infrastructure plans that genuinely have no project parent.

See `architecture/agent-network-v1/projects.md` for the full project doctrine, schema, and
lifecycle.

---

## Authoring

Use `plans/_template.md` for new plans. Required frontmatter:

- `status:` — `proposed`
- `concern:` — `personal` or `work`
- `owner:` — your agent name or `duong`
- `created:` — `YYYY-MM-DD`
- `tests_required:` — `true` or `false`

Plans with `tests_required: true` must include a non-empty `## Test plan` section.

---

## Pre-commit structural lint

`scripts/hooks/pre-commit-zz-plan-structure.sh` runs on every staged `plans/**/*.md`
and enforces five rules (see inline comments in the script). Plans under
`plans/archived/**` and `plans/_template.md` are exempt.

---

## Grandfathered plans (`plans/pre-orianna/`)

Plans predating the Orianna-gate-v2 regime — those lacking `orianna_gate_version: 2`
in their frontmatter — live under `plans/pre-orianna/<phase>/`, where `<phase>` is one
of `proposed`, `approved`, `in-progress`, `implemented`, or `archived`, preserving the
original phase signal.

`plans/pre-orianna/**` is **not** a protected path under the PreToolUse guard
(`pretooluse-plan-lifecycle-guard.sh`). New writes and moves within this tree are freely
permitted for any agent or Duong's admin identity — no Orianna dispatch required.

Both pre-commit structural-lint hooks (`pre-commit-zz-plan-structure.sh`,
`pre-commit-t-plan-structure.sh`) already exempt the `plans/pre-orianna/*` glob
alongside `plans/archived/*` and `plans/_template.md`, so grandfathered plans that fail
current structural rules do not block commits.

For full rationale and the original 131-plan migration, see
`plans/approved/personal/2026-04-21-pre-orianna-plan-archive.md`.

---

## Backlog and parking lot (ideas/)

Two structural concepts extend the plan lifecycle without adding new phases:

### Priority surface (A1)

Every plan in `plans/proposed/**` carries two required frontmatter fields:

```yaml
priority: <P0|P1|P2|P3>     # P0=ship-blocker, P1=important, P2=wanted, P3=nice-to-have
last_reviewed: <YYYY-MM-DD> # ISO date; coordinator bumps on every grooming pass
```

Coordinators (Evelynn, Sona) surface the top-5 P0/P1 plans at session start and on
demand via the `/backlog` skill (a thin wrapper over `scripts/backlog-list.sh`). A plan
missing `priority:` is rejected by the pre-commit plan-structure lint
(`pre-commit-zz-plan-structure.sh` extension, T6 of the ADR breakdown) and surfaced to
coordinators as "ungroomed." `last_reviewed:` dates older than 30 days trigger a stale
flag in `/backlog` output. Once a plan moves past `proposed/`, `priority:` is ignored;
`last_reviewed:` is preserved for audit.

**Grooming cadence (A4).** Once per coordinator session — at boot, coordinators see the
top-5 P0/P1 plans and any stale (`last_reviewed > 14 days`) items. Coordinators bump
`last_reviewed:` on every plan they considered, not just the one promoted.

### Parking lot — `ideas/<concern>/` (A2)

Raw, unbroken-down ideas live under `ideas/personal/` and `ideas/work/`. They are
explicitly *not plans*: no Orianna gate, no Aphelios breakdown, no test plan, no task
list. The `ideas/**` path is freely writable by any agent.

**Idea frontmatter (5 required fields):**

```yaml
---
title: <short title, sentence-case>
concern: <personal|work>
created: <YYYY-MM-DD>
last_reviewed: <YYYY-MM-DD>
tags: [<tag1>, <tag2>]
---
```

**Body:** 1–2 paragraphs of free-form prose. Forbidden section headers: `## Tasks`,
`## Test plan`, `## Design`, `## Decision`, `## Risks`, `## Rollback`, `## Open questions`.
Any of these triggers the idea-structure lint (`pre-commit-zz-idea-structure.sh`) with the
message *"this is a plan, not an idea — author it under plans/proposed/<concern>/ instead."*

**Staleness (A5).** Ideas with `last_reviewed` older than 90 days are flagged in
`/backlog --ideas`. At 90 days a coordinator must either promote the idea to a proposed
plan or delete it. The 180-day threshold is a hard auto-archive candidate (manual
confirmation required; auto-move is out of scope for this ADR).

### Promotion path: idea → proposed plan (A3)

Promotion is a coordinator decision. The coordinator (or a dispatched planner such as
Azir/Swain) authors a new `plans/proposed/<concern>/<slug>.md` with full plan structure
and `priority:` already assigned. The original `ideas/<concern>/<file>.md` is deleted in
the same commit that creates the proposed plan. The commit message records lineage:
`chore: promote idea/personal/YYYY-MM-DD-<slug>.md to proposed plan`.

An idea cannot be implemented from the parking-lot state — it must first enter the
five-phase plan lifecycle via this promotion step.

---

Full rationale, design decisions (A1–A5), directory/contract spec (D1), and task
breakdown live in:
`plans/approved/personal/2026-04-25-plan-of-plans-and-parking-lot.md`

---

## Related

| Item | Purpose |
|------|---------|
| `.claude/agents/orianna.md` | Orianna's callable agent definition |
| `agents/orianna/memory/git-identity.sh` | Sets Orianna's git identity on session start |
| `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` | PreToolUse physical guard — primary enforcement layer |
| `scripts/hooks/pre-commit-plan-lifecycle-guard.sh` | Pre-commit defence-in-depth guard — blocks pre-staged lifecycle moves |
| `scripts/orianna-bypass-audit.sh` | Post-hoc bypass detection (non-blocking) |
| `scripts/hooks/_archive/v2-commit-phase-plan-guards/` | Archived v2 commit-phase guards (superseded) |
| `architecture/archive/v1-orianna-gate/plan-lifecycle.md` | Previous lifecycle doc (v1 regime) |
