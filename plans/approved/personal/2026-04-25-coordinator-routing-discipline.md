---
title: Coordinator routing discipline — cheat-sheet doc + dispatch primitive include
slug: coordinator-routing-discipline
date: 2026-04-25
owner: karma
concern: personal
status: approved
complexity: quick
orianna_gate_version: 2
tier: quick
pair_mate: talon
tests_required: true
related:
  - assessments/research/2026-04-25-coordinator-routing-discipline.md
  - .claude/agents/_shared/coordinator-intent-check.md
  - plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md
  - plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
  - agents/evelynn/learnings/2026-04-25-gate-bypass-on-surgical-infra-commits.md
tags: [agents, routing, coordinator, evelynn, sona, taxonomy, discipline]
---

# 1. Context

Two coordinator-routing failures landed today inside one session:

- **Error 1 — lane mismatch.** Evelynn dispatched **Talon** (quick-lane executor) against a **Swain**-authored plan (complex-lane architect). Plan owner `swain` ⇒ tier `complex` ⇒ valid impl set is `{viktor, rakan}`, not `{talon}`. The dispatch was a pattern-match-under-load reach for Talon because the surface "felt small."
- **Error 2 — incomplete pair dispatch under Rule 12.** Evelynn dispatched **Viktor** (complex builder) without first dispatching **Rakan** (complex test-impl, Viktor's pair-mate per Rule 12 xfail-first sequencing). Viktor's lane was correct in isolation; the failure was that the test-impl pair-mate's xfail commit had not landed on the branch first.

Lux's research memo (`assessments/research/2026-04-25-coordinator-routing-discipline.md`, commit `4b0ab6cf`) confirms the diagnosis and adds the upgrade: **Error 1 ≠ Error 2.** A single "is dispatched agent in the right lane" check catches Error 1 only — Viktor's lane was right; his solo dispatch was the problem. Any structural fix must address both shapes.

The taxonomy data is already first-class: every pair-mate-bearing agent def carries `tier:` / `pair_mate:` / `role_slot:` frontmatter, and plan files carry `owner:`. What is missing is the **glue lookup** ("plan owner `swain` ⇒ valid impl set `{viktor, rakan}`") and the **structural pause** that forces the coordinator to perform the lookup before reaching for the Agent tool.

# 2. Decision

Ship Lux's recommendation **D, sequenced** — A + B together as one Karma → Talon plan, pre-canonical-v1 lock. C (PreToolUse hook) is **deferred** to a separate plan after the canonical-v1 measurement window per Lux §2.3; this plan does not specify or scaffold it.

- **Artifact 1 (option A):** `architecture/agent-network-v1/routing.md` — one-page glance-scannable lookup keyed by upstream-plan-author lane → required impl-set. Rule-12 sequencing prose lives in §3 of the doc + the include's reasoning block (per Evelynn's OQ1 resolution: lean table, prose lives elsewhere).
- **Artifact 2 (option B):** `.claude/agents/_shared/coordinator-routing-check.md` — sibling to the existing `_shared/coordinator-intent-check.md` primitive, sourced via `<!-- include: -->` by Evelynn and Sona only (the two coordinators that dispatch). Encodes two structured pauses: a **Lane check** (Error 1 shape) and a **Pair-set completeness check** (Error 2 shape).

Pre-lock urgency: both files touch canonical-v1 surfaces (`_shared/*.md`, top-level `architecture/`); must promote, execute, and ship before retrospection-dashboard Phase 2 freezes the canon.

# 3. Artifact specs

## 3.1. `architecture/agent-network-v1/routing.md` (Artifact 1)

**Shape:** single-page reference, glance-scannable.

**Sections (in order):**

1. **§1. Purpose & when to use** — one paragraph: read this before any `Agent` dispatch where a plan path is in scope. Reference the include as the active gate; the doc is the lookup table.
2. **§2. Lane lookup table** — lean, two columns only:

   | Upstream plan `owner:` | Required impl-set |
   |---|---|
   | `swain` / `aphelios` / `xayah` | `{viktor, rakan}` (complex builder + complex test-impl) |
   | `azir` / `kayn` / `caitlyn` | `{jayce, vi}` (normal builder + normal test-impl) |
   | `karma` | `{talon}` (single quick-lane executor; no pair split) |
   | `neeko` | `{seraphine}` (complex frontend impl) |
   | `lulu` | `{soraka}` (normal frontend impl) |
   | `lux` | special case — see §4 |
   | `syndra` | special case — see §4 |
   | `heimerdinger` | `{ekko}` (single-lane DevOps execution) |

   No "Rule-12 sequence position" column (Evelynn OQ1: prose lives in §3).

