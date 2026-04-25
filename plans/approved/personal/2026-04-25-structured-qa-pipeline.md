---
status: approved
concern: personal
owner: azir
created: 2026-04-25
complexity: complex
tests_required: true
orianna_gate_version: 2
tags: [architecture, qa, pipeline, lifecycle, akali, lulu, senna, rule-16, rule-17, gate-v2, plan-frontmatter]
related:
  - CLAUDE.md
  - .claude/agents/akali.md
  - .claude/agents/lulu.md
  - .claude/agents/senna.md
  - .claude/agents/orianna.md
  - architecture/plan-frontmatter.md
  - architecture/plan-lifecycle.md
  - plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md
  - plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md
architecture_changes:
  - architecture/agent-network-v1/qa-pipeline.md
  - architecture/plan-frontmatter.md
---

# Structured QA pipeline — QA-as-plan-artifact, QA-during-build, QA-as-merge-gate, QA-as-prod-watch

## Context

Duong's directive (verbatim):

> "I want a more structured and robust QA pipeline, currently we don't even have it documented and will easily be overlooked. QA is such an important step and is the make or break point of a plan. we currently don't have a QA plan and it often happens at the very end of the cycle, which sometimes is too late because we already built everything, but then the final result after QA is not usable, then the whole things thrown away."

The system today has fragments of a QA pipeline but no canonical name for the pipeline, no contract that obligates a plan to declare QA before approval, and no documented surface that ties the fragments together. Concretely:

- **Rule 16** (CLAUDE.md) is the pre-merge Akali gate — Playwright + Figma diff before PR open. This is *late*: the implementation already exists.
- **Rule 17** is the post-deploy smoke + auto-rollback. Also *late*: build is done; the cost is rollback churn.
- **Karma v1** (`plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md`) adds reporting-discipline hooks for Akali. Tactical patch on Rule 16; does not extend left-of-build.
- **Two-stage Swain ADR** (`plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md`) splits OBSERVE (Akali) from DIAGNOSE (Senna) on FAIL with citation-tagging. Excellent pre-merge structural fix; explicitly does not address pre-build or mid-build.
- **`assessments/qa-reports/`** already exists as the artifact landing pattern.
- **Lulu** is the design advisor (Opus) but is not wired into the QA contract — there is no documented coordination between Lulu's design intent and Akali's visual diff.

The critical hole is **upstream of build**. A plan is approved, built, then QA at the end discovers the result does not match user intent / acceptance criteria — because no one wrote acceptance criteria into the plan in the first place. Late discovery means rebuild or throw-away. The fix is **shift QA left into the planning phase** so that "what passes QA" is contractually frozen before any code is written, and **shift QA mid-build** so scope drift is caught on draft PR rather than at pre-merge.

This ADR canonicalizes a four-stage QA pipeline, makes Stage 1 (planning-phase QA contract) a hard gate at plan approval via Orianna gate v2 frontmatter, and writes the pipeline into a single canonical doc (`architecture/agent-network-v1/qa-pipeline.md`) so the full flow is visible to every agent on boot.

### What this ADR does NOT do

- Does **not** rewrite Akali's agent def from scratch — that is a separate Lux ADR if needed; explicitly defer.
- Does **not** define PR reviewer guidelines — parallel Azir ADR covers that.
- Does **not** implement any of the changes — Kayn handles task breakdown after promotion.
- Does **not** supersede the two-stage Swain ADR or Karma v1 — both ship under their own lifecycle. This ADR layers a planning-phase contract and mid-build draft-QA stage *above* them, and writes the canonical pipeline doc that ties all four stages together.

## Decision

### D1 — The four canonical QA stages

The pipeline is named **the QA pipeline** and has exactly four stages, in order:

