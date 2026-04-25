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

Aphelios breakdown — D1A inline. Five phases (A foundations → B lint hooks → C backlog tooling → D coordinator integration → E gate/merge). TDD ordering: every lint/script implementation task is preceded by a test/fixture task on the same branch (Rule 12). Each task carries `parallel_slice_candidate` per the parallel-slice doctrine; coordinators read the field at dispatch time.

### Phase A — Foundations (scaffolding, template, architecture doc)

Phase A tasks are mutually independent (different files, no shared state). They form the largest parallelisable window in the plan.

- [ ] **T1** — Create `ideas/personal/` and `ideas/work/` directories with `.gitkeep`. estimate_minutes: 10. Files: `ideas/personal/.gitkeep`, `ideas/work/.gitkeep`. DoD: both directories exist on `main` after merge; `git ls-tree main -- ideas/` shows both subdirs; PreToolUse plan-lifecycle guard does NOT fire on writes under `ideas/**` (manual probe: `Write` to `ideas/personal/test.md` succeeds). parallel_slice_candidate: no. blockedBy: none. blocks: T2-fixtures (idea fixture path), T7 (idea-structure lint).

- [ ] **T2** — Extend `plans/_template.md` with `priority:` and `last_reviewed:` frontmatter fields, scoped with a comment that they apply only while in `proposed/`. estimate_minutes: 15. Files: `plans/_template.md`. DoD: template includes both fields with allowed-values comment (`# P0|P1|P2|P3` for priority, `# YYYY-MM-DD` for last_reviewed); no other template field changes. parallel_slice_candidate: no. blockedBy: none. blocks: T13 (migration script reads template), T6 (lint references template).

- [ ] **T3** — Append "## Backlog and parking lot (ideas/)" section to `architecture/agent-network-v1/plan-lifecycle.md` summarising A1–A5 + D1 with backlinks to this ADR. estimate_minutes: 30. Files: `architecture/agent-network-v1/plan-lifecycle.md`. DoD: new section appended; the existing five-phase lifecycle table remains byte-identical (verify with `git diff` shows only additive lines below the table); section ends with link to `plans/approved/personal/2026-04-25-plan-of-plans-and-parking-lot.md`. parallel_slice_candidate: no. blockedBy: none. blocks: T19 (integration smoke verifies doc cross-ref).

### Phase A gate

A-G1: T1, T2, T3 merged on a single branch; pre-commit hooks pass; no functional behaviour change yet (no hooks updated, no scripts added). Phase B may begin.

### Phase B — Lint hooks (TDD: fixtures and tests first, then implementation)

Per Rule 12, B-test tasks land in a commit that precedes the matching B-impl commit on the same branch. Fixture tasks are slice-friendly (separate fixture files, no merge conflict).

- [ ] **T4** — Author golden-file fixtures + xfail unit test for the `pre-commit-zz-plan-structure.sh` `priority:` + `last_reviewed:` extension. estimate_minutes: 45. Files: `tests/hooks/plan-structure/fixtures/proposed-missing-priority.md`, `tests/hooks/plan-structure/fixtures/proposed-bad-priority-value.md`, `tests/hooks/plan-structure/fixtures/proposed-stale-last-reviewed.md`, `tests/hooks/plan-structure/fixtures/proposed-valid.md`, `tests/hooks/plan-structure/test_plan_structure_priority.bats`. DoD: test runs and FAILS xfail with diagnostic referencing T6 task ID; one fixture per assertion case; commit message tagged `chore: xfail for T6`. parallel_slice_candidate: yes. blockedBy: T2. blocks: T6.

- [ ] **T5** — Author golden-file fixtures + xfail unit test for the new `pre-commit-zz-idea-structure.sh` hook. estimate_minutes: 45. Files: `tests/hooks/idea-structure/fixtures/idea-with-tasks-header.md`, `tests/hooks/idea-structure/fixtures/idea-missing-frontmatter-field.md`, `tests/hooks/idea-structure/fixtures/idea-bad-concern-value.md`, `tests/hooks/idea-structure/fixtures/idea-valid.md`, `tests/hooks/idea-structure/test_idea_structure.bats`. DoD: test runs and FAILS xfail with diagnostic referencing T7; covers all forbidden headers from D1 (`## Tasks`, `## Test plan`, `## Design`, `## Decision`, `## Risks`, `## Rollback`, `## Open questions`); commit tagged `chore: xfail for T7`. parallel_slice_candidate: yes. blockedBy: T1. blocks: T7.

