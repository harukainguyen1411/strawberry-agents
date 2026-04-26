# QA Pipeline — Canonical Reference

This document is the single source of truth for the **QA pipeline** in the Strawberry
agent system. Every agent reads this on boot so the full flow is visible without
reconstructing it from scattered rules.

**Source ADR:** `plans/approved/personal/2026-04-25-structured-qa-pipeline.md`

---

## Overview

The QA pipeline has exactly **four stages**, in order:

| Stage | Name | When | Owner | Artifact | Gate enforcer |
|-------|------|------|-------|----------|---------------|
| 1 | QA Plan (planning-phase contract) | Plan authored, before Orianna `proposed → approved` | Plan author + QA co-author | `## QA Plan` section in plan body + `qa_plan` frontmatter field | Orianna gate v2 |
| 2 | Draft-PR Smoke (mid-build drift catch) | After first push to a PR branch, before PR is marked ready-for-review | Akali (UI surface) or Senna (backend surface) | Short smoke report appended to PR draft body as `QA-Draft: <path-or-status>` | Coordinator dispatch + pr-lint advisory warning |
| 3 | Pre-Merge QA (full gate) | Before PR `ready-for-review` → mergeable | Akali OBSERVES + Senna DIAGNOSES on FAIL (per two-stage ADR) | `assessments/qa-reports/<slug>.md` linked via `QA-Report:` in PR body | Rule 16 (enforced by `.github/workflows/pr-lint.yml`) |
| 4 | Post-Deploy Smoke (prod watch) | After deploy to stg and prod | CI smoke job + auto-rollback on prod failure | Smoke job logs + rollback artifact | Rule 17 (enforced by deploy workflow) |

Stages 3 and 4 are carry-forward from existing rules — this document does not modify
their text; it cites them as the authoritative source. Stages 1 and 2 are the new
contracts introduced by the structured-qa-pipeline ADR.

**Pipeline name:** the QA pipeline. All four stages together form it; no subset is
"the QA pipeline." Agents referencing a specific stage should say "Stage N of the QA
pipeline" not just "QA."

---

### Stage 1 — QA Plan (planning-phase contract)

**When.** Before Orianna promotes a plan from `plans/proposed/` to `plans/approved/`.

**Owner.** The plan author, with a QA co-author declared in frontmatter (see
co-authorship matrix below).

**Purpose.** Freeze "what passes QA" before any code is written. A plan approved
without acceptance criteria produces late-discovery failures: the build is done, then
QA reveals the result does not match user intent, then the whole build is thrown away.
Stage 1 closes that failure mode by making the acceptance contract a prerequisite for
approval.

#### Frontmatter contract

Every new plan with UI, user-flow, or backend surface that has user-observable
acceptance criteria MUST declare these fields in YAML frontmatter:

```yaml
qa_plan: required        # one of: required | inline | none
qa_co_author: <agent>    # required if qa_plan != none
```

Allowed `qa_plan` values:

| Value | Meaning | When to use |
|-------|---------|-------------|
| `required` | Plan body MUST contain a `## QA Plan` section with the four required sub-headings. Default for any plan touching user-observable surface. | New routes, forms, API endpoints, state-transition changes, design changes. |
| `inline` | `## QA Plan` section present but surface is so trivial that the four sub-headings collapse to one paragraph. | Typo/copy/single-color changes. Equivalent of today's `QA-Waiver:` but declared at planning time. |
| `none` | Plan has no user-observable QA surface. MUST be paired with a `qa_plan_none_justification` field (minimum 10 characters). Orianna verifies the justification is present. | Pure infra, agent-def edits, scripts, docs plans. |

#### Body section shape

When `qa_plan: required`, the plan body MUST contain a `## QA Plan` section with
these four sub-headings (exact heading text required):

```markdown
## QA Plan

### Acceptance criteria
- <criterion 1 — observable, testable>
- <criterion 2>

### Happy path (user flow)
1. <step 1>
2. <step 2>
3. <expected outcome>

### Failure modes (what could break)
- <failure mode 1: trigger → expected handling>
- <failure mode 2: trigger → expected handling>

### QA artifacts expected
- Stage 2 (draft-PR smoke): <one-line scope>
- Stage 3 (pre-merge): <one-line scope — e.g. "full Playwright + Figma diff against frame Foo/Bar">
- Design reference: <Figma URL or "n/a — backend surface">
```

