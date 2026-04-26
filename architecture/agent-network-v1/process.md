# agent-network-v1 — Unified Process

This is the canonical authority for the end-to-end execution process of the Strawberry agent
network. It covers the full journey from idea to post-deploy retrospective. The five source ADRs
listed in §Cross-references remain the authoritative specifications for their respective
subsections; this document joins them into a single navigable pipeline.

**Version:** v1 (2026-04-26)
**Lock status:** candidate for canonical-v1 lock manifest pin
**Source synthesis:** `plans/approved/personal/2026-04-25-unified-process-synthesis.md`

---

## Overview

The pipeline has ten stages (0–9). Each stage is named, owned, gated, and produces a defined
artifact. Five fast-path patterns (FP1–FP5) describe where parallel dispatch buys speed without
sacrificing quality. Fourteen quality non-negotiables name what must not be cut.

```mermaid
flowchart TD
  A["IDEA<br/>ideas/&lt;concern&gt;/YYYY-MM-DD-slug.md<br/>5-field frontmatter<br/>(ADR #1 §A2)"] -->|coordinator decides<br/>idea is ready| B
  B["PROPOSED PLAN<br/>plans/proposed/&lt;concern&gt;/...<br/>+priority: P0-P3<br/>+last_reviewed:<br/>+qa_plan:<br/>+§UX Spec if UI<br/>(ADR #1+#3+#5)"] -->|Orianna fact-check<br/>+priority+qa_plan+UX<br/>(see §Stage 2)| C
  B -->|REJECT| B
  C["APPROVED PLAN<br/>plans/approved/&lt;concern&gt;/...<br/>orianna_signature_approved"] -->|coordinator dispatches<br/>parallel-slice fan-out| D
  D["BREAKDOWN + DESIGN-FILL<br/>parallel:<br/>• Aphelios/Kayn task list<br/>• Lulu/Neeko UX Spec amend<br/>• Caitlyn QA Plan amend<br/>(ADR #5 D6, ADR #3 D5)"] --> E
  E["IMPL — xfail-first<br/>plans/in-progress/&lt;concern&gt;/...<br/>orianna_signature_in_progress<br/>Rule 12 enforced<br/>Rule 22 gate (UX Spec)"] -->|first interactive<br/>surface ready| F
  E -->|backend-only<br/>or fully impld| G
  F["STAGE-2 (parallel observers)<br/>• Akali smoke — ON-TRACK/DRIFT/BLOCKED<br/>(ADR #3 D3)<br/>• Lulu usability — friction/affordance/copy<br/>(ADR #5 D4)"] --> E
  G["DRAFT PR<br/>+QA-Draft: marker<br/>+Design-Spec: marker<br/>+Accessibility-Check: marker<br/>+Visual-Diff: marker<br/>+Plan: marker<br/>(ADR #5 D7)"] --> H
  H["STAGE-3 PRE-MERGE<br/>• Akali OBSERVES (cite_kind tagged)<br/>• Senna 5-axis review (correct/sec/scale/reli/test)<br/>• Lucian 5-axis review (plan/ADR/contract/defer/cross-repo)<br/>• Camille if security-blast-radius<br/>(ADR #4 D2/D3/D6, QA two-stage ADR)"] -->|Senna DIAGNOSES<br/>FAIL/PARTIAL inferred| H
  H -->|all green +<br/>1 non-author approve<br/>(Rule 18)| I
  I["MERGE<br/>plans/implemented/&lt;concern&gt;/...<br/>orianna_signature_implemented"] --> J
  J["STAGE-4 POST-DEPLOY<br/>• stg smoke<br/>• prod smoke<br/>• auto-rollback on prod fail<br/>(Rule 17)"] --> K
  K["RETRO + REVIEWER AUDIT<br/>• post-merge bug correlation<br/>• reviewer calibration drift<br/>• ideas spawned → ideas/<br/>(ADR #4 D8)"]
  K -.->|new ideas surface| A
```

### Stage summary table

