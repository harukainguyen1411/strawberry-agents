---
status: approved
concern: personal
owner: azir
created: 2026-04-25
tests_required: false
complexity: complex
orianna_gate_version: 2
tags: [architecture, plan-lifecycle, backlog, parking-lot, prioritization, canonical-v1]
related:
  - architecture/agent-network-v1/plan-lifecycle.md
  - architecture/plan-frontmatter.md
  - plans/in-progress/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
  - plans/in-progress/personal/2026-04-20-agent-pair-taxonomy.md
architecture_changes:
  - architecture/agent-network-v1/plan-lifecycle.md
---

# Plan-of-Plans and Parking Lot — backlog priority surface + raw-idea staging

## 1. Problem & motivation

`plans/proposed/<concern>/` is currently an unordered flat directory. Coordinators (Sona, Evelynn) pick what to promote next by feel — recency, conversational salience, whichever plan was most recently mentioned in chat. There is no mechanically queryable priority signal, no notion of "the next thing to work on," and no place for half-baked ideas to live without forcing them through the full plan structure.

Two pathologies follow:

1. **Backlog drift.** Proposed plans accumulate in `plans/proposed/`. Without a priority field or a top-N surface, lower-value plans get dispatched alongside high-value ones based on recency, not importance. Skarner (the dashboard agent) cannot render a backlog view because there is nothing to rank on.
2. **Premature breakdown.** Today, the only way to capture an idea is to author a full proposed plan — frontmatter, problem statement, design, tasks. For ideas that are clearly not for now ("eventually we should look at X"), this either (a) wastes Aphelios/Kayn cycles on plans that will be obsolete in two weeks, or (b) the idea evaporates because the cost of capturing it correctly is too high.

Duong's directive (verbatim, 2026-04-25): *"We need to have a structured way to backlog and prioritize plans. Currently they are not sorted in any way, and we just do things randomly. There should be more structures in this (plan of plans). also I want a parking lot for ideas, which simply sits there and doesn't need a proposed solution yet because we don't need it yet, so I don't want to waste time and resources to break it down now and then couple weeks later find out the idea is obsolete or the plan is stale"*

This ADR is pre-canonical-v1-lock urgent: the canonical-v1 manifest (`plans/in-progress/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md`) needs to pin this structure before lock or the backlog/parking-lot story will be relitigated post-lock.

## 2. Decision

Add two structural concepts to the plan lifecycle:

1. **Backlog priority surface** — a `priority:` frontmatter field on every plan in `plans/proposed/**`, with values `P0|P1|P2|P3` plus a `last_reviewed:` date field. Mechanically queryable by Skarner. Plans without `priority:` are rejected by Orianna at the `proposed → approved` gate and surfaced to coordinators as "ungroomed" by the `/backlog` skill (see §A4).
2. **Parking lot** — a new top-level directory `ideas/<concern>/` for raw, unbroken-down ideas. Light schema (5 frontmatter fields + 1-2 paragraphs of body). Explicitly NOT a plan: no Orianna gate, no Aphelios breakdown, no test plan, no tasks. The contract: an idea cannot be implemented from this state — it must first promote to `plans/proposed/<concern>/` (a coordinator-authored transition that materializes a full plan).

Both concepts are minimal additions, not new lifecycle phases. The five-phase plan lifecycle (`proposed → approved → in-progress → implemented → archived`) is unchanged. The parking lot sits *upstream* of `proposed/`; the priority field is a property of plans already inside the lifecycle.

### Scope — out

- Skarner dashboard integration of the backlog/parking-lot view (defer to retrospection-dashboard prompt-quality v1.5).
- Karma quick-lane plans — they are authored on-the-fly inside an active session and do not enter the backlog at all.
- Implementation tasks — Kayn's breakdown handles those once this ADR is approved.
- Auto-archive automation. §A5 specifies the staleness *signal*; turning that signal into automatic moves is a separate plan.

## 3. Design

This section answers the five architecture decisions called out in the directive. Each is a numbered subsection (A1–A5) followed by the directory/contract spec (D1) and invariants.

### A1. Backlog priority surface