- [ ] **T6** — Implement `pre-commit-zz-plan-structure.sh` extension: enforce `priority: P0|P1|P2|P3` and ISO-date `last_reviewed:` on every plan in `plans/proposed/**`. estimate_minutes: 50. Files: `scripts/hooks/pre-commit-zz-plan-structure.sh`. DoD: T4 fixtures all pass (xfail flips to xpass / removed); hook rejects missing priority with message `"plans/proposed/**: priority: field required (P0|P1|P2|P3)"`; rejects bad priority value with message naming the offending value; rejects missing/non-ISO `last_reviewed`; POSIX-portable bash (Rule 10) — no GNU-only `date -d`, use `[0-9]{4}-[0-9]{2}-[0-9]{2}` regex. parallel_slice_candidate: no. blockedBy: T4. blocks: T13.

- [ ] **T7** — Implement new hook `scripts/hooks/pre-commit-zz-idea-structure.sh`: validate `ideas/<concern>/**.md` frontmatter (5 required fields per A2) and reject forbidden headers in body. estimate_minutes: 55. Files: `scripts/hooks/pre-commit-zz-idea-structure.sh`. DoD: T5 fixtures all pass; hook validates `title`, `concern` (∈ `personal|work`), `created`, `last_reviewed` (ISO), `tags`; rejects body containing any forbidden header with the exact error message from §A2 ("this is a plan, not an idea — author it under plans/proposed/<concern>/ instead."); POSIX-portable bash; runs only on changed files in the staged set. parallel_slice_candidate: no. blockedBy: T5. blocks: T8.

- [ ] **T8** — Wire `pre-commit-zz-idea-structure.sh` into the dispatcher (`scripts/hooks-dispatchers/pre-commit` or equivalent). estimate_minutes: 15. Files: `scripts/hooks-dispatchers/pre-commit`, `scripts/install-hooks.sh` (if explicit list). DoD: hook executes on `pre-commit` for staged files under `ideas/**`; smoke: `git commit` against a fixture idea with `## Tasks` header is rejected. parallel_slice_candidate: no. blockedBy: T7. blocks: T9.

- [ ] **T9** — Set `pre-commit-zz-idea-structure.sh` to **warning-only** mode for the first two weeks (per §5 risk row 6). estimate_minutes: 15. Files: `scripts/hooks/pre-commit-zz-idea-structure.sh` (add `STRAWBERRY_IDEA_LINT_LEVEL` env var with default `warn` until `2026-05-09`, then `error`). DoD: warning prints diagnostic to stderr with `[warn]` prefix and exits 0 until sunset date; after sunset hook fails-closed; sunset date written into the script as a constant for easy audit. parallel_slice_candidate: no. blockedBy: T7. blocks: T18.

### Phase B gate

B-G1: T6, T7, T8, T9 merged; all hook tests green; manual probe — committing a proposed plan without `priority:` is rejected (T6 path); committing an idea with `## Tasks` produces a warning until 2026-05-09 (T9 path). Phase C may begin.

### Phase C — Backlog tooling (`/backlog` skill + migration script)

- [ ] **T10** — Author smoke-test fixture + xfail test for `scripts/backlog-list.sh`. estimate_minutes: 40. Files: `tests/scripts/backlog-list/fixtures/personal/proposed-p0-fresh.md`, `tests/scripts/backlog-list/fixtures/personal/proposed-p1-stale.md`, `tests/scripts/backlog-list/fixtures/personal/proposed-p2-fresh.md`, `tests/scripts/backlog-list/fixtures/personal/proposed-p3-stale.md`, `tests/scripts/backlog-list/test_backlog_list.bats`. DoD: test runs and fails xfail; assertions cover sort order (P0 → P3), stale-flag rendering for `last_reviewed > 30 days`, and concern-filter behaviour (`--concern personal` returns only personal). parallel_slice_candidate: yes. blockedBy: T2. blocks: T11.

