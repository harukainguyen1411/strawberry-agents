---
title: Coordinator routing discipline — structural fix for plan-author/pair-mate/Rule-12 dispatch errors
author: lux
date: 2026-04-25
concern: personal
tags: [agents, routing, coordinator, hooks, taxonomy, evelynn, sona]
status: research
related:
  - plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md
  - .claude/agents/_shared/coordinator-intent-check.md
  - plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
  - plans/approved/personal/2026-04-25-coordinator-deliberation-primitive.md
  - agents/evelynn/learnings/2026-04-25-gate-bypass-on-surgical-infra-commits.md
---

# 1. Verification of Evelynn's self-diagnosis

The diagnosis is **largely correct, with one important upgrade**. Findings:

**Diagnosis claim 1 — taxonomy is scattered across 4-5 files.** Partially true; partially **better than claimed**.
The pair-taxonomy *narrative* lives in `plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md` (Evelynn cited the wrong path — it's `pre-orianna/implemented/`, not `in-progress/`). The *executive summary* lives in `agents/memory/agent-network.md` §"Coordination" lines 87–116 with the correct complex/normal lane breakdown. Rule 12 sits in repo-root `CLAUDE.md`. Twelve `.claude/agents/<name>.md` files carry frontmatter.

**Crucially, the data needed to mechanize the check is already first-class in frontmatter.** Spot-check confirmed:
- `viktor.md` → `tier: complex`, `pair_mate: jayce`, `role_slot: builder`
- `rakan.md` → `tier: complex`, `pair_mate: vi`, `role_slot: test-impl`
- `karma.md` → `tier: quick`, `pair_mate: talon`, `role_slot: quick-planner`
- `talon.md` → `tier: quick`, `pair_mate: karma`, `role_slot: quick-executor`
- `swain.md` → `tier: complex`, `pair_mate: azir`, `role_slot: architect`

Plan files carry `owner: <agent-slug>` in frontmatter (e.g. retrospection-dashboard plan: `owner: swain`; today's karma-authored plans: `owner: karma`). Both endpoints (plan owner, agent pair_mate/tier) are already machine-readable. **What's missing is the glue lookup** — "owner: swain on this plan ⇒ build/test track is `tier: complex` ⇒ valid impl agents are {viktor, rakan} (and not {talon})."

**Diagnosis claim 2 — fast-pattern-match-vs-slow-lane-check under load.** Confirmed and corroborated by an existing primitive: `_shared/coordinator-intent-check.md` already encodes the "intent block before mutating tool call" pause but its 4-line shape (literal/goal/failure-if-literal/shape) does not include "lane". A coordinator running the intent block as written today *can* still get Error 1 right if they happen to think about lane, but the schema doesn't force it.

**Diagnosis claim 3 — no automated check.** Confirmed. The `agent-default-isolation.sh` PreToolUse `Agent` hook is the architectural precedent — it already reads the dispatched subagent's frontmatter to inject `isolation`. There is room beside it for a sibling routing check. Existing `Agent`-matcher infrastructure is wired in `.claude/settings.json`.

**Upgrade to the diagnosis:** Error 2 (Viktor without Rakan) is a different failure shape than Error 1 (Talon vs Swain-lane). Error 1 is **lane mismatch**; Error 2 is **incomplete pair dispatch under Rule 12**. A single fix that only verifies "is the dispatched agent's lane correct" catches Error 1 but not Error 2 (Viktor's lane is correct — his solo dispatch is the problem). Any structural fix must address both.

# 2. Structural recommendation: D (combined) — but cheap-first, hook-second

**Recommend D, sequenced.** A + B ship pre-lock immediately (low cost, high coverage); C ships as a follow-up if A+B don't measurably reduce errors over the canonical-v1 measurement window.

## 2.1. The one-page cheat-sheet (option A)

`architecture/agent-routing.md` — single doc, glanced at dispatch time. Sketch of the headers:

- **§1. The dispatch question** — "What is the upstream plan's `owner:`?" (4-step lookup)
- **§2. Lane lookup table** — keyed by plan author slug → required pair-mates set
  - Authors `swain` / `aphelios` / `xayah` → impl pair = `{viktor, rakan}`
  - Authors `azir` / `kayn` / `caitlyn` → impl pair = `{jayce, vi}`
  - Author `karma` → impl = `{talon}` (single executor; no pair-mate split)
  - Authors `lux` (complex AI) / `syndra` (normal AI) — typically self-dispatch the impl chain since plan author = specialist
  - Authors `neeko` (complex FE) / `lulu` (normal FE) → impl = `{seraphine}` / `{soraka}`
- **§3. Rule 12 sequencing reminder** — for any complex/normal pair-mate impl-set whose row includes a test-impl agent (rakan or vi), that agent's xfail commit MUST land on the branch BEFORE the builder's first impl commit
- **§4. Single-lane exceptions** — Heimerdinger→Ekko, Senna+Lucian, Akali, Camille, Orianna
- **§5. The dispatch checklist** — 4 yes/no questions to answer before invoking `Agent`

Cost: one Karma plan, one new doc, no code. Can ship today pre-lock.

## 2.2. The routing primitive include (option B)

`.claude/agents/_shared/coordinator-routing-check.md` — sourced by Evelynn and Sona at the same level as `coordinator-intent-check.md`. Section sketch:

- **§Pre-dispatch routing block** — emit internally before any `Agent` tool call:
  1. **Plan author** — what is the upstream plan's `owner:` field? (or "no plan; ad-hoc")
  2. **Required lane** — given that author, complex / normal / quick / single-lane?
  3. **Required pair-mates** — full set, not just the agent in front of you
  4. **Rule-12 position** — am I dispatching the test-impl-then-builder-on-same-branch sequence? Whose commit lands first?
- **§"This dispatch feels obvious" smell** — if you reached for an agent name on pattern match without working through the four-line block, **stop**. The intent-check primitive's "surgical is not a license" framing applies one floor up: pattern-match speed is not a license to skip the routing block.
- **§Read-only / status-ping dispatches exempt** — Skarner read-only excavation, Yuumi inbox FYI. Anything with `tier: quick` or single-lane still requires the block (those are where Error 1 happened).

Cost: small include file + sync via existing `scripts/sync-shared-rules.sh` + `<!-- include: -->` mechanism. Ships today pre-lock.

## 2.3. The hook (option C, deferred)

`scripts/hooks/pretooluse-agent-routing-check.sh` — PreToolUse `Agent`-matcher sibling to `agent-default-isolation.sh`. Parse strategy:

1. Read JSON from stdin; extract `tool_input.subagent_type` and `tool_input.prompt`
2. Scan prompt for `plans/(approved|in-progress)/.*\.md` path matches
3. For each matched plan: read its frontmatter `owner:`, look up the author's `tier:` from the agent's `.md`
4. Read dispatched subagent's frontmatter `tier:` and `role_slot:`
5. **Mismatch policy**:
   - Lane mismatch (e.g. plan owner `swain` → tier `complex`; dispatched `talon` → tier `quick`) → **block** with diagnostic listing the correct pair-mates
   - Builder dispatched without test-impl pair-mate visible elsewhere on branch (heuristic: grep recent commits for the test-impl slug) → **warn-not-block** (false-positive risk too high to fail closed)
6. Empty-prompt / no-plan-cited / ad-hoc dispatch → pass (don't gate exploratory work)

**Why deferred, not skipped.** The hook has real false-positive risk — multi-plan dispatches, drive-by mentions of plan paths, plans with multiple legitimate impl tracks (the retrospection plan itself spans multiple lanes). Shipping A+B and measuring whether human discipline alone closes the gap is cheaper. C ships only if the canonical-v1 retro shows recurring Error 1 / Error 2.

# 3. Authoring path

**Recommendation: one Karma quick-lane plan, scoped to A + B together; defer C.**

Rationale: A and B are both small, the rule and the doc are tightly coupled (the include points readers at the cheat-sheet for the lookup table), and a single Karma → Talon round-trip covers both. C is deferred per §2.3.

**The brief Karma should receive:**

> **Plan title:** "Coordinator routing discipline — cheat-sheet doc + dispatch primitive include"
>
> **Goal:** Add a single one-page routing reference at `architecture/agent-routing.md` keyed by plan author → required pair-mates, plus a `_shared/coordinator-routing-check.md` include sourced by Evelynn and Sona that adds a 4-line pre-dispatch reasoning block alongside the existing `coordinator-intent-check.md`.
>
> **Source material:** This memo (`assessments/research/2026-04-25-coordinator-routing-discipline.md`); pair taxonomy (`plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md`); `.claude/agents/_shared/coordinator-intent-check.md` for the existing primitive shape; `agents/memory/agent-network.md` §Coordination for the routing tree.
>
> **Out of scope:** The PreToolUse hook (option C) — defer to a follow-up plan after the canonical-v1 measurement window.
>
> **Pre-lock urgency:** Both deliverables touch `_shared/*.md` (and one architecture doc) — must land before the canonical-v1 freeze at retrospection-dashboard Phase 2 ship.
>
> **Acceptance:** Evelynn's and Sona's agent defs include the new `coordinator-routing-check.md` via `<!-- include: -->`; sync runs via `scripts/sync-shared-rules.sh`; the cheat-sheet renders the full lookup table covering all 12+ pair-mate-bearing agents.

Karma is correct because: (a) Karma owns documentation-shape + small-file plans by precedent (today's karma-authored plan list is overwhelmingly small infra/discipline plans); (b) two surface artifacts is exactly the quick-lane sweet spot; (c) Talon can implement (one new doc, one new include, two existing-agent-def edits) in a single pass.

# 4. Trade-offs weighed

- **A alone vs A+B.** Cheat-sheet alone is passive — it doesn't trigger reading. The include actively gates dispatch via the same mechanism the intent-check uses. A+B is defense-in-depth with negligible extra cost.
- **B alone vs A+B.** Include without cheat-sheet forces coordinators to internalize the lookup table from prose; the table form is much faster to scan at dispatch time. A+B keeps the table visible.
- **C now vs C deferred.** Hook adds enforcement strength but has parse-edge-case risk; better to measure A+B first.
- **Single combined plan vs split A/B/C plans.** Combined keeps coupling visible; split fragments the discipline change.
- **Pre-lock vs post-lock.** Must be pre-lock — touches `_shared/*.md` which is canonical-v1 territory.

# 5. Open questions

**OQ1 (highest priority):** Should the cheat-sheet table also include a "Rule-12 sequence position" column per row, or does that belong only in the include's reasoning block? *Recommendation: keep the table lean (author → impl-set), put Rule-12 mechanics in a separate §3 of the doc and in the include's §Pre-dispatch routing block. A column for it would clutter the lookup.*

**OQ2:** When a plan cites multiple lanes (e.g. the retrospection-dashboard plan touches `_shared/`, hooks, and observability tooling — multiple specialists across multiple phases), does Evelynn run the routing block once per dispatch, or once per phase? *Recommendation: once per dispatch — the block is fast, multiple specialists per plan is the common case.*

**OQ3:** Should `lux` and `syndra` plan-author rows note the "self-dispatch impl" exception explicitly, or treat AI/MCP work as a special case in §4 single-lane exceptions? *Recommendation: special-case in §4. Lux-authored plans frequently land via direct edits (this memo is one example), so coding them as "self-dispatch impl" in the main table is misleading.*