**Decision.** Add a required `priority:` frontmatter field to every plan in `plans/proposed/**`. Allowed values: `P0|P1|P2|P3`. Add a required `last_reviewed:` field (ISO date) tracked by the coordinator on each grooming pass.

**Semantics.**

| Value | Meaning | Coordinator action |
|-------|---------|-------------------|
| `P0` | Ship-blocker. Coordinator should promote next session unless dependency-blocked. | Top of `/backlog` listing; flagged red in dashboard. |
| `P1` | Important. Pulled into the next 1–2 grooming windows. | Listed prominently. |
| `P2` | Wanted. Not urgent; pulled when P0/P1 are clear. | Listed below the fold. |
| `P3` | Nice-to-have. Borderline parking-lot material; reconsider whether it should be moved back to `ideas/`. | Listed last; flagged for review at every grooming. |

**Why P0–P3 over Eisenhower (importance × urgency) or wave grouping.**

- *Eisenhower (2D)* requires the coordinator to set two values per plan and forces the dashboard to either project to a single dimension or render a 2×2 grid. The directive emphasizes "structured way to backlog and prioritize" — a single ordinal scale satisfies this with the lowest cognitive overhead. Importance/urgency information is implicit in the P0–P3 scale (P0 = both high; P3 = neither).
- *Wave grouping* (e.g., `wave: 1|2|3`) creates explicit batches that need to be reflowed every grooming cycle. P-levels are individually mutable without rebatching everyone else.
- *P0–P3* is a flat ordinal that every engineer recognizes from incident-response triage; Skarner can `SELECT priority FROM plans ORDER BY priority ASC` trivially.

**Mechanical query surface.** Plans live in markdown with YAML frontmatter; Skarner already parses these for the dashboard. Adding two fields adds zero new infrastructure. A `scripts/backlog-list.sh` (deferred to Kayn breakdown) emits a sorted table to stdout.

**Default & enforcement.**

- New plans authored without `priority:` are rejected by the pre-commit plan-structure lint (extension to `pre-commit-zz-plan-structure.sh`).
- Migration: existing proposed plans (today: 3 personal, ~N work) get `priority: P2` injected at ADR landing time as a one-shot script (`scripts/backlog-init-priority.sh`, written by Kayn). Coordinators re-rank at the first grooming pass.

### A2. Parking-lot location and shape

**Decision.** New top-level directory `ideas/<concern>/` (e.g., `ideas/personal/`, `ideas/work/`). One file per idea, named `YYYY-MM-DD-<slug>.md`.

**Why top-level `ideas/` over `plans/parking-lot/`.**

- Ideas are explicitly *not plans*. Putting them inside `plans/` invites Orianna gate logic, structural lint, and PreToolUse plan-lifecycle guards to apply. None of those should fire on ideas.
- A peer directory makes the conceptual separation visible: `plans/` is the lifecycle; `ideas/` is the inbox. Skarner can render them as separate dashboard panels.
- The plan-lifecycle PreToolUse guard (`scripts/hooks/pretooluse-plan-lifecycle-guard.sh`) keys on `plans/approved/`, `plans/in-progress/`, `plans/implemented/`, `plans/archived/` — `ideas/**` is freely writable by any agent.

**Light schema (frontmatter, all required).**

```yaml
---
title: <short title>
concern: <personal|work>
created: <YYYY-MM-DD>
last_reviewed: <YYYY-MM-DD>
tags: [<tag1>, <tag2>]
---
```

**Body.** 1–2 paragraphs of free-form text. Optional context, optional motivating example. Explicitly forbidden: `## Tasks`, `## Test plan`, `## Design`, `## Decision`, or any section header that would imply lifecycle-grade structure. A pre-commit lint (`pre-commit-zz-idea-structure.sh`, deferred to Kayn) rejects ideas with these headers and points the author at A3 (promotion).

**No Orianna involvement.** Ideas are created, edited, deleted, and moved freely. There is no gate, no signature, no approval block.

### A3. Promotion path: idea → proposed plan