The `### QA artifacts expected` sub-section names the Figma frame explicitly so Akali
is not guessing which frame to diff against at Stage 3.

#### Co-authorship matrix

| Plan surface | `qa_co_author` | What they review |
|--------------|----------------|------------------|
| UI / user-flow (new route, new form, design change) | `lulu` | Acceptance criteria match design intent; happy path matches Figma flow; failure modes include common UX failures (loading, empty, error, offline) |
| Backend / API (new endpoint, schema change, business logic) | `senna` | Acceptance criteria are testable; failure modes include known security/race/edge classes |
| Mixed UI + backend | `lulu` (primary) + advisory mention of `senna` in `## QA Plan` body | Lulu owns the user-observable contract; Senna owns the API contract |
| Infra / ops / agent-def / docs | n/a — set `qa_plan: none` with justification | n/a |

The author may invoke the co-author agent or write the section themselves and note
"co-author reviewed inline." Orianna verifies the field is present, not that the
co-author was actually dispatched (light-touch enforcement for v1).

#### Orianna gate enforcement

Orianna's `proposed → approved` gate (gate v2) blocks promotion when:

- `qa_plan` field is absent on a plan with user-observable surface.
- `qa_plan: required` is set but the `## QA Plan` section is missing or lacks any of
  the four required sub-headings.
- `qa_plan: none` is set but `qa_plan_none_justification` is missing or trivially
  short (< 10 characters).
- `qa_plan != none` and `qa_co_author` is absent.

**Grandfather clause.** Plans authored before this ADR's cutover (commit SHA of
`plans/approved/personal/2026-04-25-structured-qa-pipeline.md` landing) are
grandfathered:

- `plans/implemented/` — never retroactively gated. Historical record only.
- `plans/in-progress/` — soft warning on `in-progress → implemented` transition;
  transition is not blocked.
- `plans/approved/` — subject to a sweep (plan T3 of the ADR). Until the sweep
  runs, Orianna emits a grandfather warning on `approved → in-progress` but does not
  block.

The cutover SHA is recorded in `scripts/hooks/pre-commit-zz-plan-structure.sh` as a
named constant (added by implementation task T6b of the structured-qa-pipeline ADR).

**Cross-reference.** `architecture/agent-network-v1/plan-frontmatter.md` documents the
`qa_plan` and `qa_co_author` fields in the field reference section (added by T8).

---

### Stage 2 — Draft-PR Smoke (mid-build drift catch)

**When.** After first push to a PR branch implementing a `qa_plan: required` plan,
before the PR is marked ready-for-review.

**Owner.** Akali (UI surface) in `smoke` mode, dispatched by the coordinator.

**Purpose.** Catch scope drift early — the developer has built the route but it does
not match acceptance criterion 2; catching this at draft saves rebuild cost. Stage 2
does NOT catch polish, edge cases, or full Figma fidelity — those wait for Stage 3.

#### Akali smoke mode

Akali in `smoke` mode:

- Runs a 30-second to 2-minute happy-path screenshot pass — no video, no full
  click-through, no Figma pixel diff.
- Checks ONLY the acceptance criteria from the linked plan's `### Acceptance criteria`
  sub-section. Akali reads the plan path from the PR body's `Plan: <path>` line; if
  absent, she requests it.
- Output: a short report appended to the PR draft body as a fenced `QA-Draft:` block
  with verdict `ON-TRACK | DRIFT | BLOCKED` and a one-line summary per acceptance
  criterion.
- Wall-clock cap: ≤ 2 minutes. Token cap: ≤ 30k input tokens per smoke run.

See `.claude/agents/akali.md` `## Modes` section for the full `smoke` vs `full`
invocation contract (added by T9 of the structured-qa-pipeline ADR).

#### Dispatch trigger

A GitHub Actions workflow (`qa-draft-reminder.yml`, added by T11b) posts a comment on
draft PRs opened against branches implementing a `qa_plan: required` plan. The comment
reminds the coordinator to dispatch Akali in smoke mode. Auto-dispatch from Actions to
a Claude session is not available; coordinator-driven dispatch is the only mechanism.