| Stage | Name | Owner | Gate | Artifact |
|-------|------|-------|------|----------|
| 0 | Parking lot | Coordinator / any agent via inbox | None | `ideas/<concern>/YYYY-MM-DD-<slug>.md` |
| 1 | Promote idea → plan | Coordinator + Swain/Azir | Coordinator judgment | `plans/proposed/<concern>/...` |
| 2 | Orianna approve gate | Orianna agent | Frontmatter + body section linter | `plans/approved/<concern>/...` |
| 3 | Breakdown + design-fill (parallel) | Aphelios/Kayn + Lulu/Neeko + Caitlyn | None — parallel-slice doctrine | Inline task list + §UX Spec amend + §QA Plan amend |
| 4 | Implementation (xfail-first) | Implementer agent | Rules 12/13/14/22 | Code commits on PR branch |
| 5 | Parallel observers (mid-build) | Akali + Lulu, coordinator-dispatched | Advisory (v1) | QA-Draft block + friction notes |
| 6 | Pre-merge | Akali + Senna + Lucian + Camille (conditional) | Rules 16/18 + reviewer-discipline primitive | `assessments/qa-reports/<concern>/<slug>/...` |
| 7 | Merge | PR author + Orianna re-sign | Rule 18 + CI green | `plans/implemented/<concern>/...` |
| 8 | Post-deploy | CI smoke + auto-rollback | Rule 17 | Smoke logs + rollback artifact |
| 9 | Retro + reviewer audit | Skarner v2 / Duong spot-check | None | `assessments/retrospectives/<concern>/...` |

---

## Stage 0 — Parking lot

**Owner:** Coordinator authors; any agent may suggest via inbox.
**Gate:** None — free write.
**Artifact:** `ideas/<concern>/YYYY-MM-DD-<slug>.md`

Ideas that are not ready for breakdown live in `ideas/<concern>/`. A 5-field frontmatter
captures title, created date, concern, source (agent or human), and status. Ideas cannot be
implemented directly — they must first be promoted to `plans/proposed/<concern>/` (see Stage 1).

A coordinator-dispatched `pretooluse-ideas-impl-guard.sh` hook is a candidate for v2
enforcement; in v1 coordinator discipline is the guard.

**Authority:** ADR #1 §A2 (plan-of-plans-and-parking-lot)

---

## Stage 1 — Promote idea → plan