**Decision.** Promotion is a coordinator decision, materialized as a *new* proposed plan that the coordinator authors (or dispatches a planner like Azir/Swain to author). The original `ideas/<concern>/<file>.md` is not moved or renamed; it is **deleted** by the coordinator in the same commit that creates the new `plans/proposed/<concern>/<file>.md`.

**Why "delete the idea, author the plan" over "rename in place".**

- The two artifacts have incompatible schemas (idea: 5 frontmatter fields, light body; plan: 8+ frontmatter fields, full structure). A rename-in-place would require partial-write semantics that confuse both the lint and the human reader.
- Deleting the idea on promotion enforces the contract that ideas cannot accumulate "shadow plans." If the plan is later rejected (Orianna REJECT) or archived without implementation, the original idea is gone — a healthy forcing function for coordinators to think hard before promoting.
- The promotion commit message records the lineage: `chore: promote idea/personal/2026-04-25-foo.md to proposed plan`.

**Promotion triggers (coordinator judgment, not automation).**

1. The dependency that made the idea premature has unblocked.
2. A user-facing pain has elevated the idea's urgency past P3.
3. The idea has aged past 90 days *and* the coordinator decides it is still relevant — at this point either promote or delete.

Triggers (1) and (2) are session-driven. Trigger (3) is grooming-driven (see A4).

**Authoring.** The coordinator dispatches an architect agent (Azir for personal, Swain for work) with the idea body as input and a directive to write the proposed plan with `priority:` already assigned. The new plan goes through the standard Orianna gate from there.

### A4. Backlog grooming cadence + `/backlog` skill

**Decision.** Coordinators groom the backlog **once per coordinator session** — at session start (Sona/Evelynn boot), surface the top-5 P0/P1 proposed plans and any `last_reviewed` dates older than 14 days. Add a callable skill `/backlog` that emits this summary on demand mid-session.

**Why per-session over weekly cron.**

- Weekly cron creates an external trigger that competes with Duong's session cadence (variable; sometimes daily, sometimes 4-day gaps). Per-session grooming aligns review with the moments when promotion decisions are actually being made.
- The session-start surface is unavoidable — coordinators see it whether or not they want to. Weekly cron emits to a channel that may be ignored.
- Per-session also naturally throttles: in a heavy week (5 sessions), grooming happens 5 times; in a quiet week (1 session), once. Self-regulating to actual activity.

**`/backlog` skill output (sketch).**

```
## Backlog — personal concern (2026-04-25)

P0 (1)
- 2026-04-25-canonical-v1-lock.md (last_reviewed: 2026-04-25)

P1 (3)
- 2026-04-25-akali-qa-discipline-hooks.md (last_reviewed: 2026-04-25)
- 2026-04-25-qa-two-stage-architecture.md (last_reviewed: 2026-04-25)
- 2026-04-21-daily-agent-repo-audit-routine.md (last_reviewed: 2026-04-21) [STALE — review]

P2 (12), P3 (4) — collapsed; expand with /backlog --all
```

The skill is a thin wrapper over `scripts/backlog-list.sh` (Kayn breakdown).

**Re-rank ritual.** Whenever a coordinator promotes a plan from `proposed → approved`, they bump `last_reviewed:` on every plan they considered (not just the one promoted). This keeps the staleness signal honest.

### A5. Stale detection

**Decision.** Use the `last_reviewed:` field as the staleness signal across both `plans/proposed/**` and `ideas/<concern>/**`.

| Artifact | Stale at | Action |
|----------|----------|--------|
| `plans/proposed/**` plan | `last_reviewed` > 30 days old | Flagged in `/backlog` output; coordinator must re-rank or demote to `ideas/`. |
| `ideas/<concern>/**` idea | `last_reviewed` > 90 days old | Flagged in `/backlog --ideas` output; coordinator must re-confirm relevance, promote, or delete. |
| Any artifact | `last_reviewed` > 180 days old | Hard auto-archive candidate (manual confirmation; auto-move deferred per scope). |

**Why date-based over activity-based (e.g., commit-touched).**