#### Decision tree on DRIFT or BLOCKED

| Verdict | Meaning | Default action |
|---------|---------|----------------|
| `ON-TRACK` | Build matches acceptance criteria so far | Continue to Stage 3 when ready |
| `DRIFT` (built ≠ plan, plan is right) | Implementation diverged from acceptance criteria | Push back to implementer; do not amend plan; re-dispatch Akali smoke after next push |
| `DRIFT` (built ≠ plan, plan is wrong) | Acceptance criteria turn out to be impractical | Pause build; coordinator dispatches Karma to amend `## QA Plan`; Orianna re-signs in-progress; resume |
| `BLOCKED` (env down, build broken) | Akali could not run | Escalate to coordinator; do not bypass; do not promote PR to ready-for-review without Stage 3 |

A throw-away decision is always human-only (see cross-stage failure tree below).

#### Enforcement

Stage 2 is **advisory, not gating** in v1. `pr-lint` emits a WARNING (not failure)
when a plan-linked draft PR has no `QA-Draft:` block after 24 hours. The warning does
not fail the workflow. Coordinator-driven dispatch is the primary enforcement
mechanism.

---

### Stage 3 — Pre-Merge QA (full gate)

**When.** Before a PR is marked ready-for-review (merging is blocked until Stage 3
passes).

**Owner.** Akali OBSERVES; Senna DIAGNOSES on FAIL (per the two-stage architecture
described in `plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md`).

**Artifact.** A report at `assessments/qa-reports/<slug>.md`, linked in the PR body
via a `QA-Report: <path-or-url>` line. A `QA-Waiver: <reason>` line is accepted in
lieu of a report when Akali cannot run (e.g. no running staging environment).

**Enforcement.** Rule 16 (`CLAUDE.md` lines 92–101), enforced by
`.github/workflows/pr-lint.yml`. This document does not modify Rule 16 text.

**Scope.** Full Playwright run + Figma pixel diff against the frame named in the plan's
`### QA artifacts expected` sub-section. The two-stage Swain ADR
(`plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md`) governs the
OBSERVE/DIAGNOSE seam — this document cites that ADR as the source of truth; it does
not redefine the seam.

**Lulu/Akali handoff.** Lulu authors `### Acceptance criteria` + `### Happy path` at
Stage 1 and provides the Figma reference. Akali at Stage 3 diffs against the same
Figma frame Lulu cited. Lulu does not run Stage 3 herself; she may review the Stage 3
report for design-intent fidelity post-Akali (advisory, not gating).

---

### Stage 4 — Post-Deploy Smoke (prod watch)

**When.** After deploy to stg and prod.

**Owner.** CI smoke job. Auto-rollback on prod failure.

**Artifact.** Smoke job logs. Rollback artifact when prod smoke fails.

**Enforcement.** Rule 17 (`CLAUDE.md` lines 103–106), enforced by the deployment
workflow. Prod smoke failures trigger auto-revert via `scripts/deploy/rollback.sh`.
This document does not modify Rule 17 text.

**Reference.** See `plans/in-progress/2026-04-17-deployment-pipeline.md` for the
deployment pipeline mechanics.

---

## Failure decision trees

### Per-stage failure handling

| Failure | Stage caught | Decision authority | Default action |
|---------|--------------|--------------------|----------------|
| `qa_plan` field absent on UI/user-flow plan | Stage 1 (Orianna gate) | Orianna | REJECT promotion; author adds field and re-submits |
| `## QA Plan` section missing or incomplete | Stage 1 (Orianna gate) | Orianna | REJECT promotion; author adds section; re-submits |
| `qa_plan: none` without justification | Stage 1 (Orianna gate) | Orianna | REJECT; author adds `qa_plan_none_justification` |
| Built ≠ plan, plan is right | Stage 2 | Coordinator | Push back to implementer; do not amend plan |
| Built ≠ plan, plan is wrong | Stage 2 | Coordinator → Karma | Pause build; Karma amends `## QA Plan`; Orianna re-signs; resume |
| Akali smoke BLOCKED (env down) | Stage 2 | Coordinator | Escalate; do not bypass; do not promote to ready-for-review without Stage 3 |
| Pre-merge FAIL — `cite_kind: verified` | Stage 3 | Coordinator → fix-planner | Direct fix; no Senna round-trip |
| Pre-merge FAIL — `cite_kind: inferred` | Stage 3 | Coordinator → Senna | Senna grounds the citation; then fix-planner |
| Pre-merge FAIL irreparable / over-budget | Stage 3 | **Duong only** | Throw-away decision is human-only; never automated |
| Post-deploy stg smoke FAIL | Stage 4 | Coordinator | Block prod deploy; investigate |
| Post-deploy prod smoke FAIL | Stage 4 | Auto | Auto-rollback per Rule 17; coordinator post-mortems |