| Stage | Name | When | Owner | Artifact | Gate enforcer |
|-------|------|------|-------|----------|---------------|
| 1 | **QA Plan (planning-phase contract)** | Plan authored, before Orianna `proposed → approved` | Plan author + design/QA co-author | `## QA Plan` section in the plan body, `qa_plan` frontmatter field | Orianna gate v2 (D2) |
| 2 | **Draft-PR Smoke (mid-build drift catch)** | After first push to a PR branch, before PR is marked ready-for-review | Akali (UI surface) or Senna (backend surface) | Lightweight smoke report appended to PR draft body as `QA-Draft: <path-or-status>` | Coordinator dispatch policy + PR-lint advisory check (D4) |
| 3 | **Pre-Merge QA (full gate)** | Before PR `ready-for-review` → mergeable | Akali OBSERVES + Senna DIAGNOSES on FAIL/PARTIAL inferred (per two-stage ADR) | `assessments/qa-reports/<slug>.md` linked via `QA-Report:` | Rule 16 (already enforced by `.github/workflows/pr-lint.yml`) |
| 4 | **Post-Deploy Smoke (prod watch)** | After deploy to stg and prod | CI smoke job + auto-rollback on prod failure | Smoke job logs + rollback artifact | Rule 17 (already enforced by deploy workflow) |

Stages 3 and 4 already exist and are governed by their own rules — this ADR does **not** modify their text. Stages 1 and 2 are the new contracts. The canonical pipeline doc (D6) describes all four in one place so no agent has to reconstruct the flow from scattered rules.

**Rationale for four and not more.** A planning-phase contract closes the "we built the wrong thing" failure mode. A draft-PR smoke closes the "we built it wrong and only noticed at merge" failure mode. Pre-merge and post-deploy already exist and work. Adding more stages (e.g. pre-implementation-task-breakdown-QA, post-merge-pre-deploy-QA) is over-instrumentation — the marginal failure modes those would catch are dominated by Stages 1–4 if Stages 1–4 are honored.

### D2 — Stage 1: QA Plan as a plan-frontmatter contract

Every new plan with UI or user-flow surface, AND every new plan with backend surface that has user-observable acceptance criteria, MUST declare a `qa_plan` frontmatter field and a `## QA Plan` body section. The Orianna gate v2 `proposed → approved` transition blocks promotion when the field is missing or the section is empty.

**Frontmatter field.**

```yaml
qa_plan: required        # one of: required | inline | none
qa_co_author: <agent>    # required if qa_plan != none — see D5
```

Allowed values:

| Value | Meaning | When |
|-------|---------|------|
| `required` | Plan body MUST contain a `## QA Plan` section with the four sub-headings below. Default when the field is absent on a UI/user-flow plan. | Default for any plan touching user-observable surface. |
| `inline` | The plan body section is present but the surface is so trivial that the four sub-headings collapse to one paragraph. Acceptable for typo/copy/single-color plans. | Trivial UI surface; equivalent of today's `QA-Waiver:` but declared at planning time. |
| `none` | Plan has no user-observable QA surface (pure infra, agent-def edits, scripts, docs). MUST be paired with a one-line justification immediately after the field. Orianna verifies the justification is present. | Infra/ops/docs/agent-def plans. |

**Body section shape.** When `qa_plan: required`, the `## QA Plan` section MUST contain four sub-sections with these exact headings:

```markdown
## QA Plan

### Acceptance criteria
- <criterion 1 — observable, testable>
- <criterion 2>
- ...

### Happy path (user flow)
1. <step 1>
2. <step 2>
3. <expected outcome>

### Failure modes (what could break)
- <failure mode 1: trigger → expected handling>
- <failure mode 2: trigger → expected handling>
- ...

### QA artifacts expected
- Stage 2 (draft-PR smoke): <one-line scope — e.g. "Akali screenshot on the new route, no full Playwright run">
- Stage 3 (pre-merge): <one-line scope — e.g. "full Playwright + Figma diff against frame `Foo/Bar`">
- Design reference: <Figma URL or "n/a — backend surface">
```

**Co-authorship.** UI plans have `qa_co_author: lulu` (design intent + acceptance criteria) AND the plan author is responsible for the QA Plan being present at promotion time. Backend plans have `qa_co_author: senna` (review the failure-mode list for completeness). The author may invoke the co-author or write the section themselves and cite "co-author reviewed inline" — Orianna verifies the field is present, not that the co-author was actually dispatched (light-touch enforcement).

