---
title: Agent pair taxonomy — complex / normal two-track roster
status: proposed
owner: swain
date: 2026-04-20
created: 2026-04-20
tags: [taxonomy, roster, pairing, governance]
---

# Context

The plan lifecycle ADR (`plans/proposed/2026-04-20-orianna-gated-plan-lifecycle.md`) gates each phase transition on a **role** — architect, breakdown, test plan, test impl, feature build, frontend, DevOps, review, AI-specialist. Today the roster has one agent per role regardless of the task's complexity. That's the wrong default.

**Symptoms today:**

- **Under-powered architecture.** Azir is the only architect, running at Opus-high. For a trivial schema tweak this is fine; for a cross-cutting lifecycle overhaul (the Orianna ADR, the portfolio-currency ADR) it's thin. Swain has existed informally for exactly these — but only via Duong's ad-hoc "hey Swain" invocation, never as a routable role.
- **Ad-hoc test authoring.** Caitlyn writes test plans, Vi executes. When a plan needs a serious test strategy (resiliency, fault injection, multi-service fixtures), Caitlyn at Opus-medium is below what's needed. There's no second tier to escalate to, and no separate agent for writing xfail test skeletons before impl.
- **Feature-building role confusion.** Viktor is labeled "refactoring agent" but the roster uses him as a generic Sonnet builder half the time. Meanwhile refactor-vs-feature is a task type, not a personality — every feature commit touches existing code. The agent-identity split is misaligned with how work actually flows.
- **Design lane has no normal track.** Lulu/Neeko → Seraphine handles design, but for a one-off "add a tooltip" task there's no lightweight path; Neeko is Opus-high. Designers tune for serious UI work and can't be efficient on trivial tweaks.
- **AI/agents specialist overloaded.** Lux covers Claude API + MCP + agent architecture + prompt engineering + agent-definition organization. That's 5 different things at one agent. Lux's model (Opus-medium) is wrong for heavy MCP design work and overkill for "rename this agent definition."

The Orianna ADR names agents by role (`the task breakdown agent`, `the feature builder`) — but that phrasing only works if the role has a single fill. Once we introduce tiers, the ADR needs to resolve "which fill" through a separate taxonomy layer. That layer is this ADR.

**This ADR defines:**

1. A two-track pairing model — complex vs normal — for each role slot.
2. Four new agents to fill the normal-track and test-authoring gaps: Xayah, Rakan, Soraka, Syndra.
3. Rescopes of Lux (narrowed to AI-specialist + agent-def org) and Viktor (from refactor to complex-track feature builder).
4. A shared-rules include pattern so pair-mates share behavior without duplicating the rule text in two definition files.
5. Complexity-classification heuristics Evelynn uses to pick a track.

---

# Decisions

## D1. The pair matrix

Every role slot gets two fills — a **complex** track and a **normal** track — *except* the three single-lane roles where a split would add coordination cost without benefit (see §D1.3).

| # | Role | Complex (higher effort) | Normal (lower effort) |
|---|------|------------------------|-----------------------|
| 1 | Architect (ADR) | **Swain** — Opus xhigh | **Azir** — Opus high |
| 2 | Task breakdown | **Aphelios** — Opus high | **Kayn** — Opus medium |
| 3 | Test plan / audit | **Xayah** *new* — Opus high | **Caitlyn** — Opus medium |
| 4 | Test implementation | **Rakan** *new* — Opus low | **Vi** — Sonnet medium |
| 5 | Feature builder | **Viktor** *rescoped* — Sonnet medium | **Jayce** — Sonnet low |
| 6 | Frontend design → impl | **Neeko → Seraphine** (Opus high → Sonnet medium) | **Lulu → Soraka** *new* (Opus low → Sonnet low) |
| 7 | DevOps advice → exec | **Heimerdinger → Ekko** (single lane — no split) | — |
| 8 | PR review | **Senna (code) + Lucian (fidelity)** (single lane — no split) | — |
| 9 | AI/Agents/MCP specialist | **Lux** *rescoped* — Opus high | **Syndra** *new* — Sonnet low |