3. **§3. Rule 12 sequencing — xfail-first** — short prose: for any complex/normal impl-set whose row includes a test-impl agent (`rakan` or `vi`), that agent's xfail commit MUST land on the target branch before the builder's first impl commit. Same branch, sequential commits — not parallel worktrees, not different branches. Cite Rule 12 in repo-root `CLAUDE.md` and the pre-push hook as enforcement.
4. **§4. Single-lane and self-dispatch exceptions** — Heimerdinger→Ekko, Senna+Lucian (PR review pair), Akali (QA pre-PR), Camille (advisory only), Orianna (gate, callable directly). **AI/MCP self-dispatch:** Lux- and Syndra-authored work frequently lands as direct edits by the author (this memo and many others); routing them as "self-dispatch impl" in §2 would mislead. Treated here as a special case rather than a row.
5. **§5. Dispatch checklist** — four yes/no questions, mirrored verbatim by the include's reasoning block:
   1. What is the upstream plan's `owner:`?
   2. Given that owner, what is the required impl-set?
   3. Is the agent I am about to dispatch in that set?
   4. If the set has a test-impl agent, has its xfail commit already landed on the target branch?
6. **§6. Rationale & references** — one-paragraph pointer to Lux's memo, the existing `coordinator-intent-check.md` primitive, and the pair-taxonomy plan.

**Rationale source:** `assessments/research/2026-04-25-coordinator-routing-discipline.md` is the canonical motivating memo; cite it inline in §1 and §6.

## 3.2. `.claude/agents/_shared/coordinator-routing-check.md` (Artifact 2)

**Shape:** mirrors `_shared/coordinator-intent-check.md` exactly — short markdown with section headers, internal-only block, not output to Duong, sourced by Evelynn + Sona only.

**Sections (in order):**

