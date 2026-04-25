---
status: proposed
concern: personal
owner: swain
created: 2026-04-25
tests_required: false
complexity: complex
qa_plan: none
qa_plan_justification: synthesis ADR — no user-observable surface; ties five upstream ADRs into one canonical process doc and enumerates Orianna gate v2 amendments. Implementation work is downstream.
orianna_gate_version: 2
priority: P0
last_reviewed: 2026-04-25
tags: [architecture, process, synthesis, canonical-v1, plan-lifecycle, qa, pr-review, ux, parking-lot, assessments, sequencing]
related:
  - plans/proposed/personal/2026-04-25-plan-of-plans-and-parking-lot.md
  - plans/proposed/personal/2026-04-25-assessments-folder-structure.md
  - plans/proposed/personal/2026-04-25-structured-qa-pipeline.md
  - plans/proposed/personal/2026-04-25-pr-reviewer-tooling-guidelines.md
  - plans/proposed/personal/2026-04-25-frontend-uiux-in-process.md
  - plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md
  - plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md
  - plans/in-progress/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
  - plans/approved/personal/2026-04-25-architecture-consolidation-v1.md
  - plans/approved/personal/2026-04-25-pre-dispatch-parallel-slice.md
  - architecture/agent-network-v1/plan-lifecycle.md
  - architecture/agent-network-v1/coordinator-boot.md
  - architecture/agent-network-v1/routing.md
  - architecture/agent-network-v1/taxonomy.md
  - architecture/agent-network-v1/README.md
  - CLAUDE.md
architecture_changes:
  - architecture/agent-network-v1/process.md
  - architecture/agent-network-v1/README.md
  - architecture/agent-network-v1/plan-lifecycle.md
---

# Unified Process Synthesis — connecting plan-of-plans + assessments + QA + reviewer + UI/UX into one canonical process

## 1. Context

On 2026-04-25 five process-shaping ADRs landed in `plans/proposed/personal/` within hours of each other:

| # | Slug | Commit | Surface |
|---|------|--------|---------|
| 1 | `2026-04-25-plan-of-plans-and-parking-lot.md` | `cd237f93` | Backlog priority (P0–P3), `ideas/<concern>/` parking lot, `/backlog` skill, `last_reviewed:` staleness |
| 2 | `2026-04-25-assessments-folder-structure.md` | `b1003cc0` | 8-category taxonomy, prefix-date naming, 8+4 frontmatter, 2-state lifecycle (`active|archived` + `superseded` overlay), per-category INDEX |
| 3 | `2026-04-25-structured-qa-pipeline.md` | `8df81d67` | 4 stages (QA Plan in plan / draft-PR Akali / pre-merge / post-deploy), Lulu+Senna co-author, throw-away human-only |
| 4 | `2026-04-25-pr-reviewer-tooling-guidelines.md` | `4bf46ba2` | `_shared/reviewer-discipline.md` primitive, 5-axis checklists per lane, plugin closure, Senna→Camille escalation, reviewer-of-reviewer audit |
| 5 | `2026-04-25-frontend-uiux-in-process.md` | `b1003cc0` | §UX Spec required, Rule 22 (PreToolUse hook gates Seraphine/Soraka), Lulu/Neeko routing, 6-item a11y floor, stage-2 usability, PR markers, design-system stub |

Adjacent to them: the QA two-stage ADR (`2026-04-25-qa-two-stage-architecture.md`), the Karma quick-lane parallel-slice doctrine (`2026-04-25-pre-dispatch-parallel-slice.md`, approved), the architecture consolidation v1 (`2026-04-25-architecture-consolidation-v1.md`, approved — W1 + W2 shipped, W3 pending), and the retrospection dashboard + canonical-v1 lock (`2026-04-25-retrospection-dashboard-and-canonical-v1.md`, in-progress; lock-Saturday target).

Duong's directive (verbatim): *"After they all returned, have Swain take a look at all the plans and figure out a way to connect all of them and what we're currently having into a well designed process that's optimized for both quality and speed."*