### Throw-away is a human decision

No agent decides to discard a built feature without Duong's explicit call. The table
above is exhaustive on automated/coordinator-handled cases; the residual class
escalates to Duong. When Duong calls throw-away, the in-progress plan moves to
`plans/archived/<concern>/` with a `## Throwaway record` section appended (Orianna
handles the move).

### DRIFT → plan amendment path (Stage 2)

When Stage 2 reveals the acceptance criteria are impractical:

1. Coordinator pauses build (notifies implementer).
2. Coordinator dispatches Karma to amend the `## QA Plan` section of the in-progress
   plan.
3. Orianna re-signs the amended in-progress plan (re-sign-in-progress operation; see
   OQ-1 in the source ADR).
4. Coordinator resumes build dispatch with the updated acceptance criteria.
5. Akali smoke re-runs after next push; new verdict determines next step.

---

## Backwards compatibility

Plans authored before the cutover SHA (see §Stage 1 grandfather clause above) are
subject to the following treatment:

| State | Treatment |
|-------|-----------|
| `plans/implemented/` | Grandfathered permanently. Do not retroactively add §QA Plan. |
| `plans/in-progress/` | Soft warning only on `in-progress → implemented` transition. Not blocked. |
| `plans/approved/` | Subject to the T3 sweep (structured-qa-pipeline ADR). Until swept: grandfather warning on `approved → in-progress`, transition not blocked. |

---

## Cross-references

| Resource | What it provides |
|----------|-----------------|
| `CLAUDE.md` Rule 16 (lines 92–101) | Stage 3 gate — pre-merge Akali requirement, `QA-Report:` PR body line, `QA-Waiver:` escape hatch |
| `CLAUDE.md` Rule 17 (lines 103–106) | Stage 4 gate — post-deploy smoke + auto-rollback |
| `CLAUDE.md` Rule 19 (lines 117–118) | Orianna gate; extended by Stage 1 `qa_plan` check at `proposed → approved` |
| `architecture/agent-network-v1/plan-frontmatter.md` | Field reference for `qa_plan` and `qa_co_author` (§qa_plan section added by T8) |
| `architecture/agent-network-v1/plan-lifecycle.md` | Plan phase → stage mapping: Stage 1 at `proposed → approved`; Stages 2–3 during `in-progress`; Stage 4 post-`implemented` |
| `plans/approved/personal/2026-04-25-structured-qa-pipeline.md` | Source ADR for this document; authoritative decisions D1–D9 |
| `plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md` | Swain ADR — Akali OBSERVES + Senna DIAGNOSES seam at Stage 3 |
| `plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md` | Karma v1 — reporting-discipline hooks layered under Stage 3 |
| `plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md` | Orianna gate v2 ADR — the gate this pipeline extends with `qa_plan` check |
| `.claude/agents/akali.md` | QA execution agent; `## Modes` section documents `smoke` vs `full` (added by T9) |
| `.claude/agents/lulu.md` | Design advisor; `## QA co-author` responsibility section (added by T10) |
| `.claude/agents/senna.md` | PR review + backend QA co-author; `## QA co-author` section (added by T10) |
| `assessments/qa-reports/` | Stage 3 report landing directory |
| `.github/workflows/qa-draft-reminder.yml` | Stage 2 dispatch reminder workflow (added by T11b) |
| `scripts/ci/pr-lint-qa-draft.sh` | Stage 2 advisory pr-lint check (added by T12b) |