1. **Heading and scope line** — `# Coordinator routing primitive` + one-line "Sourced by: Evelynn, Sona." (mirrors intent-check's opening).
2. **`## Pre-dispatch routing block`** — the active gate. Before any `Agent` tool call where a plan path is cited or implied, emit a 4-line block internally:
   1. **Plan author** — what is the upstream plan's `owner:` field? (or "no plan; ad-hoc" — exempt)
   2. **Required impl-set** — given that owner, look up the row in `architecture/agent-network-v1/routing.md` §2. State the full set.
   3. **Lane check (Error 1 shape)** — is the agent I am about to dispatch in that impl-set? If no, **stop** — pick from the correct set.
   4. **Pair-set completeness check (Error 2 shape)** — does the impl-set include a test-impl pair-mate (`rakan` or `vi`)? If yes, has that pair-mate's xfail commit already landed on the target branch? If no, dispatch the test-impl pair-mate **first**.
3. **`## "This dispatch feels obvious" smell`** — pattern-match speed is not a license to skip the routing block. Mirrors the intent-check's "surgical is not a license" framing one floor up. Canonical failure mode: today's two errors (Talon-on-Swain-plan and Viktor-without-Rakan).
4. **`## Read-only / status-ping dispatches exempt`** — Skarner read-only excavation, Yuumi inbox FYI, Lissandra memory-consolidation. Anything `tier: quick` (Karma plans) or single-lane (Ekko, Senna, Lucian, Akali) **still requires the block** — those are exactly where Error 1 happened. No carve-out for "looks small."

**Sourced by:** Evelynn and Sona only. Subagents do not source it (they do not dispatch).

# 4. Tasks

T1. **xfail bats fixture asserting routing-check primitive is wired into both coordinator defs**
- kind: test
- estimate_minutes: 20
- files: `tests/agents/coordinator-routing-check-wired.bats` (new) <!-- orianna: ok -->
- detail: New bats file with two test cases. Case 1: `grep -F '<!-- include: _shared/coordinator-routing-check.md -->' .claude/agents/evelynn.md` returns 0. Case 2: same grep against `.claude/agents/sona.md` returns 0. Add a third case asserting the include file exists at `.claude/agents/_shared/coordinator-routing-check.md`. Add a fourth asserting `architecture/agent-network-v1/routing.md` exists and contains the literal heading `## 2. Lane lookup table` (or whatever §2 header T2 produces — Talon adjusts to match). Commit FIRST, expecting all four cases to fail (xfail per Rule 12). Use a `# bats test_tags=tag:routing-discipline` tag.
- DoD: file committed on the implementation branch as a failing test (xfail commit), referenced by plan slug; pre-push hook accepts the xfail commit.

T2. **Author the cheat-sheet doc** at `architecture/agent-network-v1/routing.md`.
- kind: docs
- estimate_minutes: 30
- files: `architecture/agent-network-v1/routing.md` (new) <!-- orianna: ok -->
- detail: Implement §3.1 spec above. Six sections in order. Lookup table is the lean two-column form (no Rule-12 column). §3 holds the Rule-12 prose. §4 covers Heimerdinger/Ekko, Senna+Lucian, Akali, Camille, Orianna, plus the Lux/Syndra self-dispatch special case. §5 is the four-question dispatch checklist. §6 cites Lux's memo, the intent-check primitive, and the pair-taxonomy plan.
- DoD: file exists; bats case 4 passes (header literal present); humans can scan in under 60 seconds.

T3. **Author the routing-check include** at `.claude/agents/_shared/coordinator-routing-check.md`.
- kind: docs
- estimate_minutes: 25
- files: `.claude/agents/_shared/coordinator-routing-check.md` (new) <!-- orianna: ok -->
- detail: Implement §3.2 spec above. Mirror `_shared/coordinator-intent-check.md` shape — short markdown, "Sourced by:" line, three sections (`## Pre-dispatch routing block`, `## "This dispatch feels obvious" smell`, `## Read-only / status-ping dispatches exempt`). The block is 4 lines (plan author / required impl-set / lane check / pair-set completeness check). State explicitly that the block is internal and not emitted to Duong.
- DoD: file exists; cross-reference to `architecture/agent-network-v1/routing.md` §2 lookup table is present; bats case 3 passes.

T4. **Wire the include into Evelynn's agent def.**
- kind: chore
- estimate_minutes: 5
- files: `.claude/agents/evelynn.md`
- detail: Add `<!-- include: _shared/coordinator-routing-check.md -->` adjacent to the existing `<!-- include: _shared/coordinator-intent-check.md -->` directive on line 34 (place immediately after, on its own line). Run `scripts/sync-shared-rules.sh` to expand the include into the rendered def. Verify the expansion contains the new primitive's section headers.
- DoD: bats case 1 passes; sync script exits 0; rendered def contains both `## Pre-dispatch routing block` and `## Intent block` section headers.

T5. **Wire the include into Sona's agent def.**
- kind: chore
- estimate_minutes: 5
- files: `.claude/agents/sona.md`
- detail: Same as T4 against Sona's def — add the `<!-- include: -->` directive next to the existing intent-check include on line 34, run `scripts/sync-shared-rules.sh`, verify expansion.
- DoD: bats case 2 passes; sync script exits 0; rendered def contains both section headers.

T6. **Run the full bats suite; confirm xfail cases now pass.**
- kind: test
- estimate_minutes: 10
- files: `tests/agents/coordinator-routing-check-wired.bats`
- detail: After T2-T5 land, the four bats cases authored in T1 should flip from failing (xfail) to passing. Remove any `# xfail` markers and re-run. If any case is still failing, fix the source artifact, not the test.
- DoD: `bats tests/agents/coordinator-routing-check-wired.bats` exits 0; all four cases green.

# 5. Test plan

**Invariants protected by the bats fixture (T1, T6):**

- **Wiring invariant:** Both coordinator defs (`evelynn.md`, `sona.md`) source `_shared/coordinator-routing-check.md` via the include directive. Drift here (someone deletes the include, or only Sona has it) is the primary regression risk — the include is useless if the def doesn't source it.
- **Existence invariant:** Both new files (`architecture/agent-network-v1/routing.md`, `.claude/agents/_shared/coordinator-routing-check.md`) exist on disk. Catches accidental deletion or path rename.
- **Content shape invariant:** `architecture/agent-network-v1/routing.md` contains the §2 lookup-table heading. This is a thin signal that the doc still has the table (a weak content check; a malformed table would still pass, but a missing-table refactor would not).

**Out of scope for the test:** the include's expanded content inside the rendered def. The include mechanism + sync script is already covered by existing tests for the intent-check include; this plan inherits that coverage.

**TDD sequence (Rule 12):** T1 commits first (xfail). T2-T5 produce the source artifacts. T6 confirms green. All on the same branch. No parallel worktrees.

# 6. Rollback

To revert this plan:

1. Delete `architecture/agent-network-v1/routing.md`.
2. Delete `.claude/agents/_shared/coordinator-routing-check.md`.
3. Remove the `<!-- include: _shared/coordinator-routing-check.md -->` line from `.claude/agents/evelynn.md` (originally added at line ~35) and `.claude/agents/sona.md` (same location).
4. Run `scripts/sync-shared-rules.sh` to re-render both defs without the include.
5. Delete `tests/agents/coordinator-routing-check-wired.bats`.
6. Commit as `chore: rollback coordinator-routing-discipline plan` and push.

No data migration, no hook changes, no schema changes — pure additive surface, fully reversible.

# 7. Out of scope

- **PreToolUse hook (Lux's option C).** Deferred per Lux §2.3 to a follow-up plan after the canonical-v1 measurement window. This plan does **not** scaffold, prototype, or specify the hook. If A+B prove insufficient over the canonical-v1 retro window, a separate plan introduces it then.
- **Backfilling other coordinators.** Only Evelynn and Sona dispatch — no other agent defs receive the include.
- **Frontmatter changes to existing agent defs or plans.** The taxonomy is already first-class; this plan is glue only.

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has a clear owner (karma), concrete artifact specs with section-by-section detail, six well-scoped tasks with explicit DoD criteria, and Rule-12 xfail-first sequencing baked into T1/T6. Test plan names invariants (wiring, existence, content shape). Rollback is enumerated step-by-step and reversible. Out-of-scope explicitly defers Lux's option C hook to a post-retro follow-up — disciplined scope. No unresolved TBDs in gating sections.