The five ADRs, plus the existing W1+W2 invariants (Rules 1–21, plus Rule 22 pending under ADR #5), describe a single process if read together — but no document does the joining. Without this synthesis: (a) Orianna gate v2 will be amended three or four times in series instead of once; (b) `qa-reports/` location and shape will be specified by two ADRs without a pinned hand-off; (c) coordinators will not know whether stage-2 advisory means Akali (ADR #3) or Lulu (ADR #5) or both; (d) the canonical-v1 manifest (Saturday lock) will pin pieces of the process while the joins are still ambiguous, forcing post-lock relitigation.

This ADR is the join. It does not redefine any of the five; it sequences them, resolves conflicts between them, surfaces every open question consolidated, and proposes the canonical doc landing target. It is intentionally pre-canonical-v1-lock urgent — the lock manifest needs to pin **the process** as a single named artifact, not five independent artifacts.

## 2. Decision (synthesis primitives)

Five primitives shape the unified process:

1. **One canonical pipeline doc — `architecture/agent-network-v1/process.md`** — single W3 doc that documents the full journey from idea → parking-lot → proposed plan → Orianna approve gate (with QA Plan + UX Spec sub-gates) → breakdown → impl-with-stages → PR → review → merge → post-deploy. This doc cites the five ADRs as authority but renders the flow once.
2. **One Orianna gate v2 amendment wave — not five** — the gate gains three new fields in a single migration: `priority:` + `last_reviewed:` (ADR #1), `qa_plan:` + `qa_co_author:` (ADR #3), and §UX Spec body section + path-glob check (ADR #5). All three land in one Orianna re-sign cycle, not three.
3. **Stage-2 is two parallel, non-conflicting passes — not one** — Akali smoke (ADR #3 stage 2: ON-TRACK/DRIFT/BLOCKED on acceptance criteria) and Lulu usability check (ADR #5 D4: friction/affordance/copy ambiguity). They look at different signals, fire on the same trigger ("interactive surface ready"), and their outputs are coordinator-routed to the same impl agent. They are NOT two stage-2's; they ARE one stage-2 with two parallel observers.
4. **Path contracts hand off cleanly** — `assessments/qa-reports/<concern>/<slug>/...` (ADR #2 §3 row 2) is the location into which ADR #3 stage 3 reports land. ADR #2's frontmatter contract (date/author/category/concern/target/state/owner/session) wraps; ADR #3's body shape (cite_kind/cite_evidence per the QA two-stage ADR) is the inner content. ADR #2 owns the wrapper; ADR #3 owns the body.
5. **Speed comes from the pre-dispatch parallel-slice doctrine** — once the gate(s) clear and the plan is `approved/`, the canonical fast path is to dispatch Lulu/Neeko (UX Spec amendment if needed) + Caitlyn (QA Plan amendment if needed) + Aphelios/Kayn (task breakdown) in parallel, not in series. The plan is already shaped; the breakdown phase is where serial-by-default kills throughput. See §6 for canonical fast-path patterns.

These five primitives together let us hold the contract: **quality non-negotiables stay non-negotiable, but the cost of running them concurrently is paid once.**

## 3. Unified flow — full journey from idea to post-deploy

The flow has eight stages. Each is named, owned, gated, and produces a defined artifact. Mermaid diagram first, then the stage-by-stage table.

```mermaid
flowchart TD
  A["IDEA<br/>ideas/&lt;concern&gt;/YYYY-MM-DD-slug.md<br/>5-field frontmatter<br/>(ADR #1 §A2)"] -->|coordinator decides<br/>idea is ready| B
  B["PROPOSED PLAN<br/>plans/proposed/&lt;concern&gt;/...<br/>+priority: P0-P3<br/>+last_reviewed:<br/>+qa_plan:<br/>+§UX Spec if UI<br/>(ADR #1+#3+#5)"] -->|Orianna fact-check<br/>+priority+qa_plan+UX<br/>(see §5 wave plan)| C
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

### Stage-by-stage table

| Stage | Name | Owner | Gate | Artifact | ADR(s) authoritative |
|-------|------|-------|------|----------|----------------------|
| 0 | **Parking lot** | Coordinator authors; any agent may suggest via inbox | None — free write | `ideas/<concern>/YYYY-MM-DD-<slug>.md` | ADR #1 §A2 |
| 1 | **Promote idea → proposed plan** | Coordinator decides; dispatches Swain/Azir to author | None — coordinator judgment | `plans/proposed/<concern>/...` (idea deleted in same commit) | ADR #1 §A3 |
| 2 | **Orianna approve gate** | Orianna agent | Frontmatter (`priority`, `last_reviewed`, `qa_plan`, `qa_co_author`, `architecture_impact`) + body (`## QA Plan` if `qa_plan: required`, `## UX Spec` if UI path-glob, `## Architecture impact`) + plan-structure linter | `plans/approved/<concern>/...` with `orianna_signature_approved` | ADR #1 §A1 + ADR #3 §D2 + ADR #5 §D2 |
| 3 | **Breakdown + design-fill (parallel)** | Aphelios/Kayn (tasks); Lulu/Neeko (UX Spec amendment if not authored at plan time); Caitlyn (QA Plan amendment if needed) — all dispatched in parallel | None — pre-dispatch parallel-slice doctrine | Inline task list + amended §UX Spec + amended §QA Plan; plan moves `approved/ → in-progress/` with `orianna_signature_in_progress` | Pre-dispatch parallel-slice doctrine + ADR #3 §D5 + ADR #5 §D6 |
| 4 | **Implementation (xfail-first)** | Implementer (Aphelios/Karma/Ekko/Seraphine/Soraka/Viktor/Caitlyn/Vi/Jayce) | Rule 12 (xfail commit before impl); Rule 22 PreToolUse hook (Seraphine/Soraka blocked if §UX Spec missing); Rule 13 (regression test on bug fix); Rule 14 (pre-commit unit tests) | Code commits on PR branch | Rules 12/13/14/22 + ADR #5 §D2 |
| 5 | **Stage-2 parallel observers (mid-build)** | Coordinator dispatches Akali (smoke mode) + Lulu (usability) when impl reports "interactive surface ready" | Coordinator dispatch (advisory, not gating in v1 per ADR #3 OQ-3) | `QA-Draft:` block in PR draft body (Akali); inline coordinator-routed friction notes (Lulu) | ADR #3 §D3 + ADR #5 §D4 |
| 6 | **Pre-merge (stage 3)** | Akali OBSERVES; Senna 5-axis; Lucian 5-axis; Camille if security-blast-radius | Rule 16 (Akali run + report); Rule 18 (1 non-author approve); reviewer-discipline primitive (`_shared/reviewer-discipline.md`) | `assessments/qa-reports/<concern>/<slug>/{report.md, screenshot-*.png, video.webm}` (ADR #2 path) with `cite_kind`/`cite_evidence`/`head_sha` (QA two-stage ADR body shape); PR-body markers `QA-Report:`, `Design-Spec:`, `Accessibility-Check:`, `Visual-Diff:`, `Plan:` | ADR #4 + ADR #3 §D4 + QA two-stage ADR + ADR #5 §D7 |
| 7 | **Merge → implemented** | PR author; Orianna re-signs `implemented` | Rule 18 + all required CI checks green; Orianna `in-progress → implemented` gate verifies `architecture_changes` paths actually modified | `plans/implemented/<concern>/...` with `orianna_signature_implemented` | Orianna gate v2 |
| 8 | **Post-deploy (stage 4)** | CI smoke + auto-rollback | Rule 17 | Smoke logs + rollback artifact | Rule 17 (unchanged by these ADRs) |
| 9 | **Retro + reviewer audit (asynchronous)** | Skarner v2 dashboard panel; Duong manual spot-check until panel exists | None | `assessments/retrospectives/<concern>/...` per ADR #2; reviewer-quality panel data | ADR #4 §D8 + ADR #2 §3 row 5 |

The five-phase plan lifecycle (`proposed → approved → in-progress → implemented → archived`) is unchanged. The numbers above are stage counts of the **execution flow**, not lifecycle phases.

## 4. Quality-vs-speed framing per stage

Every stage costs time and buys quality. The synthesis question is: **for each stage, what is the unit-cost of running it, and what failure mode does skipping it introduce?**

| Stage | Time cost | Quality bought | Cheap-quality win? | Load-bearing (don't cut)? | Genuinely cuttable? |
|-------|-----------|----------------|--------------------|----------------------------|--------------------|
| 0 Parking lot | ~5 min/idea (write) | Defer breakdown until it matters → no stale plans, no premature Aphelios cycles | YES — biggest cheap win in the whole pipeline. Cost is one file write; saves hours of breakdown for ideas that never ship. | Quality of `ideas/` discipline is non-load-bearing (ideas can be wrong; that's the point). | Whole stage is optional for emergency fast-path, but should default ON. |
| 1 Promote idea → plan | ~30–90 min depending on scope; Swain/Azir authored | The structural decisions are made by the architect, not the implementer. Avoids "we built the wrong thing." | Cheap when idea is well-formed; expensive when not. | Non-skippable for non-Karma plans. Karma quick-lane plans (`2026-04-25-pre-dispatch-parallel-slice.md`) skip `proposed/` entirely. | Karma quick-lane is the cut for trivial work. |
| 2 Orianna gate | ~5–15 min (fact-check pass + rendering) | Frontmatter contract enforced; gating questions surfaced; downstream consumers (qa_plan, UX Spec, priority) checked once. | YES — the gate is automated; cost is dominated by author rework when fields are missing, not by the gate itself. | Non-skippable. The gate is the canonical authority for "this plan is real and ready." | No — gate-skipping is a class of governance drift (per Swain memory item 5). |
| 3 Breakdown + design-fill (parallel) | ~30–60 min if serial; ~15–25 min if parallel-slice | Breakdown is faithful to plan; UX Spec is authored by design owner; QA Plan is testable. | YES — parallel-slice is the dispatch-discipline win. Three agents dispatched in one coordinator turn = ~3x speedup over serial. | Quality of breakdown IS load-bearing (bad breakdown = bad impl). | Cannot cut the work; CAN cut the wall-clock by parallel dispatch. **§6 names the canonical fast-path patterns.** |
| 4 Implementation (xfail-first) | Variable — wave-clocked by impl scope | Rule 12 catches "no test = no impl" at commit time; Rule 13 catches regression-test absence; Rule 14 catches local-test failures pre-push. | xfail-first is cheap structurally but expensive socially (people want to "just write the code"). | **NON-NEGOTIABLE.** Rule 12 is the entire reason `xfail-first` exists. | Never. See §7. |
| 5 Stage-2 (parallel observers) | Akali smoke ≤2 min (ADR #3 OQ-6); Lulu usability ~10 min (ADR #5 D4) | DRIFT caught at draft = no rebuild churn; usability friction caught at draft = no copy-rewrite at PR open. | YES — stage-2 is the highest-leverage quality stage we don't currently run. Two parallel observers, ~12 min total wall-clock, catches scope drift AND usability gaps. | Yes — but advisory in v1 per ADR #3 OQ-3 (promote to hard gate after 4 weeks <10% false-positive). | Skipping = re-introducing the failure mode the entire ADR #3 was written to fix. Don't cut. |
| 6 Pre-merge (stage 3) | Akali ~5–10 min full Playwright; Senna ~10–20 min; Lucian ~10–20 min; Camille ~5–10 min when dispatched | This is the fortress. Five-axis Senna + five-axis Lucian + Akali pixel-diff + (conditionally) Camille security review = the bulk of the safety contract. | NO — this stage is the expensive one. The cost is justified because each axis catches a different failure class. | **NON-NEGOTIABLE.** Rule 16 + Rule 18 + reviewer-discipline primitive. | Reviewer-of-reviewer audit (ADR #4 D8) is the meta-check that this stage is calibrated correctly. Skip ANY of the four (Akali, Senna, Lucian, conditional Camille) on a non-trivial PR = governance drift. |
| 7 Merge | <1 min | Orianna re-signs `implemented`; lifecycle phase advances. | Cheap. | Non-skippable. | No. |
| 8 Post-deploy (stage 4) | stg smoke ~5 min + prod smoke ~5 min + auto-rollback infrastructure | Catches deploy-only failures (env config, DNS, IAM); auto-rollback bounds blast radius. | YES — smoke is fast; rollback is automatic. | **NON-NEGOTIABLE for prod.** Rule 17. | stg-fail can sometimes be deferred to manual; prod-fail never. |
| 9 Retro + reviewer audit | Asynchronous — accumulated work | Bug correlation + reviewer calibration drift + idea spawn loop = the only way we know the previous 8 stages are working. | YES once the dashboard panel exists; manual audit (5 PRs/month) is the cheap interim. | Non-load-bearing on a per-PR basis; LOAD-BEARING in aggregate. Without it the 8 stages above become unfalsifiable. | Don't cut; defer dashboard work to v2 if needed. Manual audit is the floor. |

### Where the cheap quality wins are

- **Stage 0 (parking lot)**: defer breakdown until it matters → biggest cheap win in the whole pipeline.
- **Stage 3 (breakdown parallel-slice)**: ~3x dispatch wall-clock speedup with zero quality loss. **The single largest speed-leverage point in the system.**
- **Stage 5 (parallel stage-2 observers)**: ~12 min total to prevent rebuild churn + usability rewrites; advisory in v1 keeps it cheap until calibrated.

### Where the expensive quality is paid because it's load-bearing

- **Stage 6 (pre-merge)**: the fortress. Four reviewers (Akali + Senna + Lucian + conditional Camille) on every non-trivial PR. This is the gate that keeps shipped code correct, secure, scalable, and reliable. Don't cut.
- **Stage 4 (xfail-first)**: Rule 12. The xfail commit is annoying socially but it's the discipline that lets us catch "no test = no impl" before the code lands.
- **Stage 8 (post-deploy)**: Rule 17. Auto-rollback on prod failure is non-skippable.

### Where genuine cuts exist

- **Karma quick-lane** for trivial plans bypasses Stage 0–2 (no parking lot, no proposed plan, no Orianna gate). The pre-dispatch parallel-slice doctrine plan (`2026-04-25-pre-dispatch-parallel-slice.md`, approved) names this lane explicitly.
- **`qa_plan: none` + `UX-Waiver:`** bypass Stage 2's QA Plan + UX Spec checks for plans that genuinely have no user-observable surface (infra/ops/agent-defs/docs). ADR #3 §D2 and ADR #5 §D2 both define the bypass shape.
- **Stage 5 is advisory in v1**. Acceptable cut today; promote to hard gate after 4-week observation per ADR #3 OQ-3.

## 5. Conflict resolution between ADRs

Reading the five together surfaces seven conflicts or ambiguities. Each is named, then resolved.

### Conflict C1 — Stage 2 ownership: Akali (ADR #3) vs Lulu (ADR #5)

**The conflict.** ADR #3 §D3 names Akali as the stage-2 observer in "smoke mode" — runs Playwright against acceptance criteria, returns ON-TRACK/DRIFT/BLOCKED. ADR #5 §D4 names Lulu as the stage-2 observer doing a "usability check" — walks the flow as a fresh user, returns friction/affordance/copy notes. **Are these the same stage 2 or two different ones?**

**Resolution.** They are **the same stage 2 with two parallel observers.** Different signals: Akali looks at *did we build what the acceptance criteria say*, Lulu looks at *can someone other than the implementer use what we built*. Same trigger (impl reports "interactive surface ready"). Same coordinator routing (notes return to the impl agent). Same advisory-not-gating disposition in v1. **The unified-process doc names this as "Stage 5 — parallel observers" and lists both observers explicitly.** No mutual-exclusion; coordinator dispatches both in parallel.

This was foreshadowed by the cross-coherence note in ADR #4 §Follow-ups item 4. Ship the synthesis with both observers documented as one stage.

### Conflict C2 — Camille's role across PR review (ADR #4) vs QA pipeline (ADR #3)

**The conflict.** ADR #4 §D6b puts Camille on the dispatch path for security-blast-radius PRs, advisory to Senna. ADR #3 (QA pipeline) does not mention Camille at all. **Is QA-stage Camille involvement needed?**

**Resolution.** **Camille is review-stage, NOT QA-stage.** The QA pipeline (Akali/Lulu/Senna-as-diagnoser) is observation-and-diagnosis of *user-observable behavior*. Camille is a security-blast-radius advisor on *code-and-deploy patterns*. They operate on different artifacts (Akali on rendered UI; Camille on diff). No overlap; no joint dispatch.

The unified-process doc clarifies: stage 6 (pre-merge) has four reviewers in parallel — Akali (QA), Senna (5-axis), Lucian (5-axis), Camille (conditional, security-blast-radius detection). Stage 5 (mid-build observers) has two — Akali smoke + Lulu usability. **Camille does not fire at stage 5.**

### Conflict C3 — `qa-reports/` location and frontmatter

**The conflict.** ADR #2 §3 row 2 pins `qa-reports/` location at `assessments/qa-reports/personal/` and `assessments/qa-reports/work/` (concern-scoped); the 8-field mandatory frontmatter wraps. ADR #3 §D6 cites `assessments/qa-reports/` for stage-3 reports without specifying concern subdirs or frontmatter. The QA two-stage ADR adds a `head_sha:` field. **Do the path/frontmatter contracts match?**

**Resolution.** **ADR #2 owns the location and the frontmatter wrapper; the QA ADRs own the body shape.** Concretely:

- **Location** (ADR #2): `assessments/qa-reports/<concern>/<YYYY-MM-DD>-<slug>/{report.md, screenshot-*.png, video.webm, *.html}` — the per-PR subdirectory pattern from ADR #2 §4.
- **Wrapper frontmatter** (ADR #2 §5): 8 mandatory fields (`date`, `author`, `category: qa-reports`, `concern`, `target`, `state`, `owner`, `session`) + 4 optional. **Plus** the QA-specific `head_sha:` field added to the optional set as a QA-category convention.
- **Body shape** (ADR #3 §D3 + QA two-stage ADR D2): four sub-headings — Acceptance criteria walked, Failure modes encountered, Cite-kind table (`cite_kind: verified | inferred`, `cite_evidence`), Verdict block.

**The unified-process doc records this hand-off explicitly.** ADR #2 implementation MUST land before ADR #3 implementation, otherwise the wrapper contract is undefined when the QA ADR's body shape goes live. See §6 wave plan.

### Conflict C4 — Ideas vs implementation: can an idea be implemented from raw state?

**The conflict.** ADR #1 §A3 says explicitly: ideas cannot be implemented from raw state — must first promote to `plans/proposed/<concern>/`. The other ADRs do not mention this. Is the contract that NO agent implements anything from `ideas/` ever?

**Resolution.** **Yes, no exceptions.** The unified-process doc states this as a gate: any dispatch (Aphelios, Kayn, Seraphine, Soraka, Caitlyn, Karma, Ekko, etc.) referencing a path under `ideas/` MUST be rejected by the coordinator. This is symmetric to the "Aphelios cannot dispatch impl on a `proposed/` plan that hasn't passed Orianna gate" rule. **A future PreToolUse hook (`scripts/hooks/pretooluse-ideas-impl-guard.sh`) is a candidate enforcement** but is out of scope for any of the five ADRs and not proposed in this synthesis — coordinator-discipline + plan-lifecycle-guard's existing scope is sufficient for v1.

### Conflict C5 — Orianna gate v2 amendment count

**The conflict.** ADR #1 amends the gate with `priority:` + `last_reviewed:` checks (§A1). ADR #3 amends with `qa_plan:` field + `## QA Plan` section verification (§D2). ADR #5 amends with `## UX Spec` body section + UI-path-glob check (§D2 + OQ-1). **Three independent amendments to the same gate.**

**Resolution.** **Single migration wave.** The Orianna gate v2 is amended once with all three new contracts merged into the gate's check set. Sequencing the amendments serially would require Orianna re-signing the gate spec three times, each invalidating prior signatures via body-hash; one merged migration is one re-sign cycle.

The unified-process doc names this as "Orianna gate v3" if signaling the version bump is helpful, OR keeps "gate v2 with amendment 2026-04-26" if version churn is undesirable. **Recommendation: keep `orianna_gate_version: 2` and amend the v2 spec in one commit; bump to v3 only if a future ADR introduces a backward-incompatible change.** See §6 wave plan.

### Conflict C6 — `qa_co_author` vs `Lulu/Neeko` UX-Spec author

**The conflict.** ADR #3 §D5 says `qa_co_author: lulu` for UI plans (Lulu reviews the §QA Plan §Acceptance criteria + Happy path). ADR #5 §D6 says Lulu (or Neeko) authors the §UX Spec. **Are these two roles for Lulu, or one?**

**Resolution.** **Two roles, one Lulu** (or Neeko on complex track). Lulu/Neeko authors the §UX Spec at plan time AND co-reviews the §QA Plan §Acceptance criteria for design-intent fidelity. Same agent, two artifacts, both at plan-authoring time (or breakdown stage if amendment is needed). **The unified-process doc names this as "Stage 2 — design + QA co-author" and lists both deliverables under one dispatch.**

Practically: when Evelynn dispatches Lulu for a UI plan, Lulu authors §UX Spec inline AND reviews §QA Plan §Acceptance criteria for whether they match the design's user flow. One dispatch, two outputs. This is a coordinator-discipline detail; no ADR amendment needed.

### Conflict C7 — `priority:` field on plans that skip `proposed/`

**The conflict.** ADR #1 says `priority:` is required on `plans/proposed/**` and removed once the plan moves to `approved/`. Karma quick-lane plans (per the parallel-slice doctrine) skip `proposed/` entirely and go straight to `in-progress/`. **Do they get a `priority:` field?**

**Resolution (per ADR #1 OQ-3).** **No.** Karma quick-lane plans do not enter the backlog and do not carry `priority:`. The unified-process doc records this as the "fast-path bypass" — Karma quick-lane explicitly skips Stages 0, 1, 2 of the unified flow (parking lot → promote → Orianna approve gate). They enter at Stage 4 (impl) directly. Bookkeeping: the parallel-slice doctrine plan already pins this; the synthesis just confirms.

## 6. Implementation sequencing — the wave plan

Five ADRs need to land in order. Wrong sequence = re-amendment churn. Right sequence = one Orianna re-sign cycle and one canonical doc emission.

**Sequencing constraint analysis:**

- **ADR #2 (assessments)** defines the `qa-reports/` location and the wrapper frontmatter. ADR #3 (QA pipeline) writes into that location. → ADR #2 MUST land before ADR #3 implementation. (The ADRs themselves are already promoted independently; the *implementation work* sequencing is the constraint.)
- **ADR #1 (priority + parking lot)**, **ADR #3 (qa_plan)**, **ADR #5 (UX Spec)** all amend the Orianna gate v2 frontmatter contract. → land all three gate-amendments in ONE Orianna re-sign cycle (per Conflict C5).
- **ADR #4 (reviewer tooling)** is independent of the gate amendments — it touches `_shared/reviewer-discipline.md`, agent-defs (Senna, Lucian, Camille), and coordinator dispatch heuristic. Can land in parallel with any wave.
- **ADR #5 (UI/UX) Rule 22 hook** is an independent enforcement layer — can land in parallel with the gate-amendment wave; doesn't depend on §UX Spec lint passing on legacy plans (sweep grandfathers).
- **The unified-process canonical doc** (this ADR's main deliverable, `architecture/agent-network-v1/process.md`) MUST land **after** the five ADRs are promoted but **before** the canonical-v1 lock manifest is finalized — otherwise the lock pins five disconnected ADRs instead of one process.

### Proposed wave plan (analogous to architecture-consolidation W0–W3)

**W0 — Foundation, no behavioral change** (concurrent; ~1 day total)

| Task | Source ADR | Why first |
|------|-----------|-----------|
| Create `ideas/personal/.gitkeep` and `ideas/work/.gitkeep` | #1 | Directory existence is a prereq for any later move. Zero behavioral risk. |
| Create `assessments/qa-reports/<concern>/` subdirs (concern split per ADR #2 §3 row 2) | #2 | Same. Prereq for ADR #3 implementation. |
| Create `_shared/reviewer-discipline.md` primitive (skeleton; no `<!-- include: -->` wiring yet) | #4 | Independent file; safe to land. Wiring waits for W2. |
| Author `architecture/agent-network-v1/process.md` (this ADR's doc deliverable; first draft based on §3 of this synthesis) | This ADR | Doc-only; no code or hook impact. **Must land before lock manifest.** |

**W1 — Migration / wrapper contracts** (concurrent; ~2 days)

| Task | Source ADR | Why before W2 |
|------|-----------|---------------|
| Migrate existing `assessments/` files into 8-category tree per ADR #2 §9 (a separate plan: `<date>-assessments-migration-execution.md`); back-fill frontmatter | #2 | The wrapper for `qa-reports/` must be in place before ADR #3 implementation writes there. Tree migration is the prereq. |
| One-shot script `scripts/backlog-init-priority.sh` injects `priority: P2` and `last_reviewed: <today>` into existing proposed plans | #1 | Existing plans must satisfy the new gate after Orianna re-amendment in W2. |
| Sweep approved-personal plans for §QA Plan back-fill (per ADR #3 §D7 Karma sweep T3) | #3 | Same reasoning — existing approved plans need `qa_plan` frontmatter before gate enforcement. |
| Sweep approved-personal plans for §UX Spec back-fill OR `UX-Waiver:` annotation | #5 | Same. |

**W2 — Orianna gate v2 single re-amendment + hooks** (concurrent within wave; ~1–2 days)

| Task | Source ADR | Why bundled |
|------|-----------|-------------|
| Orianna gate v2 amended in one re-sign cycle to enforce: `priority:` + `last_reviewed:` (#1), `qa_plan:` + `qa_co_author:` + §QA Plan body (#3), §UX Spec body + path-glob check (#5), `architecture_impact:` (already enforced) | #1, #3, #5 | Single re-amendment per Conflict C5. |
| `scripts/hooks/pre-commit-zz-plan-structure.sh` extended with `priority:`, `last_reviewed:`, `qa_plan:`, §QA Plan, §UX Spec checks | #1, #3, #5 | Same hook; one extension. |
| New hook `scripts/hooks/pre-commit-zz-idea-structure.sh` (forbidden-headers lint per ADR #1 §A2) | #1 | Independent of gate. |
| New hook `scripts/hooks/pretooluse-uxspec-gate.sh` (Rule 22 — Seraphine/Soraka block on missing §UX Spec) | #5 | Independent enforcement layer. |
| `<!-- include: _shared/reviewer-discipline.md -->` wired into `senna.md` and `lucian.md`; `scripts/sync-shared-rules.sh` regenerates | #4 | Safe to ship in parallel. |
| Five-axis checklists added to `senna.md` (A–E) and `lucian.md` (F–J) | #4 | Same. |
| Coordinator routing heuristic for security-blast-radius Camille dispatch | #4 | Same. |

**W3 — New CI checks + canonical doc emission** (~1 day)

| Task | Source ADR | Why last |
|------|-----------|----------|
| GitHub Actions `qa-draft-reminder.yml` (stage-2 reminder per ADR #3 §D8) | #3 | Depends on `qa_plan:` frontmatter being present (W2). |
| `.github/workflows/pr-lint.yml` extended with `pr-frontend-markers` job (Design-Spec/Accessibility-Check/Visual-Diff per ADR #5 §D7) | #5 | Independent; can ship in W2 too. |
| Update `CLAUDE.md` with Rule 22 (frontend) | #5 | Touches universal-rules surface; land last. |
| Update `architecture/agent-network-v1/plan-lifecycle.md` with backlog/parking-lot section (ADR #1 §D1) | #1 | Doc amendment; safe to ship anytime in W2/W3. |
| Update `architecture/agent-network-v1/README.md` to point at `process.md` | This ADR | Last — once `process.md` is final from W0. |
| Pin `architecture/agent-network-v1/process.md` in canonical-v1 lock manifest | Retrospection-dashboard ADR | **MUST be last item before lock**. |

**W4 — Post-lock observation** (4 weeks)

- Stage-2 false-positive rate measurement (ADR #3 OQ-3) — promote to hard gate if <10%.
- First reviewer-of-reviewer audit assessment (ADR #4 §D8 manual bridge) — Duong manual spot-check on 5 PRs.
- ADR #2 enforcement-hook hardening (frontmatter required, naming required, category-folder agreement).

### Why this sequence

- **Foundation first (W0)**: directories and the doc itself are prereqs. Zero behavioral risk; nothing to undo.
- **Migration second (W1)**: existing artifacts must satisfy the new gate before the gate is amended. Otherwise W2 immediately blocks every existing plan.
- **Single gate re-amend (W2)**: per Conflict C5. All three frontmatter contracts merge in one Orianna re-sign cycle.
- **Doc emission last but pre-lock (W3)**: `process.md` is the canonical authority. It must reflect the gate's actual state and must land before the lock pins it.

## 7. Open questions consolidated (compact-form-ready)

Grouped by surface. Each has a recommended default; Duong can answer in compact form (`1a 2b 3c`).

### Group A — Orianna gate v2 amendments

- **A1. Single re-amendment vs version bump?** Recommendation: **(a)** keep `orianna_gate_version: 2` and amend in one commit. (b) bump to v3.
- **A2. `qa_plan: required` default-on for backend plans with user-observable acceptance criteria?** Recommendation: **(a)** YES if API observable in any user flow within 30 days; NO if internal-only or feature-flagged off. (b) always YES on every backend plan with acceptance criteria. (c) coordinator judgement, no default.
- **A3. `UX-Waiver:` allowed on `complexity: complex` plans?** (ADR #5 OQ-2) Recommendation: **(a)** restrict to `standard | trivial`; complex MUST have §UX Spec. (b) allow at all complexities with reason. (c) coordinator judgement.

### Group B — Frontmatter / contract

- **B1. ADR #2 `concern: cross` as a real third value?** (ADR #2 OQ-4) Recommendation: **(a)** YES — keep for genuinely cross-concern material. (b) NO — force pick `personal | work`.
- **B2. ADR #3 `qa_plan: required` re-sign on amendment of in-progress plan?** (ADR #3 OQ-1) Recommendation: **(a)** route through `approved → in-progress` re-sign cycle (clean lifecycle, heavy). (b) Orianna `re-sign-in-progress` operation (cheap; defer to follow-up ADR). (c) treat body-hash mismatch on §QA Plan as soft warning.
- **B3. `head_sha:` field made mandatory in `qa-reports/` frontmatter wrapper?** Recommendation: **(a)** YES — directly motivated by Sona's wrong-head verification failure on PR #32 (per QA two-stage ADR D6f). (b) NO — keep optional.

### Group C — Hook / CI enforcement

- **C1. `priority:` lint enforcement: warn or fail?** (ADR #1 §A5 implicit) Recommendation: **(a)** start as warn for first 2 weeks; escalate to fail. (b) fail from day 1. (c) warn forever.
- **C2. ADR #2 frontmatter enforcement timing?** (ADR #2 OQ-5) Recommendation: **(a)** start as warn, escalate to fail after 2-week observation. (b) fail from migration day. (c) warn forever.
- **C3. Rule 22 (UX Spec gate) v1 hard-gate or advisory?** (Implicit; ADR #5 §D2 says hard gate.) Recommendation: **(a)** hard gate from W2 (matches ADR #5 D2). (b) advisory for 2 weeks; promote to hard gate.
- **C4. Stage-2 advisory → hard gate timeline?** (ADR #3 OQ-3) Recommendation: **(a)** advisory for 4 weeks at <10% false-positive rate, then hard gate. (b) advisory permanently. (c) hard gate from day 1.
- **C5. PreToolUse `pretooluse-ideas-impl-guard.sh` to block dispatch from `ideas/`?** (Conflict C4 escalation) Recommendation: **(a)** NO — coordinator discipline is sufficient for v1. (b) YES — add to W2.

### Group D — Agent-def edits / dispatch routing

- **D1. Camille parallel-dispatch trigger list — exact paths?** (ADR #4 §D6b implicit refinement) Recommendation: **(a)** the path list in D6b verbatim (`apps/**/server/`, `apps/**/auth/`, `scripts/deploy/**`, `.github/workflows/`, `tools/decrypt.sh`, branch-protection/CODEOWNERS, agent-identity boundaries). (b) extend with `mcps/**` server code. (c) labels-only, no path detection.
- **D2. Lulu dispatch verification at Stage 1 — declared-only or mandatory dispatch?** (ADR #3 OQ-4) Recommendation: **(a)** declared-only for v1 (light-touch); promote to mandatory if quality drifts. (b) mandatory dispatch from v1.
- **D3. Lulu vs Neeko routing tiebreak: Lulu-first-with-escalation or always Neeko on uncertainty?** (ADR #5 §D6) Recommendation: **(a)** Lulu-first; Lulu escalates to Neeko via `recommend_neeko: true`. (b) Neeko on uncertainty; cost overhead acceptable.
- **D4. Reviewer-of-reviewer audit cadence pre-dashboard?** (ADR #4 §D8 manual bridge) Recommendation: **(a)** Duong monthly spot-check 5 PRs. (b) bi-weekly 3 PRs. (c) defer entirely until dashboard panel ships.

### Group E — Doc / process surface

- **E1. Canonical-v1 lock manifest pins `architecture/agent-network-v1/process.md` as the unified-process artifact?** Recommendation: **(a)** YES — single named artifact in the lock. (b) NO — pin the five ADRs individually.
- **E2. `process.md` cites the five ADRs as authority but does not reproduce their decisions?** Recommendation: **(a)** YES — cite-only. ADRs remain source of truth. (b) `process.md` reproduces decision tables (risk: drift).
- **E3. ADR #1 `/backlog` skill scope: home-concern default vs `--all` cross-concern?** (ADR #1 OQ-2) Recommendation: **(a)** home concern default; `--all` shows both. (b) `--all` default. (c) only home concern always.
- **E4. ADR #2 `qa-artifacts/akali/` folding into `qa-reports/<concern>/<slug>/` subdirs vs separate `artifacts/qa/akali/`?** (ADR #2 OQ-2) Recommendation: **(a)** fold under `qa-reports/<concern>/<slug>/{report.md, screenshot-*.png, video.webm}` per ADR #2 §4 sub-grouped pattern. (b) keep separate.
- **E5. Stage-2 cross-concern uniform application?** (ADR #5 OQ-3) Recommendation: **(a)** YES uniform — Lulu/Neeko concern-agnostic at design layer. (b) personal-only for v1.

Recommended-default compact form (Duong's response shape): `A1a A2a A3a B1a B2a B3a C1a C2a C3a C4a C5a D1a D2a D3a D4a E1a E2a E3a E4a E5a` — 20 questions; defaults bias toward incremental/light-touch/conservative as the unified-process v1 baseline.

## 8. Speed-leverage points — canonical fast-path patterns

Five named dispatch patterns that the unified-process doc should encode as the canonical "fast path." Each is a parallel-slice opportunity that buys time without sacrificing quality.

### FP1 — UI plan post-approve fan-out (the headline)

**When**: UI plan moves `proposed → approved` (Orianna gate clears).

**Pattern**: Coordinator dispatches **three agents in parallel** in a single coordinator turn:

1. **Lulu (or Neeko on complex)** — author §UX Spec amendment (if not authored at plan-authoring time) per ADR #5 §D6.
2. **Caitlyn** — author §QA Plan amendment (if not authored at plan-authoring time) per ADR #3 §D5.
3. **Aphelios (or Kayn on complex)** — author task breakdown.

**Speedup**: ~3x wall-clock vs serial dispatch (15–25 min vs ~45–75 min serial).

**Quality preserved**: each agent operates on independent surface; outputs are concatenated by the coordinator before impl dispatch. No sequencing dependency between the three.

### FP2 — Backend plan post-approve fan-out

**When**: backend plan with user-observable acceptance criteria moves `proposed → approved`.

**Pattern**: **Two agents in parallel**:

1. **Senna (qa_co_author)** — review §QA Plan acceptance criteria for testability + failure-mode completeness per ADR #3 §D5.
2. **Aphelios (or Kayn)** — task breakdown.

**Speedup**: ~2x wall-clock vs serial.

### FP3 — Stage-2 parallel observers (mid-build)

**When**: impl agent reports "interactive surface ready" on a UI plan.

**Pattern**: **Two agents in parallel**:

1. **Akali (smoke mode)** — ON-TRACK/DRIFT/BLOCKED on acceptance criteria per ADR #3 §D3.
2. **Lulu (usability check)** — friction/affordance/copy notes per ADR #5 §D4.

**Speedup**: ~2x wall-clock vs serial; combined ~12 min total.

### FP4 — Stage-3 four-reviewer parallel (security-blast-radius case)

**When**: PR opens against branch implementing a plan AND diff matches Camille security-blast-radius detection (per ADR #4 §D6b).

**Pattern**: **Four agents in parallel**:

1. **Akali** — Rule 16 Playwright + Figma diff.
2. **Senna** — 5-axis review (correctness/security/scalability/reliability/test-quality).
3. **Lucian** — 5-axis review (plan/ADR/contract/deferral/cross-repo).
4. **Camille** — security verdict (BLOCK/NEEDS-MITIGATION/OK), advisory to Senna.

**Speedup**: ~4x wall-clock vs serial. Quality preserved because each agent's lane is non-overlapping.

**Non-security PRs** drop Camille → three-reviewer parallel.

### FP5 — Idea promotion fast-track

**When**: an idea in `ideas/<concern>/` becomes urgent (dependency unblocked, user-pain elevated) and coordinator decides to promote.

**Pattern**: **Two agents in parallel**:

1. **Swain (personal) or Azir (work)** — author proposed plan from idea body.
2. **Coordinator** — delete the original idea file in the same commit (ADR #1 §A3 rename-vs-rewrite contract).

**Speedup**: minor (~1.2x); the main win is structural — promotion is one coordinator turn, not a multi-step ritual.

### Encoded in `process.md`

The unified-process doc lists these five fast-path patterns under a `## Speed leverage` section, with example dispatch description for each. Coordinator routing-check shared primitive (`_shared/coordinator-routing-check.md` — lane-check + pair-set-check + slice-check from PR #66) gains a new check: "did you fan out per FP1/FP2/FP3/FP4/FP5 if the trigger matched?"

## 9. Quality non-negotiables — must-not-cut-for-speed

Listed explicitly so future "ship fast" pressure has a guard rail. Each item names the rule or ADR that defines it.

1. **Rule 12 — xfail test before impl on TDD-enabled services.** No exception ever. The xfail commit is the discipline that catches "no test = no impl" at commit time. Bypass = pre-push hook block + CI fail. Reasoning: stage 4 (impl) costs nothing if stage 6 (review) catches it; stage 6 doesn't catch missing tests reliably without Rule 12.
2. **Rule 13 — regression test before bug fix.** Same enforcement; same reasoning.
3. **Rule 14 — pre-commit unit tests.** Local feedback loop. Cheap.
4. **Rule 16 — Akali QA at PR open for UI/user-flow PRs.** Pre-merge stage 3 visual gate. Bypass via `QA-Waiver:` only for legitimate cases (no running staging environment); never as a speed cut.
5. **Rule 17 — post-deploy smoke + auto-rollback on prod.** Stage 8. Non-skippable for prod.
6. **Rule 18 — no `gh pr merge --admin` bypass; one non-author approve required.** Branch-protection structural enforcement.
7. **Rule 19 — Orianna gate v2 for plan promotions.** No skipping the gate. Hooks block.
8. **Rule 22 — UX Spec required for UI plans, hook-enforced.** Per ADR #5 §D9. Non-skippable; bypass via `UX-Waiver:` only for legitimate cases.
9. **§QA Plan acceptance criteria authored at plan-authoring time.** Per ADR #3 §D2. The criteria are the contract for stage 5 (Akali smoke) and stage 6 (Akali full). Skipping = "we built the wrong thing" failure mode returns.
10. **Reviewer-of-reviewer audit (manual bridge).** Per ADR #4 §D8. Even before the dashboard panel exists, the monthly 5-PR spot-check is the only feedback loop on whether the reviewers are calibrated. Skipping = unfalsifiable trust in stage 6.
11. **`_shared/reviewer-discipline.md` primitive in both Senna and Lucian agent-defs.** Per ADR #4 §D1. Phantom citation + stale-SHA + lane-bleed are anti-patterns named in D7; without the primitive they re-emerge.
12. **Throw-away decision is human-only.** Per ADR #3 §D9 last row. No agent ever decides to discard built work. Escalation to Duong is the only path.
13. **Dual non-author approval required (Rule 18).** No reviewer self-approves; no admin bypass.
14. **Stage 5 advisory v1 disposition.** Defaults to ON-by-coordinator-dispatch on UI plans with `qa_plan: required`. Cutting stage 5 entirely (claiming "we'll catch it at stage 6") = regression to pre-ADR-#3 state.

## 10. Process docs land target

Two questions: where does the unified process get documented, and what cross-references update?

### Primary canonical doc

**`architecture/agent-network-v1/process.md`** — new W3 file. Sibling to `coordinator-boot.md`, `plan-lifecycle.md`, `routing.md`, `taxonomy.md`. This is the single canonical authority for the unified process; the five ADRs cite into it as authority for their specific subsections.

**Structure** (one screenful per stage, mirrors §3 of this synthesis):

1. **Overview** — the eight stages, the mermaid diagram, the named pipeline.
2. **Stage 0 — Parking lot** — pointer to ADR #1 §A2.
3. **Stage 1 — Promote idea → plan** — pointer to ADR #1 §A3.
4. **Stage 2 — Orianna approve gate** — the merged frontmatter checklist (pointers to #1, #3, #5).
5. **Stage 3 — Breakdown + design-fill (parallel)** — fast-path pattern FP1/FP2; pointer to pre-dispatch parallel-slice doctrine plan.
6. **Stage 4 — Implementation (xfail-first)** — pointers to Rules 12/13/14/22.
7. **Stage 5 — Parallel observers (Akali + Lulu)** — Conflict C1 resolution; pointer to ADR #3 §D3 + ADR #5 §D4.
8. **Stage 6 — Pre-merge** — fast-path FP4; pointers to ADR #4 + Rule 16 + QA two-stage ADR.
9. **Stage 7 — Merge** — pointer to Rule 18 + Orianna gate v2.
10. **Stage 8 — Post-deploy** — pointer to Rule 17.
11. **Stage 9 — Retro + reviewer audit** — pointer to ADR #4 §D8 + ADR #2 §3 retrospectives row.
12. **Speed leverage** — fast-path patterns FP1–FP5.
13. **Quality non-negotiables** — verbatim from §9 above.
14. **Cross-references** — the five source ADRs + Rules 12, 13, 14, 16, 17, 18, 19, 22 + parallel-slice doctrine plan.

### Secondary amendments

- **`architecture/agent-network-v1/README.md`** — add a "Process" section (one paragraph + link to `process.md`).
- **`architecture/agent-network-v1/plan-lifecycle.md`** — append the "Backlog and parking lot" section per ADR #1 §D1.
- **`architecture/agent-network-v1/coordinator-boot.md`** — already contains the routing-check primitive; add a one-line note pointing at `process.md` as the canonical authority for stage-by-stage dispatch.
- **`architecture/agent-network-v1/taxonomy.md`** (plan template section) — add §UX Spec scaffolding per ADR #5 T2.
- **`CLAUDE.md` File Structure table** — point at `architecture/agent-network-v1/process.md` as the unified-process authority.
- **`agents/evelynn/CLAUDE.md` and `agents/sona/CLAUDE.md`** — add reference to `process.md` in their startup chain (read on boot for stage-by-stage dispatch context).

### NOT amended

- `architecture/agent-network-v1/system-overview.md` (if it exists post-W2) — high-level system doc; cross-references `process.md` but does not duplicate the stage table.
- The five source ADRs themselves — they remain authority for their specific subsections; this synthesis does not modify them.

## 11. Tasks

This ADR is architectural synthesis. Tasks are coordination + handoff, not self-implementation.

### T1 — Promote this synthesis ADR via Orianna

- kind: ops
- estimate_minutes: 10
- files: this plan path → `plans/approved/personal/`
- detail: After Duong sign-off and answers to §7 OQs, Evelynn dispatches Orianna with this plan path. Orianna fact-checks (frontmatter completeness, body section presence, references valid, all five source-ADR paths resolve) and on APPROVE git-mvs to `plans/approved/personal/`, signs `orianna_signature_approved`, commits with `Promoted-By: Orianna` trailer, pushes.
- DoD: plan in `plans/approved/personal/` with valid `orianna_signature_approved`.

### T2 — Author `architecture/agent-network-v1/process.md` (W0)

- kind: docs
- estimate_minutes: 90
- files: `architecture/agent-network-v1/process.md` (new), `architecture/agent-network-v1/README.md` (amendment)
- detail: Author the canonical doc per §10 structure. Cite the five source ADRs verbatim; do not reproduce their decisions. Use the §3 mermaid diagram as the overview. Land in W0 — no behavioral risk.
- DoD: `test -f architecture/agent-network-v1/process.md` returns 0; doc contains the eight stage headings; cross-references resolve via `find` + `grep`.

### T3 — Dispatch Kayn for W1+W2+W3 implementation breakdown

- kind: ops
- estimate_minutes: 30
- files: (no commits — Evelynn-side dispatch)
- detail: Once approved, Evelynn dispatches Kayn (in worktree per Rule 20) to break the implementation into ordered tasks. Implementation surface spans the wave plan §6. Kayn returns ordered task list inline (no `-tasks.md` sibling per Rule 20). Evelynn assigns implementers per task per Kayn's recommendation.
- DoD: inline task breakdown returned by Kayn; Evelynn has assigned implementers per task.

### T4 — Coordinate single Orianna gate v2 re-amendment (W2)

- kind: ops
- estimate_minutes: 60 (gated on T3 completion)
- files: `_orianna_v2_amendment.md` (Orianna's signed amendment artifact, location TBD by Orianna agent)
- detail: Per Conflict C5: amend the gate spec ONCE with all three new contracts merged (`priority` + `qa_plan` + §UX Spec). Orianna re-signs in one cycle. Coordinator (Evelynn) dispatches; verifies the body-hash signature.
- DoD: Orianna gate v2 spec contains all three amendments; downstream hooks in W2 read the amended spec.

### T5 — Pin `process.md` in canonical-v1 lock manifest (W3 final)

- kind: ops
- estimate_minutes: 10
- files: `architecture/canonical-v1.md` (per retrospection-dashboard ADR §canonical-v1 lock)
- detail: Add `architecture/agent-network-v1/process.md` to the lock manifest's pinned-paths list. **Last action before Saturday lock.**
- DoD: `architecture/canonical-v1.md` references `process.md` in its pinned-paths section.

## Test plan

`tests_required: false` — this ADR is structural meta-work (synthesis + sequencing + canonical doc target). Tests belong on the implementation work that Kayn breaks down (T3) per the wave plan §6.

The downstream tasks land tests via Rule 12 xfail-first ordering:

- W1 migration scripts: golden-file tests for assessments-tree migration + backlog priority injection.
- W2 hook extensions: integration tests per ADR #1, #3, #5 individual T2/T3 detail.
- W3 CI workflows: synthetic PR fixtures per ADR #5 §T5 detail.

These belong on the Kayn breakdown, not this synthesis ADR.

## Architecture impact

Touched docs (per `architecture_changes:` frontmatter):

1. **`architecture/agent-network-v1/process.md`** (new) — canonical unified-process doc per §10. Eight stages + speed-leverage + quality non-negotiables. Citing-only of the five source ADRs.
2. **`architecture/agent-network-v1/README.md`** (amendment) — add "Process" section pointing at `process.md`.
3. **`architecture/agent-network-v1/plan-lifecycle.md`** (amendment) — append backlog/parking-lot section per ADR #1 §D1 (this amendment is technically owned by ADR #1; the synthesis surfaces it for sequencing visibility).

Not touched: any of the five source ADRs (they remain authority for their subsections); `architecture/agent-network-v1/coordinator-boot.md` (cross-reference only, no edit); `CLAUDE.md` Rule 22 (added by ADR #5 §T1, not this synthesis).

Orianna `in-progress → implemented` gate verifies all three architecture_changes paths were actually modified per existing gate v2 conventions.

## Rollback

If the unified-process synthesis proves wrong:

1. Revert `architecture/agent-network-v1/process.md` (delete file).
2. Revert the README and plan-lifecycle amendments.
3. Strip `process.md` from canonical-v1 lock manifest.
4. The five source ADRs remain in their respective lifecycle states; no other rollback needed.

The synthesis is mechanical and reversible because it adds doc-only joins; it does not modify the source ADRs or change any code.

## References

### Source ADRs (the five being synthesized)

- `plans/proposed/personal/2026-04-25-plan-of-plans-and-parking-lot.md` (commit `cd237f93`) — backlog priority surface + parking lot.
- `plans/proposed/personal/2026-04-25-assessments-folder-structure.md` (commit `b1003cc0`) — 8-category taxonomy + frontmatter contract.
- `plans/proposed/personal/2026-04-25-structured-qa-pipeline.md` (commit `8df81d67`) — 4-stage QA pipeline.
- `plans/proposed/personal/2026-04-25-pr-reviewer-tooling-guidelines.md` (commit `4bf46ba2`) — reviewer-discipline primitive + 5-axis checklists.
- `plans/proposed/personal/2026-04-25-frontend-uiux-in-process.md` (commit `b1003cc0`) — §UX Spec + Rule 22 + a11y floor.

### Adjacent ADRs cited

- `plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md` — QA two-stage (Akali OBSERVES + Senna DIAGNOSES) cited at Stage 6 + Conflict C3 for `cite_kind`/`head_sha` body shape.
- `plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md` — Karma v1 tactical Akali patch.
- `plans/approved/personal/2026-04-25-pre-dispatch-parallel-slice.md` — parallel-slice doctrine cited at Stage 3 + §6 fast-path patterns.
- `plans/approved/personal/2026-04-25-architecture-consolidation-v1.md` — W1+W2 architecture consolidation; W3 location for `process.md`.
- `plans/in-progress/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md` — canonical-v1 lock manifest target.

### Repo invariants

- `CLAUDE.md` Rules 1–21 (current) + Rule 22 (pending under ADR #5).
- `architecture/agent-network-v1/{plan-lifecycle, coordinator-boot, routing, taxonomy, README}.md` — W1+W2 canonical authorities cross-referenced.
- `_shared/coordinator-routing-check.md` (lane + pair-set + slice from PR #66) — gains FP1–FP5 fast-path check.
- `_shared/coordinator-intent-check.md` — deliberation primitive; unaffected.