- Activity-based ("plan not commit-touched in N days") conflates "stale" with "stable." A finished, parked-but-still-relevant idea would look identical to an obsolete one.
- `last_reviewed` is an explicit acknowledgment by the coordinator that they re-considered the artifact. The coordinator either confirms (bump date) or decides (promote/demote/delete). This makes staleness a coordinator responsibility, not an automated guess.

**Hook enforcement (deferred to Kayn).** `pre-commit-zz-plan-structure.sh` extension: `last_reviewed:` field required on all plans in `plans/proposed/**` and ideas in `ideas/**`. ISO date format. No auto-archive in this ADR — staleness is surface-only; the `/backlog` skill flags it, the coordinator acts.

### D1. Directory layout + frontmatter contract

**New top-level directory:**

```
ideas/
├── personal/
│   └── YYYY-MM-DD-<slug>.md
└── work/
    └── YYYY-MM-DD-<slug>.md
```

**Idea frontmatter (schema):**

```yaml
---
title: <short title, sentence-case>
concern: <personal|work>
created: <YYYY-MM-DD>
last_reviewed: <YYYY-MM-DD>
tags: [<tag1>, <tag2>, ...]
---
```

**Idea body (allowed):** free-form prose, max 2 paragraphs, no structural headers.

**Idea body (forbidden):** `## Tasks`, `## Test plan`, `## Design`, `## Decision`, `## Risks`, `## Rollback`, `## Open questions`. Any of these triggers the lint with the message *"this is a plan, not an idea — author it under plans/proposed/<concern>/ instead."*

**Plan frontmatter additions (extends existing `plans/_template.md`):**

```yaml
priority: <P0|P1|P2|P3>     # required for plans/proposed/**
last_reviewed: <YYYY-MM-DD> # required for plans/proposed/**
```

`priority:` is removed (or ignored) once a plan moves to `approved/` or beyond — at that point the work is committed and prioritization is moot. `last_reviewed:` is preserved for audit but no longer enforced.

**Amendments to existing docs (architecture changes):**

- `architecture/agent-network-v1/plan-lifecycle.md` — append a new section "## Backlog and parking lot (ideas/)" describing the priority surface (A1), the parking-lot location (A2), promotion path (A3), grooming cadence (A4), and staleness (A5). Two-paragraph summary linking back to this ADR.

The existing five-phase lifecycle table is unchanged.

## 4. Non-goals