- [ ] **T11** — Implement `scripts/backlog-list.sh`: enumerate `plans/proposed/**`, read `priority` + `last_reviewed`, emit sorted Markdown table to stdout. estimate_minutes: 55. Files: `scripts/backlog-list.sh`. DoD: T10 tests green; output format matches the §A4 sketch (P-bucketed, count in each bucket, stale tag for >30d); supports `--concern <work|personal>` (default = home concern via `STRAWBERRY_HOME_CONCERN`), `--all`, `--ideas` (lists `ideas/<concern>/**` with 90d staleness threshold per §A5); POSIX-portable bash; no external deps beyond `git`/`awk`/`sed`/`grep`. parallel_slice_candidate: no. blockedBy: T10, T2. blocks: T12, T15, T16.

- [ ] **T12** — Register `/backlog` skill that wraps `scripts/backlog-list.sh`. estimate_minutes: 25. Files: `.claude/skills/backlog.md` (or framework equivalent). DoD: invoking `/backlog` from a coordinator session prints the §A4 output; `--concern`, `--all`, `--ideas`, `--groom` flags all forwarded; skill description names Sona and Evelynn as primary callers. parallel_slice_candidate: no. blockedBy: T11. blocks: T15, T16, T19.

- [ ] **T13** — Author smoke test + xfail for `scripts/backlog-init-priority.sh`. estimate_minutes: 30. Files: `tests/scripts/backlog-init/fixtures/before/`, `tests/scripts/backlog-init/fixtures/after/`, `tests/scripts/backlog-init/test_backlog_init_priority.bats`. DoD: xfail test fixtures show before-state proposed plans with NO `priority:` field, after-state with `priority: P2` injected and `last_reviewed: <today>`; test fails until T14 lands. parallel_slice_candidate: yes. blockedBy: T2, T6. blocks: T14.

- [ ] **T14** — Implement `scripts/backlog-init-priority.sh`: one-shot migration that adds `priority: P2` and `last_reviewed: <today>` to every plan in `plans/proposed/**` lacking those fields. estimate_minutes: 45. Files: `scripts/backlog-init-priority.sh`. DoD: T13 fixtures pass; idempotent (re-run is a no-op); preserves frontmatter ordering and YAML formatting; emits a summary count of files touched; does NOT touch ideas, approved, in-progress, implemented, archived. parallel_slice_candidate: no. blockedBy: T13. blocks: T17.

### Phase C gate

C-G1: T11, T12, T14 merged; tests green; manual probe — running `/backlog` from a coordinator REPL prints a non-empty table (assuming T17 has run). Phase D may begin.

### Phase D — Coordinator startup integration

D-tasks must run serially per coordinator (Sona / Evelynn) — they edit the same startup files. Cross-coordinator they are independent.

- [ ] **T15** — Amend Evelynn startup chain to surface backlog summary on session start. estimate_minutes: 30. Files: `agents/evelynn/CLAUDE.md`, `.claude/agents/evelynn.md` (startup sequence section if applicable). DoD: Evelynn boot reads `scripts/backlog-list.sh --concern personal` output before greeting; top-5 P0/P1 plans + stale-count printed to context; backward-compat — if `backlog-list.sh` exits non-zero (e.g., missing fixtures), boot continues with a warning, never fails-closed. parallel_slice_candidate: yes. blockedBy: T11, T12. blocks: T19.

- [ ] **T16** — Amend Sona startup chain symmetrically for work concern. estimate_minutes: 30. Files: `agents/sona/CLAUDE.md`, `.claude/agents/sona.md`. DoD: same as T15 but `--concern work`; ensure both chains use the same wrapper helper to avoid drift. parallel_slice_candidate: yes. blockedBy: T11, T12. blocks: T19.

### Phase D gate

D-G1: T15, T16 merged; manual probe — fresh Evelynn / Sona session prints the backlog summary in the boot sequence. Phase E may begin.

### Phase E — Migration, cutover, integration smoke

- [ ] **T17** — Run `scripts/backlog-init-priority.sh` against `plans/proposed/personal/**` and `plans/proposed/work/**`; commit the resulting field additions on a single migration branch. estimate_minutes: 30. Files: every existing file in `plans/proposed/**` (read-modify-write of frontmatter only). DoD: every proposed plan has `priority: P2` (or whatever the coordinator hand-edits before commit) and `last_reviewed: <today>`; commit message format `chore: backlog-init priority migration (P2 default)`; no body changes. Coordinators may hand-tune priorities in a follow-up commit. parallel_slice_candidate: wait-bound. blockedBy: T14. blocks: T19.