**Why frontmatter + body, not just body.** Frontmatter is machine-checkable — Orianna already parses YAML. A `qa_plan` field gives Orianna a first-class signal to gate on without parsing the body for an `## QA Plan` heading (though she will also verify the heading exists when `qa_plan != none`, the same way she verifies `## Architecture impact` per existing gate v2 conventions). Frontmatter also makes it grep-able for the audit pass in D7.

### D3 — Stage 2: Draft-PR smoke (mid-build drift catch)

**Trigger.** When a PR is opened in draft state on a branch implementing a plan with `qa_plan: required` (UI surface) — first push to the PR branch fires a coordinator-side reminder to dispatch Akali in **smoke mode**.

**Akali smoke mode.** A new operating mode for Akali (added to her agent-def in the implementation plan, not here):

- Run a 30-second to 2-minute happy-path screenshot run — no video, no full click-through, no Figma pixel diff.
- Check ONLY the acceptance criteria from the plan's §QA Plan §Acceptance criteria sub-section (Akali reads the linked plan path from the PR body's `Plan: <path>` line — a line every PR body already SHOULD carry; if absent, Akali requests it).
- Output: a short report appended to the PR draft body as a fenced `QA-Draft:` block with verdict `ON-TRACK | DRIFT | BLOCKED` and a one-line summary per acceptance criterion.

**What this catches.** Scope drift early — the developer (agent or human) has built the new route but it does not match acceptance criterion 2; catching this at draft saves rebuild cost. **What this does NOT catch.** Polish, edge cases, full Figma fidelity — those wait for Stage 3.

**Decision tree on DRIFT or BLOCKED.** The coordinator receives the draft-QA report and decides:

- **DRIFT** (built ≠ plan, but plan is still right) → push back to implementer with the failing criteria; do not change the plan. Re-dispatch Akali smoke after the next push.
- **DRIFT and plan is wrong** (acceptance criteria turn out to be impractical) → pause build; coordinator dispatches Karma to amend the plan's §QA Plan; Orianna re-promotes the amended plan via gate v2 (an in-progress plan that gains a new acceptance criterion is a §D2.3-ish path — Orianna re-signs in-progress to in-progress with a new body hash, see OQ-1).
- **BLOCKED** (Akali could not run — staging down, build broken) → escalate to coordinator; not Akali's call to bypass.

**Enforcement.** Stage 2 is **advisory, not gating** in v1 — pr-lint warns (does not fail) when a plan-linked draft PR has no `QA-Draft:` block after 24h. v2 (a follow-up plan) may promote to a hard gate once the workflow is well-established. Rationale: a hard gate on draft-PR adds friction during active iteration; the coordinator-driven dispatch reminder is the right starting force.

### D4 — Stage 3 and Stage 4 carry forward unchanged

Rule 16 (Stage 3) and Rule 17 (Stage 4) are not modified by this ADR. The two-stage Swain ADR (`2026-04-25-qa-two-stage-architecture.md`) carries the structural amendment for Rule 16 (Akali OBSERVES + Senna DIAGNOSES on FAIL inferred). This ADR's Stage 3 description in the canonical pipeline doc cites that ADR as the source of truth for the OBSERVE/DIAGNOSE seam — it does not redefine it.

**Order of operations across the two ADRs:** ship the two-stage Swain ADR first (it is a strict subset of the pre-merge stage), then layer this ADR's Stages 1 and 2 on top. If the two-stage ADR is rejected by Duong, this ADR's Stage 3 description in the pipeline doc reverts to the current Rule 16 text — Stages 1, 2, 4 are unaffected.

### D5 — Co-authorship matrix

Who co-authors the §QA Plan depends on the plan's surface:

| Plan surface | `qa_co_author` | What they review |
|--------------|----------------|------------------|
| UI / user-flow (new route, new form, design change) | `lulu` | Acceptance criteria match design intent; happy path matches Figma flow; failure modes include common UX failures (loading, empty, error, offline) |
| Backend / API (new endpoint, schema change, business logic) | `senna` | Acceptance criteria are testable; failure modes include known security/race/edge classes Senna catches in PR review |
| Mixed UI + backend | `lulu` (primary) + `senna` (advisory mention in §QA Plan body) | Both — Lulu owns the user-observable contract, Senna owns the API contract |
| Infra / ops / agent-def / docs | n/a — set `qa_plan: none` with justification | n/a |

