---
title: Agent pair taxonomy — complex / normal two-track roster
status: in-progress
owner: swain
date: 2026-04-20
created: 2026-04-20
tags: [taxonomy, roster, pairing, governance]
---

# Context

The plan lifecycle ADR (`plans/approved/2026-04-20-orianna-gated-plan-lifecycle.md`) gates each phase transition on a **role** — architect, breakdown, test plan, test impl, feature build, frontend, DevOps, review, AI-specialist. Today the roster has one agent per role regardless of the task's complexity. That's the wrong default.

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

Every role slot gets two fills — a **complex** track and a **normal** track — *except* the single-lane roles where a split would add coordination cost without benefit (see §D1.3). Coordinators (Evelynn, Sona) are a separate row at the top of the table: they are not sharded by complexity — there is one per concern (personal vs work) and they *are* the pair.

**Canonical rule: never Opus-low.** Per Lux's cost-quality research (§D1.6), Opus-low is the worst `$/quality` point on the frontier: it pays Opus token rates for under-reasoned output. Every roster slot was retiered against that rule; the table below is the result.

| # | Role slot | Complex (higher effort) | Normal (lower effort) |
|---|-----------|------------------------|-----------------------|
| 0 | Coordinator | **Evelynn** — Opus medium, `concern: personal` | **Sona** — Opus medium, `concern: work` |
| 1 | Architect (ADR) | **Swain** — Opus xhigh | **Azir** — Opus high |
| 2 | Task breakdown | **Aphelios** — Opus high | **Kayn** — Opus medium |
| 3 | Test plan / audit | **Xayah** *new* — Opus high | **Caitlyn** — Opus medium |
| 4 | Test implementation | **Rakan** *new* — Sonnet high *(was Opus low)* | **Vi** — Sonnet medium |
| 5 | Feature builder | **Viktor** *rescoped* — Sonnet high *(bumped from medium)* | **Jayce** — Sonnet medium *(bumped from low)* |
| 6 | Frontend design | **Neeko** — Opus high | **Lulu** — Opus medium *(was Opus low)* |
| 7 | Frontend impl | **Seraphine** — Sonnet medium | **Soraka** *new* — Sonnet low |
| 8 | AI/Agents/MCP specialist | **Lux** *rescoped* — Opus high | **Syndra** *new* — Sonnet high *(was Opus low)* |
| 9 | DevOps advice | **Heimerdinger** — Opus medium *(single-lane)* | — |
| 10 | DevOps exec | **Ekko** — Sonnet medium *(single-lane)* | — |
| 11 | PR code/security | **Senna** — Opus high *(single-lane)* | — |
| 12 | PR plan fidelity | **Lucian** — Opus medium *(single-lane)* | — |
| 13 | Fact-check / signer | **Orianna** — Opus medium *(single-lane)* | — |
| 14 | QA Playwright | **Akali** — Sonnet medium *(single-lane)* | — |
| 15 | Memory excavator | **Skarner** — Sonnet low *(single-lane)* | — |
| 16 | Errand runner | **Yuumi** — Sonnet low *(single-lane)* | — |
| 17 | Git/security advisor | **Camille** — Opus medium *(single-lane)* | — |

Notes on the matrix:

- **Row 0, Coordinators.** Evelynn (personal) and Sona (work) are the only two coordinators in the Strawberry system; they are not complex/normal pair-mates but **concern-pair-mates** (one per life domain). Both run Opus-medium — below the architect tier because coordinators route rather than reason deeply. Coordinators do NOT carry `tier:` or `pair_mate:` frontmatter — instead they carry a new `concern: personal | work` field (see §D1.1). No shared-rules file is generated for coordinators (coordinator rules live inline in `agents/<name>/CLAUDE.md`), and the pair-mate symmetry check (§D4.3a check #2) explicitly skips any agent without `pair_mate:` — coordinators are exempt by virtue of having no such field. Sona's agent definition (`.claude/agents/sona.md`) becomes tracked as part of this ADR's implementation — she's a first-class coordinator, not provisional (Q8 resolution).
- **Row 1, Swain rescope.** Swain's `effort` bumps from `high` to `xhigh`. He's invoked for cross-cutting structural decisions — lifecycle gates, schema propagation, multi-service architecture — where deep reasoning time is worth the cost. Azir remains head product architect for normal-track ADRs (new features, standard API design).
- **Row 2, Aphelios promoted to complex.** He already pairs with Kayn informally on large plans; this formalizes him as the Opus-high breakdown agent for any task Swain authors or any plan Evelynn classifies as complex. Kayn stays at Opus-medium for normal-track breakdowns.
- **Row 3, Xayah new.** Test-planning for resilient/distributed work needs more capacity than Caitlyn at Opus-medium. Xayah takes the complex lane.
- **Row 4, Rakan retiered to Sonnet-high.** Previously scoped as Opus-low in the original matrix — retiered per the never-Opus-low rule. Sonnet-high gives strong reasoning on test-skeleton authoring (xfail tests, fault-injection harnesses, trace-capture fixtures) at a substantially better `$/quality` point than Opus-low. Vi stays Sonnet-medium for bulk test execution where the work is high-volume.
- **Row 5, Viktor + Jayce both bumped.** Viktor (complex-track builder) goes Sonnet-medium → Sonnet-high: invasive features and migrations benefit from higher-effort builds where ambiguity is highest. Jayce (normal-track builder) goes Sonnet-low → Sonnet-medium: the original Sonnet-low was under-powered for real feature work; Sonnet-medium is the common-case builder tier.
- **Row 6–7, frontend pair split into two rows.** Design and implementation are separate concerns; each has its own complex/normal split. Neeko (Opus-high) designs for complex UI work; Lulu (Opus-medium, retiered from the original Opus-low per the never-Opus-low rule) designs for normal UI work. Seraphine (Sonnet-medium) implements complex designs; Soraka (Sonnet-low) implements light tweaks. This makes four distinct agents in the frontend lane, which is correct because design and impl have independent tier needs.
- **Row 8, Lux + Syndra.** Lux becomes the AI/MCP/agent-definition-organization specialist at Opus-high. Syndra retiered to Sonnet-high (was Opus-low) — small AI tweaks still deserve careful reasoning on prompt/agent-def work, and Sonnet-high is the right `$/quality` point. See §D3.1 for Lux's scope.
- **Rows 9–17, single-lane.** Each single-lane agent gets an explicit row (rather than being bundled). Heimerdinger (Opus-medium advice) → Ekko (Sonnet-medium exec) is a two-row single-lane pipeline, not a complex/normal split. Senna (Opus-high — security review is worth the top tier) and Lucian (Opus-medium — fidelity review is lighter) are the PR reviewer pair, one row each since they review different concerns, not different complexity levels. Orianna (Opus-medium — signer authority matches coordinator tier). Akali (Sonnet-medium Playwright). Skarner/Yuumi (Sonnet-low minions — stateless, no self-close). Camille (Opus-medium git/security advisor).

### D1.1. Effort levels and model choices

`model:` + `effort:` frontmatter on each agent definition, already an established pattern (see e.g. `.claude/agents/azir.md` — `model: opus`, `effort: high`).

Canonical effort tags: `low | medium | high | xhigh`. Swain is the only agent using `xhigh` today; Q1 confirmed the harness accepts the value (runtime treats `xhigh` as a legitimate budget level). New values degrade silently to `high` if tooling lags — but the `xhigh` case is validated.

### D1.1a. Model frontmatter convention — omit Opus, declare Sonnet explicitly

Claude Code's global default model is **Opus 4.7 (1M context)** (confirmed: no `"model"` field in `~/.claude/settings.json`; the harness inherits the latest Opus 4.7 1M on every spawn). This has several consequences for agent definitions:

- **Opus agents: omit `model:` from frontmatter.** They inherit the session default, which keeps them on whatever the current Opus tier is without a pin. Pinning a specific ID (e.g. `model: opus-4-7`) creates drift debt the day a newer Opus lands. Leaving the field off means Opus agents auto-upgrade. On Opus 4.7, **adaptive thinking is the only mode** — it is automatic and non-configurable at the model level; the `effort:` dial is how you tune its intensity.
- **Sonnet agents: declare `model: sonnet` explicitly.** The alias `sonnet` resolves to **Sonnet 4.6** (never a pinned ID like `sonnet-4-5` or `sonnet-4-6`) and locks the agent to the Sonnet tier. Without the field, a Sonnet agent would silently promote to Opus on spawn — a 5× burn (see §D1.6) for no capability gain on the kind of work Sonnet agents do. **Adaptive thinking on Sonnet 4.6 is opt-in but we adopt it uniformly across the roster** — it is the default mode we use for every Sonnet agent, so `effort:` has the same semantics on Sonnet as it does on Opus (both families use the same adaptive-thinking dial). Per [Anthropic's adaptive-thinking docs](https://platform.claude.com/docs/en/build-with-claude/adaptive-thinking), Sonnet 4.6 supports adaptive thinking; Opus 4.7 requires it.
- **`effort:` is always explicit.** Never omitted. The effort tag is the budget signal and has no reasonable default. It is a **ceiling-plus-tendency, not a floor**: at `medium`, the model may skip thinking entirely for trivial sub-tasks and scale upward to moderate depth on harder ones — the tag bounds how much reasoning the model is willing to spend, not how much it must spend every turn. Practical consequence: `effort: high` does not mean "always think hard," and `effort: low` does not mean "never think" — it means "budget frugally, but reach for thought if the task genuinely needs it."
- **Coordinators carry `concern: personal | work` instead of `pair_mate:` / `tier:` / `role_slot:`.** Coordinators are not sharded by complexity — they are sharded by life domain. The `concern:` field names that domain and is the routing key Evelynn and Sona use to decide whether a task belongs to them. This is a distinct axis from the pair-mate axis; pair-mate symmetry (§D4.3a check #2) explicitly skips agents without `pair_mate:`, so coordinators do not spuriously fail the symmetry check. Non-coordinator agents do not carry `concern:`. Q9 resolution: do not misuse `pair_mate:` for concern pairing.

This convention is encoded in the shared-rules pattern (§D4): the `_shared/<role>.md` file captures effort expectations, and each per-agent file is responsible for its own `model:` (omit for Opus, declare for Sonnet) and its own `effort:` value. The pre-commit hook in §D4.3 is extended to verify this convention: any agent definition with `model: opus` (redundant) produces a warning; any agent definition without `model:` is assumed Opus and must match the Opus-family expectation in its `_shared/<role>.md`; coordinators (identified by `concern:` presence) skip the pair-mate symmetry check.

**Why this sits in the taxonomy ADR:** the model convention is a property of the pair-mate contract. Pair-mates in the same role slot use different tiers, and the tier convention (complex = Opus, normal = mixed, single-lane = case-by-case) drives which `model:` field each definition carries. Documenting it here keeps the rule alongside the matrix that uses it.

### D1.1b. Canonical ordering rule

From Lux's cost-quality research, the canonical preference ordering for assigning a tier to a role slot is:

**Opus-xhigh > Opus-high > Opus-medium > Sonnet-high > Sonnet-medium > Sonnet-low**

When assigning tiers in this matrix (or any future retiering), walk the ordering top-down and pick the first tier that matches the role's reasoning-depth needs. **Never place an agent out of this order without an ADR-level justification**: if a role gets bumped up (e.g. skipping Opus-medium to reach Opus-high for a capability reason) or bumped down (e.g. landing at Sonnet-low for a specific cost-shape reason), the matrix notes must include a one-line rationale anchored to the role's work profile.

The never-Opus-low rule is a corollary: Opus-low sits *outside* this ordering — it's not a ranked tier, it's an anti-pattern. Any agent targeting careful reasoning but low token count goes to Sonnet-high instead (see Rakan and Syndra retierings in §D1 matrix notes).

### D1.2. Why two tiers not three

A three-tier split (light / normal / heavy) was considered and rejected. Reasoning: with ~9 role slots × 3 tiers the roster grows to ~25 active agents; the coordination overhead (which tier? which pair-mate? which shared-rules file?) dominates the savings. Two tiers — complex, normal — capture the important axis (is this task worth Opus-high thinking time) without exploding the surface.

When in doubt, Evelynn picks **normal**. See §D6 for classification rules.

### D1.3. Single-lane roles — rationale

Several role slots stay single-lane (no complex/normal split):

- **DevOps advice → exec (Heimerdinger → Ekko).** DevOps tasks are infrastructure-shaped. The "complex" case in DevOps isn't about reasoning depth, it's about blast radius. Heimerdinger already escalates to Duong for high-blast-radius changes; a second Opus-high DevOps agent would duplicate without differentiating. Ekko's execution tier is sufficient for both small and large DevOps changes because the execution part is mechanical once the plan is clear.
- **PR review (Senna + Lucian).** PR review is a *pair* of concerns — code-quality+security (Senna) and plan/ADR fidelity (Lucian) — applied to every PR. The work already partitions by concern, not by complexity. Adding a complex/normal split per reviewer would mean 4 reviewers per PR, which is coordination overhead with no signal gain. **Tier asymmetry (Senna Opus-high, Lucian Opus-medium) is intentional (Q10 resolution): code and security review is deeper work than plan-fidelity review.** Senna reasons open-endedly about threat models, race conditions, and API-shape regressions — Opus-high is justified. Lucian compares the PR diff against a written plan and flags deviations — a more structured task that Opus-medium handles cleanly. The asymmetry reflects work-shape, not reviewer importance; both run on every PR.
- **Orianna (fact-check / signer).** Signature authority is a property of agent identity (§D1.1 of the lifecycle ADR); splitting the identity would break that property. Opus-medium matches the coordinator tier since the work is verification, not deep reasoning.
- **Akali (QA Playwright).** Task shape doesn't partition by complexity — every UI PR needs the same Playwright + Figma diff flow regardless of feature size. Sonnet-medium is appropriate for browser automation work.
- **Skarner + Yuumi.** Minion agents, stateless, Sonnet-low. They are not sharded by complexity because their task shape is "cheap, bounded, high-volume lookups / moves." See `agents/memory/agent-network.md` for their stateless / no-self-close semantics.
- **Camille.** Git and security advisor, Opus-medium, single-lane because git/security advice rarely decomposes into two complexity tiers — it's either a small question or it's an escalation to Duong.
- **Coordinators (Evelynn, Sona).** Not sharded by complexity; sharded by concern (personal vs work) via the new `concern: personal | work` frontmatter field (§D1.1a). Sona's definition is committed as part of this ADR's implementation (Q8 resolution). See row 0 in the matrix and §D7 on routing.

These roles are called out in this ADR so they don't look like oversights in the taxonomy. Any future split for them is scoped separately (see §D9).

### D1.6. Cost awareness (footnote)

For calibration: on the Claude Max plan, **Opus vs Sonnet at equal effort burns roughly 5× more quota.** End-to-end, **Opus-xhigh vs Sonnet-low burns roughly 50×** (Opus-xhigh vs Sonnet-high is the 5× gap; compounding effort tiers adds another ~10× within the family). The matrix above is a budget document as much as a capability one — every Opus slot should justify its presence against "could Sonnet-high do this?"; every `xhigh` should justify its presence against "could Opus-high do this?" This footnote is not enforced by hook; it is a reminder to weigh Lux's cost-quality ordering (§D1.1b) when proposing new agents or retiering existing ones.

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

### D2.2. Rakan — Sonnet-high, complex-track test implementer

- **Role slot:** Test implementation (complex).
- **Tier:** complex.
- **Model/effort:** `model: sonnet`, `effort: high`.
- **Pair mate:** Vi (normal-track, Sonnet-medium).
- **One-line:** Authors xfail test skeletons, fault-injection harnesses, and non-routine test fixtures from Xayah's plans; passes the test plan to Vi for bulk run/iterate.
- **Note on tier-model interaction:** Rakan was originally scoped as Opus-low in the first taxonomy draft; retiered to Sonnet-high per the never-Opus-low rule (§D1 matrix notes + §D1.1b). Sonnet-high gives strong reasoning on test-skeleton authoring at a better `$/quality` point than Opus-low while preserving the complex-tier distinction from Vi's Sonnet-medium.

### D2.3. Soraka — Sonnet-low, normal-track frontend implementer

- **Role slot:** Frontend implementation (normal).
- **Tier:** normal.
- **Model/effort:** `model: sonnet`, `effort: low`.
- **Pair mate:** Seraphine (complex-track).
- **One-line:** Implements small frontend tweaks — a tooltip, a copy change, a simple component variant — from Lulu's inline advice; escalates to Seraphine when Neeko-scale design artifacts are needed.
- **Invocation trigger:** Trivial frontend tasks where producing a full Neeko design spec would be ceremony.

### D2.4. Syndra — Sonnet-high, normal-track AI/agents specialist

- **Role slot:** AI/Agents/MCP (normal).
- **Tier:** normal.
- **Model/effort:** `model: sonnet`, `effort: high`.
- **Pair mate:** Lux (complex-track, Opus-high).
- **One-line:** Handles small AI-stack tweaks — adjusting a prompt, tuning an agent's `effort:` value, adding a tool to a definition, renaming roster entries — where a full Lux research pass is overkill.
- **Invocation trigger:** Single-file or few-line changes to `.claude/agents/*.md`, `agents/*/profile.md`, or MCP config. Not for new MCP tools (that's Lux) or major agent redesigns (that's Lux + Swain).
- **Note on tier-model interaction:** Syndra was originally scoped as Sonnet-low in the first taxonomy draft; retiered to Sonnet-high per the never-Opus-low rule corollary (§D1.1b) — prompt/agent-def work deserves careful reasoning even at the normal tier, and Sonnet-high is the `$/quality` point that gives it.

---

## D3. Rescopes of existing agents

### D3.1. Lux — narrowed scope

Lux today covers Claude API + MCP + agent architecture + prompt engineering + agent-definition organization. New scope: **AI/Agents/MCP specialist + agent-definition organization**. Agent-definition organization is the explicit addition — historically this has drifted across Swain, Evelynn, and Lux without a clear owner; Lux gets it because he already holds domain knowledge about how agents are structured in this system.

Frontmatter update: `effort: medium` → `effort: high`. Lux is the complex-track counterpart to Syndra, and his work (MCP server design, prompt optimization, agent-topology changes) justifies Opus-high.

Description update: add "owns the shape of `.claude/agents/*.md` and the shared-rules include pattern (§D4)."

### D3.2. Viktor — rescoped to complex-track builder + effort bump

Today: "Refactoring agent — code restructuring, optimization, cleanup, migrations." New: "Complex-track feature builder — invasive features, migrations, cross-module work, and refactor-as-part-of-build. Paired with Jayce (normal-track)."

Rationale captured in §D1 matrix note (row 5): refactor is a task type, not an identity. Every builder refactors; labeling one agent "refactor only" forced awkward routing decisions whenever a feature touched existing code (which is always).

Viktor's model stays `sonnet`; his `effort` **bumps from `medium` to `high`** (this is the retiering change — complex-track builds benefit from higher-effort reasoning where ambiguity is greatest). The rescope is both the description/boundary text *and* the effort level.

Description update: drop "No new features or greenfield work (that's Jayce)" — this boundary no longer holds. Replace with "Viktor handles complex-track builds (migrations, multi-module features, invasive refactors). Jayce handles normal-track builds (greenfield, additive, single-module). Refactor is a task-shape both agents do as needed."

**Grandfathering for in-flight plans (Q7 resolution):** Plans currently in `plans/in-progress/` that reference Viktor as "refactor-only agent" continue to run under the old semantics. New plans authored after Phase B of the migration (§D8) use the new builder semantics. Evelynn should not retroactively reroute Viktor-assigned tasks from in-flight plans; if an in-flight task hits ambiguity under the old scope, escalate to Duong rather than silently reinterpreting.

### D3.3a. Jayce — effort bump

Jayce (normal-track builder) `effort` bumps from `low` to `medium`. Original Sonnet-low was under-powered for real feature work even at the normal tier; Sonnet-medium is the common-case builder tier. No scope change.

### D3.3b. Lulu — effort bump

Lulu (normal-track frontend design) `effort` bumps from `low` to `medium`, per the never-Opus-low rule. No scope change; the bump simply moves her onto the canonical ordering (§D1.1b).

### D3.3c. Caitlyn — effort drop

Caitlyn (normal-track test plan) `effort` drops from `high` to `medium`. No scope change. The normal-track test-plan slot is Opus-medium by matrix design (§D1 row 3); Caitlyn's current `effort: high` is reconciled down to match. Complex-track test-planning (resilience, fault injection, cross-service fixtures) moves to Xayah at Opus-high (§D2.1) — Caitlyn retains the normal-track slot for standard test-plan work where Opus-medium is sufficient.

### D3.3d. Neeko — effort bump

Neeko (complex-track frontend design) `effort` bumps from `medium` to `high`. No scope change. The complex-track frontend-design slot is Opus-high by matrix design (§D1 row 6); Neeko's current `effort: medium` is reconciled up to match. This is the counterpart to Lulu's bump-up onto the canonical ordering: complex-track UI work (multi-state flows, novel interaction patterns, cross-surface design systems) justifies Opus-high.

### D3.3e. Kayn — effort drop

Kayn (normal-track task breakdown) `effort` drops from `high` to `medium`. No scope change. The normal-track breakdown slot is Opus-medium by matrix design (§D1 row 2); Kayn's current `effort: high` is reconciled down to match. Complex-track breakdowns route to Aphelios at Opus-high (§D1 matrix note row 2) — Kayn retains the normal-track slot for standard ADR decomposition where Opus-medium is the right `$/quality` point.

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

### D4.3a. Additional hook checks beyond drift

The same `pre-commit-agent-shared-rules.sh` hook performs three additional checks on every commit touching `.claude/agents/`:

1. **Shared-rules drift (primary check, Q2 resolution).** Each paired agent's inlined shared content must byte-match the canonical `_shared/<role>.md`. Failure = re-run `sync-shared-rules.sh` or the commit is rejected. Q2 confirmed hook over CI: feedback is immediate and prevents drift from shipping rather than catching it post-push.
2. **Pair-mate symmetry (Q4 resolution).** For any agent with `pair_mate: <other>` frontmatter, the hook verifies `<other>`'s definition carries `pair_mate: <this>` in reverse. Asymmetric pairings (A→B but B→A missing or B→C) are rejected. Cheap to check (one grep over `.claude/agents/*.md`); catches a real drift class where someone renames or retiers one half of a pair and forgets the other. **Coordinators are skipped** — any agent whose frontmatter carries `concern: personal | work` (and therefore omits `pair_mate:`) is exempt from this check, because coordinators pair by concern not by complexity (Q9 resolution; see §D1.1a).
3. **Model-frontmatter convention (§D1.1a).** Sonnet agents MUST declare `model: sonnet`; Opus agents MUST omit `model:` entirely (inheriting the session default). Violations: `model: opus` declared on an Opus agent (redundant, warning), or `model:` missing on an agent that appears in a Sonnet role slot (e.g. Vi, Seraphine — check would emit an error). The hook implements this by cross-referencing each agent's `role_slot` + `tier` against the matrix in §D1 — mechanical comparison, no ambiguity.

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
| Coordinator *(concern-split, not complexity-split — uses `concern:` frontmatter per §D1.1a)* | **Evelynn** (Opus medium, `concern: personal`) | **Sona** (Opus medium, `concern: work`) |
| System architecture, ADR plans | **Swain** (Opus xhigh) | **Azir** (Opus high) |
| Backend task breakdown from ADR | **Aphelios** (Opus high) | **Kayn** (Opus medium) |
| QA audit and testing strategy | **Xayah** (Opus high) | **Caitlyn** (Opus medium) |
| Writing and running tests | **Rakan** (Sonnet high) | **Vi** (Sonnet medium) |
| Feature build | **Viktor** (Sonnet high) | **Jayce** (Sonnet medium) |
| Frontend design | **Neeko** (Opus high) | **Lulu** (Opus medium) |
| Frontend implementation | **Seraphine** (Sonnet medium) | **Soraka** (Sonnet low) |
| AI/Agents/MCP advice | **Lux** (Opus high) | **Syndra** (Sonnet high) |
| DevOps advice | **Heimerdinger** (Opus medium, single-lane) | — |
| Quick fixes, DevOps execution | **Ekko** (Sonnet medium, single-lane) | — |
| PR code + security review | **Senna** (Opus high, single-lane) | — |
| PR plan/ADR fidelity review | **Lucian** (Opus medium, single-lane) | — |
| Fact-check / plan signing | **Orianna** (Opus medium, single-lane) | — |
| QA Playwright + Figma diff | **Akali** (Sonnet medium, single-lane) | — |
| Memory retrieval | **Skarner** (Sonnet low, single-lane) | — |
| Light errands | **Yuumi** (Sonnet low, single-lane) | — |
| Git/security advisor | **Camille** (Opus medium, single-lane) | — |

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
3. Add `sync-shared-rules.sh` and `pre-commit-agent-shared-rules.sh`. The hook must implement the three checks in §D4.3a (shared-rules drift, pair-mate symmetry with `concern:` exemption, model-frontmatter convention).
4. Update `.claude/agents/sona.md` (Q8 resolution). The file is already tracked+modified today; it gets `concern: work` frontmatter added per §D1.1a and is committed as part of this Phase A. Evelynn's own definition gets `concern: personal` added at the same time so the coordinator axis is symmetric from the first commit.
5. Update `agents-table.md` and `agent-network.md` to list the new agents (Xayah, Rakan, Soraka, Syndra) as `new-2026-04-xx` and add Sona's roster entry.

Phase A leaves existing routing intact — Evelynn keeps using the current delegation table. New agents are in the roster but not yet invoked.

### D8.2. Phase B — rescopes

6. Rescope Lux definition per §D3.1 (narrowed scope, effort bump, description update).
7. Rescope Viktor definition per §D3.2 (drop "refactor only" boundary, add complex-track language).
8. Bump Swain's `effort:` to `xhigh` per §D3.3.
9. Update `agents/memory/agent-network.md` delegation chain to include tier-aware language where relevant (e.g. "Duong → Evelynn → Swain/Azir (architecture by complexity)").

### D8.3. Phase C — routing table swap

10. Update `agents/evelynn/CLAUDE.md` delegation table per §D7.
11. Add the "Classifying task complexity" section.
12. From here on, Evelynn routes by tier using the heuristics in §D6.

### D8.4. Phase D — optional enforcement

13. Add `complexity:` frontmatter field to the Orianna `proposed → approved` gate as a warning-first, block-later (a follow-up ADR, not this one).

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

# Resolved gating questions (round 2)

All seven round-1 questions plus one new framing decision were answered by Duong on 2026-04-20 in the consolidation pass. Summary:

1. **Q1. Xhigh effort tag.** Resolved: `effort: xhigh` works — harness accepts the value as a legitimate budget level. Swain uses it (§D1.1); no degradation to `high` needed.
2. **Q2. Shared-rules drift detection — hook vs CI.** Resolved: **pre-commit hook** (§D4.3a). `.claude/agents/*.md` edits are frequent and CI round-trips would slow iteration; immediate feedback prevents drift from shipping.
3. **Q3. Default-lean wording.** Resolved: keep "**complex** / **normal**." Semantics are clearer than premium/standard; Duong's task briefings already use the pairing.
4. **Q4. Pair-mate symmetry check.** Resolved: **yes**, the pre-commit hook verifies A→B ↔ B→A on every agent-def commit (§D4.3a check #2).
5. **Q5. Model/effort tiers — retiering applied.** Resolved: **Lux's retiering adopted** (§D1 matrix). Canonical rule: **never Opus-low** — it is the worst `$/quality` point and sits outside the canonical ordering (§D1.1b). Retierings: Rakan Opus-low → Sonnet-high; Syndra Sonnet-low → Sonnet-high; Viktor Sonnet-medium → Sonnet-high; Jayce Sonnet-low → Sonnet-medium; Lulu Opus-low → Opus-medium.
6. **Q6. Soraka.** Resolved: **keep Soraka** as the Sonnet-low normal-track frontend implementer. Rationale: matching pair structure across role slots makes the roster learnable; Soraka activates in Phase A of migration and gets real invocations as they emerge.
7. **Q7. Viktor rescope collisions with in-flight plans.** Resolved: **grandfathered** — in-flight plans that named Viktor under the old "refactor-only" scope run to completion under that scope; new plans (authored post-Phase B, §D8) use the new complex-track-builder semantics (§D3.2).
8. **New framing decision — model frontmatter convention.** Resolved: Opus agents omit `model:` (inherit session default, which is Opus 4.7 1M); Sonnet agents declare `model: sonnet` (alias, never a pinned ID); `effort:` is always explicit. Pre-commit hook check #3 enforces (§D1.1a + §D4.3a).

These decisions are durable — no further round is expected before the ADR promotes. See §D1 matrix notes, §D1.1a (model convention), §D1.1b (canonical ordering), §D1.6 (cost footnote), and §D3 (rescopes) for the concrete text they flow into.

---

# Resolved gating questions (round 3)

Round 3 arose while consolidating Lux's retiering. Duong resolved all three on 2026-04-20 in this revision pass:

1. **Q8. Sona inclusion scope.** Resolved: **commit Sona as first-class coordinator.** Row 0 stays as-is, and `.claude/agents/sona.md` becomes tracked as part of this ADR's implementation (§D1 matrix note row 0; §D1.3 coordinators bullet).
2. **Q9. Coordinator pairing axis.** Resolved: **introduce `concern: personal | work` frontmatter for coordinators.** Coordinators do NOT carry `pair_mate:` or `tier:`. Non-coordinators do not carry `concern:`. The pair-mate symmetry hook (§D4.3a check #2) skips any agent with `concern:` set. See §D1.1a fourth bullet for the full rule.
3. **Q10. Senna/Lucian tier asymmetry.** Resolved: **keep the asymmetry as-is.** Code and security review is deeper work than plan-fidelity review; Senna stays Opus-high and Lucian stays Opus-medium. Rationale captured in §D1.3 PR-review bullet.

All three round-3 resolutions flow into the ADR text above; no open questions remain at authoring time. The ADR is ready for Orianna fact-check and promotion.

---