- Auto-archive automation (date thresholds in A5 are surfaces, not movers).
- Skarner dashboard panel implementation (defer to retrospection-dashboard prompt-quality v1.5).
- Cross-concern priority comparison (P0 personal vs P0 work — coordinators groom each concern independently).
- Karma quick-lane plan integration (Karma plans don't enter the backlog).
- Idea-to-idea linking, threading, or deduplication tooling (premature).

## 5. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Coordinators set every plan to `P0` ("everything is urgent"). | `/backlog` skill surfaces a P0 count; if >5, prompts coordinator to re-rank. Skarner dashboard renders P0-overload as a red flag in v1.5. |
| Ideas accumulate forever; nobody triages. | A5 staleness flag at 90 days; `/backlog --ideas` shows the count. Trigger (3) in A3 forces a decision. |
| `last_reviewed` becomes a lie (coordinator bumps date without actually reviewing). | This is a social contract risk — no technical fix. Mitigation: the dashboard shows `last_reviewed` history (Skarner v1.5) so a pattern of mass-bumps is visible to Duong. |
| Promotion deletes idea, then plan gets rejected — idea is lost. | Promotion commit is in git history; recovery is `git show <sha>:ideas/<concern>/<file>.md`. Coordinators are warned in the promotion skill output. |
| Ideas dir grows unbounded for ambient/never-actioned thoughts. | A5 90-day staleness + the conscious "delete or promote" ritual at trigger (3). The forcing function works because coordinators see the count at every session start. |
| Parking-lot lint over-fires and rejects legitimate idea content. | Forbidden-headers list is deliberately narrow (the structural ones); freeform body is unconstrained. Lint runs as warning-only for the first two weeks. |

## 6. Tasks

Tasks are out of scope for this ADR — Kayn breakdown handles the implementation work after Orianna approval. The implementation work spans:

1. `ideas/` directory creation + `.gitkeep` files for both concerns.
2. `pre-commit-zz-plan-structure.sh` extension (priority + last_reviewed required for proposed plans).
3. `pre-commit-zz-idea-structure.sh` new hook (forbidden-headers lint, frontmatter validation).
4. `scripts/backlog-list.sh` + `/backlog` skill registration.
5. `scripts/backlog-init-priority.sh` one-shot migration (existing proposed plans → `priority: P2`).
6. Coordinator startup-chain amendment (Sona, Evelynn): surface backlog summary on session start.
7. Architecture doc amendment (`plan-lifecycle.md` new section).
8. `plans/_template.md` update (add `priority:`, `last_reviewed:` frontmatter).

Total estimate: deferred to Kayn. Rough order of magnitude: 3–4 hours of implementation across hooks, scripts, and doc updates.

## Test plan

`tests_required: false` — this ADR is structural meta-work (directory layout + frontmatter contract). Tests belong on the implementation work that Kayn breaks down. Specifically:

- The `pre-commit-zz-idea-structure.sh` hook will get a unit test (golden-file: a valid idea passes, an idea with `## Tasks` fails with the expected message).
- The `pre-commit-zz-plan-structure.sh` extension will get an extension to its existing test (a proposed plan without `priority:` fails with the expected message).
- The `scripts/backlog-list.sh` will get a smoke test (point at a fixture dir, assert the table comes back sorted).

These belong on the Kayn breakdown plan, not this ADR.

## Architecture impact

Touched: `architecture/agent-network-v1/plan-lifecycle.md` — new section "## Backlog and parking lot (ideas/)" appended (see D1). The five-phase lifecycle table is unchanged; the new section is purely additive.

## Rollback

If this structure proves wrong:

1. Revert the lint-hook commits (priority + idea-structure).
2. Strip `priority:` and `last_reviewed:` fields from existing proposed plans (one-shot script, mirror of the migration).
3. Move any extant `ideas/<concern>/*.md` files into `plans/proposed/<concern>/` as proposed plans (with `priority: P3`) or delete them.
4. Revert the `plan-lifecycle.md` amendment.

The rollback is mechanical and reversible because no plan content lives in `ideas/` — only ungraded raw text.

## Open questions

- **OQ1** — Should `priority:` be visible in the dashboard's plan-card UI as a colored badge (P0=red, P1=orange, P2=yellow, P3=gray)? Recommendation: yes, defer to Skarner v1.5 design.
- **OQ2** — Should `/backlog` accept a `--concern <work|personal>` filter, or always emit the coordinator's home concern? Recommendation: default to home concern; `--all` shows both.
- **OQ3** — When Karma authors a quick-lane plan inline, does that plan get a `priority:` field? Recommendation: no — Karma quick-lane plans skip `proposed/` entirely (they go straight to `in-progress/`). The priority field is `proposed/`-only.
- **OQ4** — Should the `last_reviewed` bump on grooming be automated (touch every plan the coordinator considered) or manual (coordinator types the date)? Recommendation: a `/backlog --groom` mode that bumps everything in the displayed list, then prints the diff for the coordinator to commit.

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has clear owner (azir), no unresolved TBDs in gating sections, and answers all five architecture decisions (A1–A5) with concrete defaults plus a directory/contract spec (D1). Authority for promotion is the synthesis ADR §7.5 recommended-default approval (commit `c4be153b`) covering Group A which governs this ADR, plus Duong's 2026-04-25 hands-off Default-track directive. Tests_required:false is correctly scoped — implementation tests belong on the Kayn breakdown. Rollback is mechanical and complete.
- **Simplicity:** WARN: possible overengineering — five interlocking mechanisms (priority field, parking-lot directory, /backlog skill, per-session grooming, staleness tiers at 30/90/180 days) are bundled into one ADR; the staleness thresholds in particular are speculative numbers chosen without observed backlog-decay data. Consider whether v1 could ship priority + ideas/ alone and add staleness/grooming once the backlog has enough history to calibrate the thresholds.