**Lulu/Akali handoff at Stage 3.** Lulu authors the §QA Plan §Acceptance criteria + §Happy path and provides the Figma reference. Akali, at Stage 3, runs Playwright against the same Figma frame Lulu cited and pixel-diffs. The §QA Plan §QA artifacts expected sub-section names the Figma frame explicitly so Akali is not guessing which frame to diff against. This closes a gap today where Akali has to infer the Figma reference from PR context.

**Lulu does not run Stage 2 or Stage 3 herself.** She produces the spec at Stage 1 and reviews the Stage 3 report for design-intent fidelity post-Akali (advisory, not gating). Stage 2 and Stage 3 execution stays with Akali (and Senna for diagnosis on FAIL).

### D6 — Canonical pipeline doc

A new doc lands at **`architecture/agent-network-v1/qa-pipeline.md`** (W3 location — sibling to `agent-network-v1/coordinator-boot.md`, `agent-network-v1/plan-lifecycle.md`, etc., which is where canonical agent-network mechanics already live).

Doc structure (one screenful per stage):

1. **Overview** — the four stages, the table from D1, the pipeline name.
2. **Stage 1 — QA Plan** — frontmatter contract, body section shape, co-authorship matrix, Orianna gate enforcement.
3. **Stage 2 — Draft-PR smoke** — Akali smoke mode, dispatch trigger, decision tree on DRIFT/BLOCKED, advisory pr-lint warning.
4. **Stage 3 — Pre-merge QA** — pointer to Rule 16 + the two-stage Swain ADR (no duplication; just cite).
5. **Stage 4 — Post-deploy smoke** — pointer to Rule 17 + the deployment pipeline plan (no duplication).
6. **Failure decision trees** — one per stage; what happens when QA fails, who decides re-plan vs fix vs throw-away.
7. **Cross-references** — Rules 16, 17, Orianna gate v2 plan, two-stage ADR, Karma v1 hook plan, plan-frontmatter doc.

**Why W3 location and not `architecture/qa-pipeline.md` at the root.** The agent-network-v1 subtree is the documented home for agent-coordination mechanics; QA pipeline is one of those mechanics. Sibling docs there (coordinator-boot, plan-lifecycle, routing) set the precedent. Root-level `architecture/` holds system-overview docs (apps, infrastructure, mcp-servers); QA pipeline is not at that level of cross-cutting.

### D7 — Backwards compat: grandfather + sweep

Plans authored before this ADR lands fall into three classes:

- **Already-implemented plans (`plans/implemented/`)** — grandfather. Do not retroactively add §QA Plan. They are historical record.
- **In-progress plans (`plans/in-progress/`)** — grandfather with a soft note. Orianna will not block the `in-progress → implemented` transition for a missing `qa_plan` frontmatter on a plan that was approved before this ADR's promotion date. The §Test results section at implementation time captures whatever ad-hoc QA was done.
- **Approved-but-not-started plans (`plans/approved/`)** — sweep. A follow-up Karma task (out of scope for this ADR; tracked as T3) audits the approved-personal subtree, identifies plans with UI or user-flow surface, and either (a) adds a §QA Plan section + frontmatter via an Orianna re-sign-at-approved cycle, or (b) tags the plan as grandfathered with a one-line justification. Orianna's `approved → in-progress` gate enforces `qa_plan` presence going forward.

**Cutover date** is the commit SHA of this ADR's promotion to `plans/approved/personal/`. Plans created on or after that date MUST have `qa_plan` declared. Orianna's `proposed → approved` gate enforces this for plans with `orianna_gate_version: 2` (the field is already mandatory on new plans per `architecture/plan-frontmatter.md`).

### D8 — Akali mid-build dispatch entry point

For Stage 2 to work, Akali must be reachable mid-build. Today she is invoked at Stage 3 by the PR author. Mid-build dispatch needs:

- **Trigger.** A coordinator dispatch when a PR draft on a `qa_plan: required` plan is first pushed. The dispatch description includes `mode=smoke`, the plan path, and the PR number. Implementation: a GitHub Actions workflow on `pull_request` event with `types: [opened, synchronize]` filtered to draft PRs writes a comment "QA-Draft pending — coordinator should dispatch Akali smoke mode"; Evelynn or Sona reads this and dispatches. (Auto-dispatch from Actions to a Claude session is not available today; coordinator-driven is the only mechanism.)
- **Akali agent-def amendment.** Akali's def gains a `## Modes` section with `smoke` and `full` documented. The smoke mode short-circuits the §Responsibilities §1 Playwright run to a single screenshot per acceptance criterion. This is a small agent-def edit handled in the implementation plan — out of scope here.
- **Karma-quick-plans without a §QA Plan.** Karma quick-plans for trivial work today don't have a §QA Plan (and shouldn't — they declare `qa_plan: none` or `qa_plan: inline`). Stage 2 does not fire on these. The coordinator dispatch reminder only fires when `qa_plan: required` is in the plan frontmatter — pr-lint reads the linked plan path's frontmatter and gates the reminder accordingly. No extra noise on Karma quick-plans.

### D9 — QA-fail decision tree (cross-stage)

| Failure | Stage caught | Decision authority | Default action |
|---------|--------------|--------------------|----------------|
| Acceptance criterion missing from §QA Plan | Stage 1 (Orianna gate) | Orianna | REJECT promotion; author adds the criterion and re-submits |
| Built ≠ plan, plan is right | Stage 2 | Coordinator | Push back to implementer; do not amend plan |
| Built ≠ plan, plan is wrong | Stage 2 | Coordinator → Karma | Pause build; amend plan; Orianna re-signs; resume |
| Akali smoke BLOCKED (env down) | Stage 2 | Coordinator | Escalate; do not bypass; do not promote PR to ready-for-review without Stage 3 |
| Pre-merge FAIL with `cite_kind: verified` | Stage 3 | Coordinator → fix-planner | Direct fix; no Senna round-trip |
| Pre-merge FAIL with `cite_kind: inferred` | Stage 3 | Coordinator → Senna | Senna grounds the citation; then fix-planner |
| Pre-merge FAIL irreparable / over-budget | Stage 3 | Duong | Throw-away decision is human-only — never automated |
| Post-deploy stg smoke FAIL | Stage 4 | Coordinator | Block prod deploy; investigate |
| Post-deploy prod smoke FAIL | Stage 4 | Auto | Auto-rollback per Rule 17; coordinator post-mortems |

**Throw-away is a human decision.** No agent decides to discard a built feature without Duong's explicit call. The decision tree above is exhaustive on automated/coordinator-handled cases; the residual class is escalated.

## Tasks

This plan is architectural. Tasks are coordination + handoff, not self-implementation.

### T1 — Promote this ADR via Orianna

- kind: ops
- estimate_minutes: 10
- files: `plans/proposed/personal/2026-04-25-structured-qa-pipeline.md` → `plans/approved/personal/`
- detail: After Duong sign-off, Evelynn dispatches Orianna with this plan path. Orianna fact-checks (frontmatter completeness, body section presence, references valid) and on APPROVE she git-mvs to `plans/approved/personal/`, signs `orianna_signature_approved`, commits with `Promoted-By: Orianna` trailer, pushes.
- DoD: Plan in `plans/approved/personal/` with valid `orianna_signature_approved` field.

### T2 — Dispatch Kayn for implementation breakdown