- [ ] **T18** — Sunset audit: verify the warning-only date constant in T9 (`2026-05-09`) is still the right cutover and the script's date-comparison logic resolves correctly. estimate_minutes: 15. Files: `scripts/hooks/pre-commit-zz-idea-structure.sh` (read-only check), `assessments/2026-05-09-idea-lint-cutover.md` (new short note). DoD: assessment file records (a) the date the warning-only mode flips off, (b) a probe command to verify the flip, (c) link back to this ADR §5. parallel_slice_candidate: yes. blockedBy: T9. blocks: E-G1.

- [ ] **T19** — End-to-end integration smoke: author one idea under `ideas/personal/`, observe `/backlog --ideas` shows it, promote it to `plans/proposed/personal/` (manual coordinator dance per §A3), observe `/backlog` shows it, observe pre-commit lint accepts the new proposed plan, observe deletion of original idea via the promotion commit. estimate_minutes: 45. Files: a throwaway `ideas/personal/2026-04-26-aphelios-smoke.md` + the materialized proposed plan (cleaned up at end); `assessments/2026-04-26-plan-of-plans-smoke.md` (transcript). DoD: smoke transcript saved at the assessments path; transcript shows lint allowing the idea, `/backlog --ideas` listing it, `/backlog` not listing it, then post-promotion the inverse — `/backlog` lists it and `/backlog --ideas` does not. parallel_slice_candidate: wait-bound. blockedBy: T3, T15, T16, T17. blocks: E-G1.

### Phase E gate

E-G1: T17, T18, T19 merged; smoke transcript exists. Plan transitions `in-progress → implemented` (Orianna gate). Coordinators announce backlog grooming as live in next session.

### Cross-cutting notes

- **Hook ordering**: T6 (plan-structure extension) and T7 (new idea-structure hook) are in the `zz-` namespace deliberately — they run last in the pre-commit chain, after secret-scanning and commit-prefix. Maintain that ordering.
- **No raw `git checkout`** — every implementation branch uses `scripts/safe-checkout.sh` or `scripts/worktree-add.sh` (Rule 3).
- **Commit prefix**: every task in this breakdown is `chore:` (Rule 5; nothing under `apps/**`).
- **Bundling concern (Orianna WARN)**: this breakdown ships all five mechanisms (priority, ideas/, /backlog, grooming, staleness). Phase B is the natural cut point if Duong wants to land v1 narrowly — Phases C/D/E (the `/backlog` skill, grooming surface, staleness flag) are structurally separable from priority + ideas/. Coordinators may pause between B-G1 and Phase C if calibration data is desired before shipping `/backlog`. See OQ-K2 below.

### Open questions (Aphelios)

- **OQ-K1** — Should the warning-only sunset date in T9 (`2026-05-09`) be hard-coded or read from a config knob (`config/lint-sunsets.yaml`)? Recommendation: hard-coded for v1; one cutover, no need for a knob.
- **OQ-K2** — Bundling: per Orianna's WARN, would Duong prefer to ship Phase A + Phase B as v1 (priority field + ideas/ lint, no `/backlog` skill yet) and gate Phase C on observed backlog-decay data? Defaulting to no — caller said "breakdown should still proceed for the full ADR as written" — but flagging for explicit confirm.
- **OQ-K3** — Coordinator startup-chain amendments (T15, T16) add ~1s of boot latency for the `backlog-list.sh` shellout. If this is unacceptable, fall back to lazy: print a hint ("`/backlog` to see the queue") and only run the script on demand. Recommendation: measure first, optimise only if >2s.
- **OQ-K4** — Should T19 smoke transcript live under `assessments/` (where it goes for ADR audit) or under `agents/aphelios/` (where it traces back to the breakdown author)? Recommendation: `assessments/` — it's a system-level integration test, not an agent journal entry.
- **OQ-K5** — Orianna signature invalidation: this Edit changes the body bytes of an approved ADR. The plan does not appear to carry a body-hash signature today (only the cosmetic `## Orianna approval` block from the proposed→approved transition). If a body-hash signature is later attached at the `approved → in-progress` step, this Edit will invalidate it; coordinator (Evelynn) should run the demote → re-sign dance per shared rules. Flagging for awareness.

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