Notes on the matrix:

- **Row 1, Swain rescope.** Swain's `effort` bumps from `high` to `xhigh`. He's invoked for cross-cutting structural decisions — lifecycle gates, schema propagation, multi-service architecture — where deep reasoning time is worth the cost. Azir remains head product architect for normal-track ADRs (new features, standard API design).
- **Row 2, Aphelios promoted to complex.** He already pairs with Kayn informally on large plans; this formalizes him as the Opus-high breakdown agent for any task Swain authors or any plan Evelynn classifies as complex. Kayn stays at Opus-medium for normal-track breakdowns.
- **Row 3, Xayah new.** Test-planning for resilient/distributed work needs more capacity than Caitlyn at Opus-medium. Xayah takes the complex lane.
- **Row 4, Rakan new at Opus-low.** Test implementation is the unusual slot where complex-track uses a *cheaper* model than normal-track. Rationale: complex test work means authoring xfail skeletons, fault-injection fixtures, and trace-capture harnesses — tasks that need careful reasoning (Opus) but low token count (low effort). Vi stays Sonnet-medium for bulk test execution where the work is high-volume.
- **Row 5, Viktor rescoped.** Viktor is no longer "refactor specialist." Refactor is a *task type*, not an identity — every feature builder refactors as part of their work. Viktor becomes the complex-track builder for invasive features, migrations, or cross-module work. Jayce stays as normal-track builder for greenfield and additive work.
- **Row 6, split pair.** Each side has its own designer + implementer. Complex-track keeps the existing Neeko → Seraphine handoff. Normal-track introduces Soraka as the light-weight frontend implementer; Lulu (Opus-low) provides design guidance inline without full artifact production.
- **Rows 7 & 8, single-lane.** Heimerdinger → Ekko and Senna + Lucian stay single-lane; see §D1.3.
- **Row 9, Lux rescoped + Syndra new.** Lux becomes the AI/MCP/agent-definition-organization specialist. Syndra is the normal-track counterpart for small AI tweaks (change a prompt, adjust an agent's effort level, add a tool to a definition).

### D1.1. Effort levels and model choices

`model:` + `effort:` frontmatter on each agent definition, already an established pattern (see e.g. `.claude/agents/azir.md` — `model: opus`, `effort: high`).

Canonical effort tags: `low | medium | high | xhigh`. Only Swain uses `xhigh` for now; introduce the value in his frontmatter and let the harness treat unknown values as `high` equivalent until tooling catches up (implementation follow-up).

### D1.2. Why two tiers not three

A three-tier split (light / normal / heavy) was considered and rejected. Reasoning: with ~9 role slots × 3 tiers the roster grows to ~25 active agents; the coordination overhead (which tier? which pair-mate? which shared-rules file?) dominates the savings. Two tiers — complex, normal — capture the important axis (is this task worth Opus-high thinking time) without exploding the surface.

When in doubt, Evelynn picks **normal**. See §D6 for classification rules.

### D1.3. Single-lane roles — rationale

Three role slots stay single-lane (no complex/normal split):

- **DevOps advice → exec (Heimerdinger → Ekko).** DevOps tasks are infrastructure-shaped. The "complex" case in DevOps isn't about reasoning depth, it's about blast radius. Heimerdinger already escalates to Duong for high-blast-radius changes; a second Opus-high DevOps agent would duplicate without differentiating. Ekko's execution tier is sufficient for both small and large DevOps changes because the execution part is mechanical once the plan is clear.
- **PR review (Senna + Lucian).** PR review is a *pair* of concerns — code-quality+security (Senna) and plan/ADR fidelity (Lucian) — applied to every PR. The work already partitions by concern, not by complexity. Adding a complex/normal split per reviewer would mean 4 reviewers per PR, which is coordination overhead with no signal gain.
- **Implicit: Evelynn herself.** Head coordinator is unsharded by design.

These three are called out in this ADR so they don't look like oversights in the taxonomy. Any future split for them is scoped separately (see §D9).

---

## D2. New agents to create

Four new agent definitions. Each follows the shared-rules pattern in §D3.

### D2.1. Xayah — Opus-high, complex-track test planner

- **Role slot:** Test plan / audit (complex).
- **Tier:** complex.
- **Model/effort:** `model: opus`, `effort: high`.
- **Pair mate:** Caitlyn (normal-track).
- **One-line:** Writes resilience/fault-injection/cross-service test plans and audits for complex-track ADRs; hands off authoring to Rakan and bulk execution to Vi.
- **Invocation trigger:** Any plan Evelynn has routed to Swain for architecture or Aphelios for breakdown; any plan touching distributed-system invariants, persistence-sync, or cross-agent messaging.

### D2.2. Rakan — Opus-low, complex-track test implementer

- **Role slot:** Test implementation (complex).
- **Tier:** complex.
- **Model/effort:** `model: opus`, `effort: low`.
- **Pair mate:** Vi (normal-track).
- **One-line:** Authors xfail test skeletons, fault-injection harnesses, and non-routine test fixtures from Xayah's plans; passes the test plan to Vi for bulk run/iterate.
- **Note on tier-model-effort interaction:** Rakan is the one "complex tier at low effort" slot in the matrix. See §D1 matrix notes for rationale. Opus-low gives careful reasoning on small-token tasks at ~1/3 the cost of Opus-medium.

### D2.3. Soraka — Sonnet-low, normal-track frontend implementer

- **Role slot:** Frontend implementation (normal).
- **Tier:** normal.
- **Model/effort:** `model: sonnet`, `effort: low`.
- **Pair mate:** Seraphine (complex-track).
- **One-line:** Implements small frontend tweaks — a tooltip, a copy change, a simple component variant — from Lulu's inline advice; escalates to Seraphine when Neeko-scale design artifacts are needed.
- **Invocation trigger:** Trivial frontend tasks where producing a full Neeko design spec would be ceremony.

### D2.4. Syndra — Sonnet-low, normal-track AI/agents specialist

- **Role slot:** AI/Agents/MCP (normal).
- **Tier:** normal.
- **Model/effort:** `model: sonnet`, `effort: low`.
- **Pair mate:** Lux (complex-track).
- **One-line:** Handles small AI-stack tweaks — adjusting a prompt, tuning an agent's `effort:` value, adding a tool to a definition, renaming roster entries — where a full Lux research pass is overkill.
- **Invocation trigger:** Single-file or few-line changes to `.claude/agents/*.md`, `agents/*/profile.md`, or MCP config. Not for new MCP tools (that's Lux) or major agent redesigns (that's Lux + Swain).

---

## D3. Rescopes of existing agents

### D3.1. Lux — narrowed scope

Lux today covers Claude API + MCP + agent architecture + prompt engineering + agent-definition organization. New scope: **AI/Agents/MCP specialist + agent-definition organization**. Agent-definition organization is the explicit addition — historically this has drifted across Swain, Evelynn, and Lux without a clear owner; Lux gets it because he already holds domain knowledge about how agents are structured in this system.

Frontmatter update: `effort: medium` → `effort: high`. Lux is the complex-track counterpart to Syndra, and his work (MCP server design, prompt optimization, agent-topology changes) justifies Opus-high.

Description update: add "owns the shape of `.claude/agents/*.md` and the shared-rules include pattern (§D4)."

### D3.2. Viktor — rescoped to complex-track builder

Today: "Refactoring agent — code restructuring, optimization, cleanup, migrations." New: "Complex-track feature builder — invasive features, migrations, cross-module work, and refactor-as-part-of-build. Paired with Jayce (normal-track)."

Rationale captured in §D1 matrix note (row 5): refactor is a task type, not an identity. Every builder refactors; labeling one agent "refactor only" forced awkward routing decisions whenever a feature touched existing code (which is always).

Viktor's model stays `sonnet`; his `effort` bumps from `medium` to `medium` (unchanged — the complex-track tier is already at Sonnet-medium per the matrix). The rescope is the *description and boundary text*, not the model.

Description update: drop "No new features or greenfield work (that's Jayce)" — this boundary no longer holds. Replace with "Viktor handles complex-track builds (migrations, multi-module features, invasive refactors). Jayce handles normal-track builds (greenfield, additive, single-module). Refactor is a task-shape both agents do as needed."

### D3.3. Swain — effort bump

Swain's `effort:` goes from `high` to `xhigh`. No description change; the role (cross-cutting system architect) is unchanged. The bump formalizes "when Duong invokes Swain, he's paying for the deeper reasoning tier."

---

## D4. Shared-rules include pattern

**Decision:** Each pair-mate gets a separate agent definition file. Rules that are identical between pair-mates live in a shared include file under `.claude/agents/_shared/<role>.md`. Each agent definition references its shared file and only differs by: `model`, `effort`, `tier`, `pair_mate`, invocation description.

### D4.1. Directory layout

```
.claude/agents/
  _shared/
    architect.md           # shared rules for Swain + Azir
    breakdown.md           # shared for Aphelios + Kayn
    test-plan.md           # shared for Xayah + Caitlyn
    test-impl.md           # shared for Rakan + Vi
    builder.md             # shared for Viktor + Jayce
    frontend-design.md     # shared for Neeko + Lulu
    frontend-impl.md       # shared for Seraphine + Soraka
    ai-specialist.md       # shared for Lux + Syndra
  azir.md
  swain.md
  aphelios.md
  ...
```

Single-lane roles (Heimerdinger, Ekko, Senna, Lucian, Evelynn) do not get shared files — their rules stay inline in the single agent definition.

### D4.2. What goes in shared vs per-agent

**Shared file (`_shared/<role>.md`) contains:**

- The role's principles (what this role values — e.g. "architect: design for next 2 years, not 2 weeks").
- The role's boundaries (what this role does not do — e.g. "architect: never self-implement").
- The role's process (how this role works — e.g. "architect: understand → research → design → write spec → hand off").
- The role's strawberry rules (the subset of universal invariants relevant to this role — commit prefixes, worktree usage, etc.).
- The role's closeout protocol (what to write at session end).

**Per-agent file contains:**

- `model:`, `effort:` frontmatter.
- `tier: complex | normal` frontmatter.
- `pair_mate: <name>` frontmatter.
- `name:` and `description:` frontmatter — identity.
- An include directive: `<!-- include: _shared/<role>.md -->`.
- A short "About <name>" section with personality/tone — the League of Legends champion voice Duong prefers, which differentiates complex from normal ("Swain is the tactician; Azir is the empire-builder") without changing the underlying rules.
- Any tier-specific invocation guidance (when to invoke complex vs normal — but this also lives in the delegation table in `agents/evelynn/CLAUDE.md`, §D5).
- Startup sequence (which is identical in structure but references agent-specific paths — these stay per-agent because paths differ by name).

### D4.3. Include mechanism — plain-text inclusion via a tiny preprocessor

Claude Code does not natively process `<!-- include: ... -->` directives in agent definitions. The mechanism is:

1. The include comment is a **human marker** — it tells readers where the shared content logically lives.
2. On definition load, a pre-commit hook (new: `scripts/hooks/pre-commit-agent-shared-rules.sh`) verifies that each agent's file contains the literal text of its shared rules — i.e. the shared content is **inlined physically** into each agent definition, but the source of truth is the shared file.
3. A helper script `scripts/sync-shared-rules.sh` re-inlines from `_shared/<role>.md` into each pair-mate's definition, preserving the per-agent header (frontmatter + "About" section) and rewriting everything below the include marker.
4. The hook blocks commits where a per-agent file's inlined shared content has drifted from the canonical `_shared/<role>.md` — forcing agents or humans to re-run `sync-shared-rules.sh`.

**Why inline-with-sync, not a true include:** Claude Code's subagent loader reads a single `.md` file into context; it does not chase `<!-- include: -->` comments. So we need the content to physically live in each agent's file at invocation time. The sync script + hook gives us shared-source-of-truth without requiring loader changes.

Alternative considered: a build step that generates `.claude/agents/*.md` from `_shared/` + per-agent stubs. Rejected because (a) generated files in `.claude/agents/` fight the human-editability of agent definitions and (b) the drift detection is identical either way.

### D4.4. Migration — existing single-lane roles are unaffected

Heimerdinger, Ekko, Senna, Lucian, Evelynn, Yuumi, Skarner, Akali, Orianna keep their existing monolithic definitions. They get no `_shared/` file. The shared-rules pattern only applies where there are two pair-mates to share between.

---

## D5. Pair-mate cross-reference in each definition

Every paired agent definition carries this in frontmatter:

```yaml
tier: complex        # or normal
pair_mate: azir      # the opposite-tier agent for this role slot
role_slot: architect # canonical slot name (matches _shared/<role>.md basename)
```

**Why:** Evelynn's delegation logic (and future auto-routing scripts) need to resolve "complex-track architect" → Swain, "normal-track architect" → Azir without hard-coding pairs at the caller. The frontmatter lets any tool walk the roster, group by `role_slot`, and key by `tier`. `pair_mate` is redundant with "scan for same `role_slot` opposite `tier`" but saves the scan at invocation time and makes the pairing visible when reading one file in isolation.

Canonical `role_slot` values (match §D4.1 directory names): `architect | breakdown | test-plan | test-impl | builder | frontend-design | frontend-impl | ai-specialist`. Single-lane agents omit these fields or use `tier: single_lane` with `pair_mate: null`.

---

## D6. Task-complexity classification

Evelynn (or whoever is delegating) decides complex-vs-normal via these heuristics. No single heuristic is dispositive; if any two fire, go complex.

**Complex indicators:**

1. **Estimated AI-minutes total > 180** across the whole plan's task list. Large plans usually have high blast-radius, and Opus-high/xhigh agents save round-trips on ambiguity.
2. **Number of tasks in breakdown > 10.** A plan with many tasks implies cross-cutting impact or non-trivial decomposition.
3. **Cross-cutting impact.** The plan modifies two or more top-level domains (e.g. `scripts/` + `.claude/agents/` + `architecture/`), or changes CLAUDE.md, or changes a universal invariant, or changes lifecycle.
4. **Invasive schema changes.** Data model alterations that propagate through UI rendering, persistence, serialization, or signed artifacts (cf. the portfolio-currency ADR which triggered schema propagation through `§3/§4/§8`).
5. **New external system integrations.** First-time MCP server wiring, new API client, new provider, new auth flow.
6. **Plan governance meta-work.** Plans that change the plan lifecycle itself (the Orianna ADR; this ADR) are always complex because they are cross-cutting by definition.

**Normal indicators (all must hold to default to normal):**

- AI-minutes total ≤ 180.
- Tasks ≤ 10.
- Single top-level domain touched.
- No schema propagation needed.
- No new external integrations.

**Default lean:** When exactly one complex indicator fires and the rest look normal, go **normal**. The cost of normal-track work is lower, and Evelynn can escalate mid-plan by rerouting the next unstarted phase to complex if normal-track agents hit a wall. Re-routing upward is cheap; routing a complex-track plan downward is wasted Opus budget.

### D6.1. Complexity declaration in the plan

Plans authored under the new taxonomy SHOULD include a frontmatter field:

```yaml
complexity: complex    # or normal
```

This is informational — it records the classification made at authoring time, so agents picking up the plan mid-lifecycle know which track they're on. Evelynn sets this when she commissions the plan; the architect (Swain or Azir) preserves it. Missing field defaults to `normal`.

Formal enforcement of the complexity field is **out of scope for this ADR**. A future follow-up can require it in Orianna's `proposed → approved` gate, but we don't extend the Orianna ADR here.

---

## D7. Routing updates — `agents/evelynn/CLAUDE.md`

The current delegation table in `agents/evelynn/CLAUDE.md` (lines 87–109) maps one work-type to one agent. The new table adds a tier column. Example rows for the refactored table:

| Work type | Complex agent | Normal agent |
|-----------|---------------|--------------|
| System architecture, ADR plans | **Swain** (Opus xhigh) | **Azir** (Opus high) |
| Backend task breakdown from ADR | **Aphelios** (Opus high) | **Kayn** (Opus medium) |
| QA audit and testing strategy | **Xayah** (Opus high) | **Caitlyn** (Opus medium) |
| Writing and running tests | **Rakan** (Opus low) | **Vi** (Sonnet medium) |
| Feature build | **Viktor** (Sonnet medium) | **Jayce** (Sonnet low) |
| Frontend (design → impl) | **Neeko → Seraphine** | **Lulu → Soraka** |
| AI/Agents/MCP advice | **Lux** (Opus high) | **Syndra** (Sonnet low) |
| Quick fixes, DevOps execution | **Ekko** (single-lane) | — |
| DevOps advice | **Heimerdinger** (single-lane) | — |
| PR code + security review | **Senna** (single-lane) | — |
| PR plan/ADR fidelity review | **Lucian** (single-lane) | — |
| Memory retrieval | **Skarner** (single-lane) | — |
| Light errands | **Yuumi** (single-lane) | — |
| Fact-check | **Orianna** (single-lane) | — |
| QA Playwright + Figma diff | **Akali** (single-lane) | — |

**Additional updates Evelynn's CLAUDE.md needs:**

1. A new section "Classifying task complexity" linking to §D6 of this ADR.
2. The default-lean rule from §D6: when uncertain, normal.
3. Update `<!-- #rule-prefer-roster-agents -->` to list the new roster entries.
4. Update the `<!-- #rule-plan-gate -->` planner list to include Swain and Xayah (both Opus planners that write plans under their respective tiers).

---

## D8. Migration plan

**Phased, no big-bang.**

### D8.1. Phase A — additions, no behavioral change

1. Create `_shared/` directory and the 8 shared rule files (§D4.1). Content = factor out existing per-agent rule text where pair-mates already exist (Azir, Kayn, Caitlyn, Vi, Jayce, Seraphine).
2. Create agent definitions for Xayah, Rakan, Soraka, Syndra. Each stubbed with shared rules inlined per §D4.3.
3. Add `sync-shared-rules.sh` and `pre-commit-agent-shared-rules.sh`.
4. Update `agents-table.md` and `agent-network.md` to list the new agents as `new-2026-04-xx`.

Phase A leaves existing routing intact — Evelynn keeps using the current delegation table. New agents are in the roster but not yet invoked.

### D8.2. Phase B — rescopes

5. Rescope Lux definition per §D3.1 (narrowed scope, effort bump, description update).
6. Rescope Viktor definition per §D3.2 (drop "refactor only" boundary, add complex-track language).
7. Bump Swain's `effort:` to `xhigh` per §D3.3.
8. Update `agents/memory/agent-network.md` delegation chain to include tier-aware language where relevant (e.g. "Duong → Evelynn → Swain/Azir (architecture by complexity)").

### D8.3. Phase C — routing table swap

9. Update `agents/evelynn/CLAUDE.md` delegation table per §D7.
10. Add the "Classifying task complexity" section.
11. From here on, Evelynn routes by tier using the heuristics in §D6.

### D8.4. Phase D — optional enforcement

12. Add `complexity:` frontmatter field to the Orianna `proposed → approved` gate as a warning-first, block-later (a follow-up ADR, not this one).

Phases A–C are sequential but each is a single small commit set. Phase D is deferred.

### D8.5. What stays the same

- Existing agent definitions for Jayce/Viktor/Vi/Caitlyn/Seraphine/Neeko/Lulu/Kayn/Azir remain in place on disk (same paths). Rescopes are content edits, not file moves or deletions.
- Single-lane agent definitions (Heimerdinger, Ekko, Senna, Lucian, Evelynn, Yuumi, Skarner, Akali, Orianna) are not touched by this ADR.
- The plan lifecycle ADR's role references resolve through §D1 once this lands. No changes to that ADR's content — only the name-decoupling revision (see companion ADR).

---

## D9. Out of scope

- **Senna/Lucian split.** Review concerns already partition by type (code vs fidelity); a complexity split on top would be 4 reviewers per PR. Defer indefinitely.
- **DevOps split.** Heimerdinger → Ekko works as single-lane for both small and large DevOps changes. Splitting would duplicate without differentiating. Defer indefinitely.
- **Further reviewer pairs.** No additional reviewer roles introduced. Senna + Lucian remain the PR review set.
- **Akali split.** QA (Playwright + Figma diff) stays single-lane for the same reason as DevOps — task shape doesn't partition by complexity.
- **Orianna split.** Fact-checker is single-lane by design; signature authority is a property of agent identity (§D1.1 of the lifecycle ADR), and splitting the identity would break that property.
- **Implementing the `_shared/` mechanism.** This ADR specifies it; actual script + hook implementation is a follow-up task breakdown.
- **Tier-aware automation for the Orianna gate.** The `complexity:` frontmatter field's enforcement is deferred (§D8.4).

---

# Open gating questions

1. **Q1. Xhigh effort tag.** Swain gets `effort: xhigh`. Does the Claude Code harness accept values outside `low | medium | high`? If not, this either degrades silently to `high` (safe but then the tier distinction is documentation-only for Swain vs Azir) or we need a different signal (e.g. a custom frontmatter field the harness ignores but our tooling reads). Leaning: degrade silently for now; revisit if an actual model-budget difference is needed.

2. **Q2. Shared-rules sync scope — hook or CI?** §D4.3 specifies a pre-commit hook for drift detection. Alternative: CI-only check via a GitHub Actions workflow. Hook is faster feedback but another hook to install; CI is slower but matches the existing enforcement style for larger governance rules (e.g. the TDD gate workflow). Leaning: hook, because `.claude/agents/*.md` edits are frequent and CI round-trips would slow iteration.

3. **Q3. Default-lean wording — "normal" as literal name.** §D6 defaults to "normal" when uncertain. Is "normal" the right label vs alternatives like "standard" or "default"? "Normal" pairs linguistically with "complex"; "standard" pairs better with "premium." Leaning: stick with "normal" — the pairing "complex / normal" is already used in Duong's task briefing and has clearer semantics (complex = exceptional, normal = the rest).

4. **Q4. Pair-mate field validation.** §D5 puts `pair_mate:` in frontmatter. Should the pre-commit hook validate that `pair_mate:` is symmetric (if A's pair is B, then B's pair is A)? Leaning: yes, add to the same `pre-commit-agent-shared-rules.sh` hook — cheap check, catches one class of drift.

5. **Q5. Rakan's unusual tier-model combo.** Rakan is complex-tier at Opus-low (§D2.2). This is the only place in the matrix where complex-tier uses a lower effort than normal-tier (Vi is Sonnet-medium — higher model-adjusted cost than Opus-low in most scenarios, though the comparison depends on the token profile). Is this combination confusing for Evelynn's routing? Alternative: bump Rakan to Opus-medium. Leaning: keep Opus-low with a note in Evelynn's delegation table explaining the carefully-reasoning-but-small-tokens shape.

6. **Q6. Soraka vs "just use Seraphine."** Is there enough normal-track frontend work to justify Soraka as a separate agent, given Seraphine already handles Sonnet-medium frontend implementation? An alternative is to skip Soraka entirely and have Lulu → Seraphine handle both tiers. Leaning: create Soraka; Lulu's Opus-low budget pairs well with Sonnet-low implementer, and keeping the frontend pair structurally identical to other paired roles (design + impl in both tiers) makes the roster learnable. But if rollout is phased (§D8), Soraka can go in the Phase A batch and be activated later if real usage emerges.

7. **Q7. Viktor rescope collisions with in-flight plans.** Any plans currently in `plans/in-progress/` that specified Viktor as the "refactor-only agent" will now read ambiguously after the rescope. Do we revise in-flight plans? Leaning: no — in-flight plans finish under grandfathered semantics (same as the Orianna ADR's grandfathering rule); only new plans (post-Phase B) use the new Viktor scope.

---