- kind: ops
- estimate_minutes: 20
- files: (no commits — Evelynn-side dispatch)
- detail: Once approved, Evelynn dispatches Kayn (in worktree per Rule 20) to break the implementation into ordered tasks. Implementation surface: (a) Orianna gate v2 amendment to require `qa_plan` frontmatter + `## QA Plan` section verification at `proposed → approved`; (b) `architecture/plan-frontmatter.md` update documenting the new field; (c) `architecture/agent-network-v1/qa-pipeline.md` new doc per D6; (d) Akali agent-def amendment for `mode=smoke` per D8; (e) Lulu and Senna agent-def amendments for `## QA co-author` responsibility per D5; (f) GitHub Actions workflow `qa-draft-reminder.yml` per D8 trigger; (g) pr-lint extension for advisory `QA-Draft:` warning per D3; (h) sweep script for approved-personal plans per D7. Kayn returns ordered task list inline (no `-tasks.md` sibling per Rule 20). Evelynn assigns implementers (Kayn does NOT — that is Evelynn's call per architect role rules).
- DoD: Inline task breakdown returned by Kayn; Evelynn has assigned implementers per task.

### T3 — Sweep approved-personal plans for §QA Plan

- kind: ops
- estimate_minutes: 60 (gated on T2 completion)
- files: per-plan edits under `plans/approved/personal/` + `plans/in-progress/personal/` (advisory tag for in-progress)
- detail: Karma audits each approved-personal plan with UI / user-flow surface; for each: either add a `## QA Plan` section + `qa_plan: required` frontmatter (then dispatch Orianna for re-sign-at-approved per D7), or set `qa_plan: none` with justification. In-progress plans receive only a soft annotation; not retroactively gated.
- DoD: 100% of approved-personal plans have `qa_plan` declared; in-progress plans annotated.

## Test plan

Implementation-level tests (xfail per Rule 12) are the responsibility of the downstream implementation tasks (T2 breakdown by Kayn). For this ADR-level plan, the §Test plan describes acceptance criteria for the ADR itself:

- **Test 1 (Orianna gate enforcement).** Create a synthetic plan in `plans/proposed/personal/` without a `qa_plan` frontmatter field, dispatch Orianna for `proposed → approved`. Expected: REJECT with error message naming the missing field. Pass: Orianna outputs the documented error string.
- **Test 2 (Body section verification).** Create a synthetic plan with `qa_plan: required` but no `## QA Plan` body section, dispatch Orianna. Expected: REJECT with message naming the missing heading. Pass: Orianna outputs the documented error string.
- **Test 3 (Grandfather behavior).** Locate a `plans/approved/personal/` plan from before this ADR's cutover date with no `qa_plan` field, dispatch Orianna for `approved → in-progress`. Expected: PASS with grandfather warning. Pass: Orianna outputs the warning, transition succeeds.
- **Test 4 (Pipeline doc presence).** `test -f architecture/agent-network-v1/qa-pipeline.md` returns 0. Doc contains all four stage headings.
- **Test 5 (Plan-frontmatter doc updated).** `architecture/plan-frontmatter.md` contains a `### qa_plan` section with the three allowed values documented.
- **Test 6 (Stage 2 reminder workflow).** Open a synthetic draft PR on a branch implementing a `qa_plan: required` plan; the GitHub Actions `qa-draft-reminder.yml` posts the expected comment within 60s.
- **Test 7 (pr-lint advisory).** PR body without `QA-Draft:` block on a `qa_plan: required` plan after 24h triggers pr-lint warning (not failure).

These tests live in the implementation plans authored from T2 — they are listed here so Kayn's breakdown has a target shape.

## Architecture impact

This plan modifies two architecture docs: a new file `architecture/agent-network-v1/qa-pipeline.md` (the canonical pipeline doc per D6), and an update to `architecture/plan-frontmatter.md` (adding the `qa_plan` and `qa_co_author` field reference per D2). Both changes are listed in `architecture_changes` frontmatter and will be touched by the implementation plan(s) downstream of T2 — Orianna's `in-progress → implemented` gate verifies the listed paths were actually modified per existing gate v2 conventions.

## Open Questions

- **OQ-1 (Re-sign on plan amendment).** When Stage 2 catches "plan is wrong" and the coordinator dispatches Karma to amend the §QA Plan of an in-progress plan, what is the Orianna ritual? Options: (a) Orianna re-signs `in-progress` with a new body hash (cheap; no rollback); (b) plan reverts to `approved`, gets re-signed `approved → in-progress` (clean lifecycle but heavy). **Recommend:** (a) — extend Orianna gate v2 with a `re-sign-in-progress` operation, or treat the body-hash mismatch on existing `orianna_signature_in_progress` as a soft warning when the plan body changes only within `## QA Plan`. Defer to a follow-up ADR; for v1 of this pipeline, route all amendments through (b) to stay inside existing gate semantics.
- **OQ-2 (`qa_plan: required` on backend plans).** Backend plans with user-observable acceptance criteria (e.g. new API endpoint exposed to a UI client) — should they default to `qa_plan: required`? **Recommend:** YES if the API change is observable in any user flow within 30 days; NO if it is internal-only or feature-flagged off. Coordinator judgement; Orianna does not arbitrate this.
- **OQ-3 (Stage 2 advisory → gating timeline).** Today D3 specifies pr-lint advisory only for Stage 2. When does it become a hard gate? **Recommend:** after 4 weeks of operation with <10% false-positive rate (PRs flagged where Stage 2 was not actually warranted), promote to hard gate via a follow-up plan.
- **OQ-4 (Lulu dispatch in Stage 1).** Should Stage 1 §QA Plan §Acceptance criteria mandate that Lulu was actually dispatched (verifiable via `agents/lulu/last-session/` or coordinator handoff log), or just that `qa_co_author: lulu` is declared? **Recommend:** declared-only for v1 (light-touch); mandatory dispatch for v2 if quality drifts.
- **OQ-5 (Cross-concern).** This plan is `[concern: personal]`. Does it apply to work-concern plans? **Recommend:** YES — the pipeline doc and the Orianna gate amendment are concern-agnostic; the qa_co_author for work-concern UI plans defaults to `lulu` if Lulu is enabled on work, else `senna` for backend-only work plans. Document in the pipeline doc.
- **OQ-6 (Akali smoke-mode cost).** What is the wall-clock and token cost target for Stage 2 smoke mode? **Recommend:** ≤ 2 minutes wall-clock and ≤ 30k input tokens per smoke run. Akali smoke-mode mandate caps these explicitly in the agent-def amendment.
- **OQ-7 (Throw-away signal in plan history).** When Duong calls throw-away on a Stage 3 FAIL, what artifact records it? **Recommend:** the in-progress plan moves to `plans/archived/<concern>/` with a `## Throwaway record` section appended naming the QA report path and the throw-away rationale; Orianna handles the move. No new lifecycle stage; existing `archived/` covers this.

## References

- `CLAUDE.md` lines 92-101 (Rule 16 — pre-merge QA, current text, unchanged by this ADR)
- `CLAUDE.md` lines 103-106 (Rule 17 — post-deploy smoke, unchanged by this ADR)
- `CLAUDE.md` lines 117-118 (Rule 19 — Orianna gate; this ADR adds the `qa_plan` check at `proposed → approved`)
- `architecture/plan-frontmatter.md` (existing field reference; this ADR adds `qa_plan` and `qa_co_author`)
- `architecture/plan-lifecycle.md` (existing lifecycle doc; QA stages map onto plan stages — Stage 1 at `proposed → approved`, Stages 2-3 during `in-progress`, Stage 4 post-`implemented`)
- `plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md` (Swain — Akali OBSERVES + Senna DIAGNOSES; layered under Stage 3 of this pipeline)
- `plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md` (Karma v1 — reporting-discipline hooks; layered under Stage 3 of this pipeline)
- `plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md` (Orianna gate v2 ADR — the gate this plan extends with the `qa_plan` check)
- `.claude/agents/akali.md` (current QA agent def; D8 amendment described inline)
- `.claude/agents/lulu.md` (design advisor; D5 co-author role)
- `.claude/agents/senna.md` (PR review + backend QA co-author per D5)
- `assessments/qa-reports/` (existing artifact landing — Stage 3 reports continue to land here per Rule 16)

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has clear owner (azir), no unresolved TBDs in gating sections, and concrete tasks T1–T3 with DoDs. Architectural surface is well-bounded: Stages 3 and 4 are explicitly carry-forward (no Rule 16/17 text changes), and Stages 1–2 are the new contracts with frontmatter + body shape fully specified. Open Questions all carry recommended defaults so none are gating. Synthesis ADR §7.5 stamps recommended-default approval across Group C governing this ADR (Hands-off Default).