**Owner:** Coordinator decides; dispatches Swain (personal) or Azir (work) to author the plan.
**Gate:** Coordinator judgment — no hook gate at this stage.
**Artifact:** `plans/proposed/<concern>/YYYY-MM-DD-<slug>.md` (idea file deleted in the same
commit per ADR #1 §A3 rename-vs-rewrite contract).

When a coordinator promotes an idea it must draft a proposed plan with:

- `priority: P0–P3` (ADR #1 backlog priority)
- `last_reviewed: <today>`
- `qa_plan: required | none` + `qa_co_author:` if required (ADR #3 §D2)
- `## QA Plan` body section if `qa_plan: required`
- `## UX Spec` body section if the plan touches UI surface (ADR #5 §D2 path-glob)
- `## Architecture impact` if the plan touches architecture docs

**Karma quick-lane bypass:** Trivial plans authored by Karma enter at Stage 4 directly,
bypassing Stages 0–2. See `plans/approved/personal/2026-04-25-pre-dispatch-parallel-slice.md`.
Karma quick-lane plans do not carry a `priority:` field.

**Authority:** ADR #1 §A3

---

## Stage 2 — Orianna approve gate

**Owner:** Orianna agent.
**Gate:** Frontmatter completeness (`priority`, `last_reviewed`, `qa_plan`, `qa_co_author`,
`architecture_changes`) + body section presence (`## QA Plan` if `qa_plan: required`,
`## UX Spec` if UI path-glob matches, `## Architecture impact` if applicable) + plan-structure
linter.
**Artifact:** `plans/approved/<concern>/...` with `orianna_signature_approved`.

Orianna fact-checks the plan, renders APPROVE or REJECT, and on APPROVE `git mv`s the file to
`plans/approved/<concern>/`, appends `orianna_signature_approved`, commits, and pushes. Hooks
in `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` block non-Orianna moves out of
`plans/proposed/`.

The gate enforces three contract families in a single check (per synthesis Conflict C5 — single
amendment wave):

1. **ADR #1 fields:** `priority`, `last_reviewed` presence and validity.
2. **ADR #3 fields:** `qa_plan`, `qa_co_author`, `## QA Plan` body section.
3. **ADR #5 fields:** `## UX Spec` body section for UI-touching plans; `UX-Waiver:` accepted
   for non-UI-surface refactors.

**Authority:** ADR #1 §A1, ADR #3 §D2, ADR #5 §D2, `architecture/agent-network-v1/plan-lifecycle.md`

---

## Stage 3 — Breakdown + design-fill (parallel)

**Owner:** Aphelios or Kayn (task breakdown) + Lulu or Neeko (UX Spec amendment, if not
authored at plan time) + Caitlyn (QA Plan amendment, if not authored at plan time) — all
dispatched in parallel in a single coordinator turn.
**Gate:** None — pre-dispatch parallel-slice doctrine.
**Artifact:** Inline task list appended to the plan + amended `## UX Spec` + amended `## QA
Plan`. Plan moves `approved/ → in-progress/` with `orianna_signature_in_progress`.

**Fast-path patterns applicable:**

- **FP1** (UI plan): three-agent parallel fan-out — Lulu/Neeko + Caitlyn + Aphelios/Kayn.
- **FP2** (backend plan with user-observable criteria): two-agent parallel — Senna
  (qa_co_author) + Aphelios/Kayn.

**Authority:** ADR #3 §D5, ADR #5 §D6, `plans/approved/personal/2026-04-25-pre-dispatch-parallel-slice.md`

---

## Stage 4 — Implementation (xfail-first)

**Owner:** Implementer — Aphelios, Karma, Ekko, Seraphine, Soraka, Viktor, Caitlyn, Vi, Jayce.
**Gate:** Rule 12 (xfail commit before impl), Rule 13 (regression test on bug fix), Rule 14
(pre-commit unit tests), Rule 22 (Seraphine/Soraka blocked if `## UX Spec` missing).
**Artifact:** Code commits on a PR branch.

Every implementation commit on a TDD-enabled service must be preceded on the same branch by an
xfail test commit referencing the plan or task. Enforced by pre-push hook and `tdd-gate.yml` CI.
No bypass via `--no-verify`.

Rule 22 is enforced by `scripts/hooks/pretooluse-uxspec-gate.sh`, which blocks Seraphine/Soraka
dispatch when the plan under `plans/in-progress/` is missing a `## UX Spec` section.

**Authority:** CLAUDE.md Rules 12, 13, 14, 22; ADR #5 §D2

---

## Stage 5 — Parallel observers (mid-build)

**Owner:** Coordinator dispatches Akali (smoke mode) + Lulu (usability) when impl reports
"interactive surface ready."
**Gate:** Advisory in v1 (per ADR #3 OQ-3 — promote to hard gate after 4-week observation at
<10% false-positive rate).
**Artifact:** `QA-Draft:` block in PR draft body (Akali); inline coordinator-routed friction
notes (Lulu).

The two observers are parallel, non-conflicting:

- **Akali (smoke mode):** runs Playwright against acceptance criteria; returns ON-TRACK /
  DRIFT / BLOCKED verdict. ~2 min wall-clock (ADR #3 OQ-6).
- **Lulu (usability check):** walks the flow as a fresh user; returns friction / affordance /
  copy-ambiguity notes. ~10 min wall-clock (ADR #5 §D4).

Combined ~12 min total. Camille does NOT fire at Stage 5 (synthesis Conflict C2 resolution —
Camille is review-stage only, not QA-stage).

**Fast-path pattern:** FP3 — two agents in parallel, ~2x wall-clock vs serial.

**Authority:** ADR #3 §D3, ADR #5 §D4, synthesis §5 Conflict C1 resolution

---

## Stage 6 — Pre-merge

**Owner:** Akali (OBSERVES) + Senna (5-axis review) + Lucian (5-axis review) + Camille
(conditional, security-blast-radius).
**Gate:** Rule 16 (Akali run + QA report) + Rule 18 (one non-author approve) +
reviewer-discipline primitive (`_shared/reviewer-discipline.md`).
**Artifact:** `assessments/qa-reports/<concern>/<YYYY-MM-DD>-<slug>/{report.md,
screenshot-*.png, video.webm}` — ADR #2 wrapper frontmatter + ADR #3/QA-two-stage body shape.

### Reviewer lanes

| Reviewer | Mode | Axes |
|----------|------|------|
| Akali | OBSERVES (cite_kind tagged) | Acceptance criteria walked, failure modes, cite_kind/cite_evidence, verdict |
| Senna | DIAGNOSES | Correctness, security, scalability, reliability, test quality (axes A–E) |
| Lucian | DIAGNOSES | Plan fidelity, ADR/contract conformance, deferral hygiene, cross-repo impact (axes F–J) |
| Camille | Advisory to Senna | Security blast-radius (BLOCK / NEEDS-MITIGATION / OK) — fires on path-list match only |

Senna DIAGNOSES FAIL/PARTIAL if Akali or Camille return a blocking verdict. The PR cannot merge
red (Rule 15).

**Path contract (synthesis Conflict C3 resolution):**

- **Location** owned by ADR #2: `assessments/qa-reports/<concern>/<YYYY-MM-DD>-<slug>/`
- **Wrapper frontmatter** owned by ADR #2: `date`, `author`, `category: qa-reports`, `concern`,
  `target`, `state`, `owner`, `session` (8 mandatory) + optional `head_sha:` (QA convention per
  QA two-stage ADR §D6f — strongly recommended).
- **Body shape** owned by ADR #3 + QA two-stage ADR: acceptance criteria walked, failure modes,
  cite_kind/cite_evidence table, verdict block.

**PR body markers required (ADR #5 §D7):** `QA-Report:`, `Design-Spec:`, `Accessibility-Check:`,
`Visual-Diff:`, `Plan:`. Enforced by `.github/workflows/pr-lint.yml`.

**Fast-path pattern:** FP4 — four reviewers in parallel (or three on non-security PRs).

**Authority:** ADR #4, ADR #3 §D4, QA two-stage ADR, ADR #2 §3, Rules 16, 18

---

## Stage 7 — Merge

**Owner:** PR author merges; Orianna re-signs `implemented`.
**Gate:** Rule 18 (all required CI checks green + one non-author approving review). Orianna
`in-progress → implemented` gate verifies `architecture_changes` paths were actually modified.
**Artifact:** `plans/implemented/<concern>/...` with `orianna_signature_implemented`.

No `gh pr merge --admin` bypass. No branch-protection bypass. Break-glass admin merges are
human-only (Duong) per CLAUDE.md Rule 18.

**Authority:** CLAUDE.md Rule 18, Orianna gate v2

---

## Stage 8 — Post-deploy

**Owner:** CI smoke tests + auto-rollback script.
**Gate:** Rule 17 — stg smoke + prod smoke required; auto-rollback on prod failure via
`scripts/deploy/rollback.sh`.
**Artifact:** Smoke logs + rollback artifact.

Stg failures can sometimes be deferred to manual triage; prod failures trigger automatic
rollback with no bypass path.

**Authority:** CLAUDE.md Rule 17

---

## Stage 9 — Retro + reviewer audit

**Owner:** Skarner v2 dashboard panel (pending); Duong manual spot-check until panel ships.
**Gate:** None per-PR; load-bearing in aggregate.
**Artifact:** `assessments/retrospectives/<concern>/...` per ADR #2; reviewer-quality panel
data.

Monthly spot-check: 5 PRs reviewed for post-merge bug correlation and reviewer calibration
drift. Reviewer-of-reviewer audit is the only feedback loop that keeps Stage 6 calibrated. New
ideas surfaced during retro go to `ideas/<concern>/` (Stage 0), closing the loop.

**Authority:** ADR #4 §D8, ADR #2 §3 retrospectives row

---

## Speed leverage

Five named fast-path patterns. Each is a parallel-slice opportunity that buys wall-clock time
without sacrificing quality.

### FP1 — UI plan post-approve fan-out

**Trigger:** UI plan moves `proposed → approved` (Orianna gate clears).

**Pattern:** Three agents dispatched in parallel in a single coordinator turn:
1. Lulu (or Neeko on complex) — author `## UX Spec` amendment if not authored at plan time.
2. Caitlyn — author `## QA Plan` amendment if not authored at plan time.
3. Aphelios (or Kayn on complex) — author task breakdown.

**Speedup:** ~3x wall-clock vs serial (15–25 min vs ~45–75 min).

### FP2 — Backend plan post-approve fan-out

**Trigger:** Backend plan with user-observable acceptance criteria moves `proposed → approved`.

**Pattern:** Two agents in parallel:
1. Senna (qa_co_author) — review `## QA Plan` acceptance criteria.
2. Aphelios (or Kayn) — task breakdown.

**Speedup:** ~2x wall-clock vs serial.

### FP3 — Stage-5 parallel observers (mid-build)

**Trigger:** Impl agent reports "interactive surface ready" on a UI plan.

**Pattern:** Two agents in parallel:
1. Akali (smoke mode) — ON-TRACK / DRIFT / BLOCKED on acceptance criteria.
2. Lulu (usability check) — friction / affordance / copy notes.

**Speedup:** ~2x wall-clock; combined ~12 min total.

### FP4 — Stage-6 four-reviewer parallel (security-blast-radius case)

**Trigger:** PR opens AND diff matches Camille security-blast-radius path detection.

**Pattern:** Four agents in parallel:
1. Akali — Rule 16 Playwright + Figma diff.
2. Senna — 5-axis review.
3. Lucian — 5-axis review.
4. Camille — security verdict, advisory to Senna.

**Speedup:** ~4x wall-clock vs serial. Non-security PRs drop Camille → three-reviewer parallel.

### FP5 — Idea promotion fast-track

**Trigger:** An idea in `ideas/<concern>/` is promoted by coordinator to a proposed plan.

**Pattern:** Two concurrent actions:
1. Swain (personal) or Azir (work) — author proposed plan from idea body.
2. Coordinator — delete the original idea file in the same commit.

**Speedup:** Minor (~1.2x); structural win is one-turn promotion with no multi-step ritual.

---

## Quality non-negotiables

The following must not be cut for speed. Each names the rule or ADR defining it.

1. **Rule 12 — xfail test before impl.** Pre-push hook + `tdd-gate.yml` CI. No bypass.
2. **Rule 13 — regression test before bug fix.** Same enforcement.
3. **Rule 14 — pre-commit unit tests.** Local feedback loop. No `--no-verify`.
4. **Rule 16 — Akali QA at PR open for UI/user-flow PRs.** `QA-Waiver:` only for legitimate
   cases (e.g. no running staging environment); never as a speed cut.
5. **Rule 17 — post-deploy smoke + auto-rollback on prod.** Non-skippable for prod.
6. **Rule 18 — no `gh pr merge --admin`; one non-author approve required.** Branch-protection
   structural enforcement.
7. **Rule 19 — Orianna gate v2 for plan promotions.** Hooks block; no workaround.
8. **Rule 22 — `## UX Spec` required for UI plans.** `UX-Waiver:` only for legitimate refactors
   with no visible delta.
9. **`## QA Plan` acceptance criteria authored at plan-authoring time.** The criteria are the
   contract for Stage 5 (Akali smoke) and Stage 6 (Akali full). Skipping reintroduces the
   "built the wrong thing" failure mode.
10. **Reviewer-of-reviewer audit (manual bridge).** Monthly 5-PR Duong spot-check until
    Skarner v2 panel ships. Without it Stage 6 is unfalsifiable.
11. **`_shared/reviewer-discipline.md` primitive in Senna and Lucian agent-defs.** Phantom
    citation, stale-SHA, and lane-bleed anti-patterns re-emerge without it.
12. **Throw-away decision is human-only.** No agent ever discards built work. Escalate to Duong.
13. **Dual non-author approval required (Rule 18).** No self-approve; no admin bypass.
14. **Stage 5 defaults ON for UI plans.** Advisory in v1; cutting it entirely regresses to
    pre-ADR-#3 state.

---

## Cross-references

### Source ADRs (canonical authority for subsections)

| # | Slug | Surface |
|---|------|---------|
| ADR #1 | `plans/proposed/personal/2026-04-25-plan-of-plans-and-parking-lot.md` | Backlog priority (P0–P3), parking lot, `last_reviewed:`, `/backlog` skill |
| ADR #2 | `plans/proposed/personal/2026-04-25-assessments-folder-structure.md` | 8-category taxonomy, `qa-reports/` location + wrapper frontmatter |
| ADR #3 | `plans/proposed/personal/2026-04-25-structured-qa-pipeline.md` | 4-stage QA pipeline, Akali smoke, `qa_plan:` field, `cite_kind`/`cite_evidence` body shape |
| ADR #4 | `plans/proposed/personal/2026-04-25-pr-reviewer-tooling-guidelines.md` | `_shared/reviewer-discipline.md` primitive, 5-axis checklists, Camille dispatch |
| ADR #5 | `plans/proposed/personal/2026-04-25-frontend-uiux-in-process.md` | `## UX Spec` required, Rule 22 hook, Lulu/Neeko routing, a11y floor, PR markers |

### Adjacent plans

- `plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md` — Akali OBSERVES + Senna DIAGNOSES architecture; `head_sha:` field motivation.
- `plans/approved/personal/2026-04-25-pre-dispatch-parallel-slice.md` — parallel-slice doctrine; Karma quick-lane bypass.
- `plans/approved/personal/2026-04-25-architecture-consolidation-v1.md` — W1+W2 architecture consolidation; W3 doc location for `process.md`.
- `plans/in-progress/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md` — canonical-v1 lock manifest target.
- `plans/approved/personal/2026-04-25-unified-process-synthesis.md` — synthesis ADR; this doc is its T2 deliverable.

### CLAUDE.md rules cited

Rules 12, 13, 14, 15, 16, 17, 18, 19, 22.

### Architecture siblings

- `architecture/agent-network-v1/plan-lifecycle.md` — five-phase plan lifecycle (`proposed → approved → in-progress → implemented → archived`).
- `architecture/agent-network-v1/coordinator-boot.md` — coordinator startup + routing-check primitive.
- `architecture/agent-network-v1/routing.md` — agent lane lookup table.
- `architecture/agent-network-v1/taxonomy.md` — plan template + frontmatter fields.
- `architecture/agent-network-v1/README.md` — system index.
