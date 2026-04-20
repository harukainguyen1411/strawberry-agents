# Agent pair taxonomy — as-built

**Status:** implemented
**Source ADR:** `plans/in-progress/2026-04-20-agent-pair-taxonomy.md`
**Last updated:** 2026-04-20

This doc describes the agent pair taxonomy *as it actually runs in the repo today* — file paths, frontmatter contracts, hook behavior, and the routing mechanics Evelynn uses. The ADR is the design rationale; this is the operating manual.

---

## 1. The two-track model

Every role slot that benefits from complexity sharding has **two fills**: a complex track and a normal track. Single-lane roles stay single-lane. Coordinators are sharded by life domain (concern), not by complexity.

### 1.1 Role-slot matrix

| # | Role slot | Complex | Normal |
|---|-----------|---------|--------|
| 0 | Coordinator | Evelynn (Opus medium, `concern: personal`) | Sona (Opus medium, `concern: work`) |
| 1 | Architect (ADR) | Swain (Opus xhigh) | Azir (Opus high) |
| 2 | Task breakdown | Aphelios (Opus high) | Kayn (Opus medium) |
| 3 | Test plan / audit | Xayah (Opus high) | Caitlyn (Opus medium) |
| 4 | Test implementation | Rakan (Sonnet high) | Vi (Sonnet medium) |
| 5 | Feature builder | Viktor (Sonnet high) | Jayce (Sonnet medium) |
| 6 | Frontend design | Neeko (Opus high) | Lulu (Opus medium) |
| 7 | Frontend impl | Seraphine (Sonnet medium) | Soraka (Sonnet low) |
| 8 | AI / Agents / MCP | Lux (Opus high) | Syndra (Sonnet high) |

Single-lane roles:

| # | Role slot | Agent |
|---|-----------|-------|
| 9 | DevOps advice | Heimerdinger (Opus medium) |
| 10 | DevOps exec | Ekko (Sonnet medium) |
| 11 | PR code/security | Senna (Opus high) |
| 12 | PR plan fidelity | Lucian (Opus medium) |
| 13 | Fact-check / signer | Orianna (Opus medium, script-only) |
| 14 | QA Playwright | Akali (Sonnet medium) |
| 15 | Memory excavator | Skarner (Sonnet low) |
| 16 | Errand runner | Yuumi (Sonnet low) |
| 17 | Git/security advisor | Camille (Opus medium) |

### 1.2 Why two tracks, not three

Three tiers (light / normal / heavy) explodes to ~25 active agents at 9 paired role slots. The coordination overhead (which tier? which pair-mate? which shared file?) dominates the savings. Two tiers — complex, normal — capture the load-bearing axis without coordinating noise.

Default lean: **when uncertain, pick normal.** Escalation upward (re-route the next phase to complex) is cheap; routing complex when normal would suffice is wasted Opus budget. See §3 for classification rules.

### 1.3 Never Opus-low

The canonical preference ordering is:

`Opus-xhigh > Opus-high > Opus-medium > Sonnet-high > Sonnet-medium > Sonnet-low`

Opus-low sits **outside** this ordering. It pays Opus token rates for under-reasoned output — the worst `$/quality` point on the frontier. Any role that wants careful reasoning at lower token spend goes to **Sonnet-high** instead.

Practical effect: Rakan (test-impl complex) is Sonnet-high. Syndra (AI specialist normal) is Sonnet-high. Lulu (frontend-design normal) was bumped from Opus-low to Opus-medium when this rule was adopted.

---

## 2. The shared-rules pattern

### 2.1 Layout

```
.claude/agents/
  _shared/
    architect.md           # Swain + Azir
    breakdown.md           # Aphelios + Kayn
    test-plan.md           # Xayah + Caitlyn
    test-impl.md           # Rakan + Vi
    builder.md             # Viktor + Jayce
    frontend-design.md     # Neeko + Lulu
    frontend-impl.md       # Seraphine + Soraka
    ai-specialist.md       # Lux + Syndra
  azir.md
  swain.md
  aphelios.md
  ...
```

Single-lane roles do not get `_shared/` files — their content lives inline.

### 2.2 What goes where

**Shared file (`_shared/<role>.md`):**
- Role principles ("architect: design for next 2 years")
- Role boundaries ("architect: never self-implement")
- Role process (understand → research → design → spec → hand off)
- Role's slice of the universal Strawberry rules
- Role's closeout protocol

**Per-agent file:**
- Frontmatter: `model` (Sonnet only), `effort`, `tier`, `pair_mate`, `role_slot`, `name`, `description`, `tools`, `permissionMode`
- Personality / "About" block (the League of Legends voice)
- Pair-context note (who's the pair-mate, what triggers complex vs normal)
- Startup sequence (per-agent paths)
- An include marker `<!-- include: _shared/<role>.md -->` followed by the inlined shared content

### 2.3 Why physical inlining

Claude Code's subagent loader reads a single `.md` file into context. It does not chase `<!-- include: -->` directives. So shared content must be **physically present** in each agent's file at invocation time.

The pattern:
1. The include marker is a **human signal** — it tells readers and tools where the shared content logically lives.
2. The shared content is inlined verbatim below the marker in each pair-mate's definition.
3. `scripts/sync-shared-rules.sh` re-inlines from `_shared/<role>.md` into each pair-mate's file, preserving the per-agent header.
4. A pre-commit hook blocks commits where a per-agent file's inlined shared content has drifted from its canonical `_shared/<role>.md`.

This gives single-source-of-truth without requiring loader changes.

---

## 3. Frontmatter contract

### 3.1 Model convention

- **Opus agents: omit `model:` entirely.** They inherit the session default (Opus 4.7 1M today) and auto-upgrade when newer Opus tiers ship.
- **Sonnet agents: declare `model: sonnet`.** The alias resolves to Sonnet 4.6; never pin a specific ID like `sonnet-4-6`.
- **`effort:` is always explicit.** Tags: `low | medium | high | xhigh`. It is a budget ceiling-plus-tendency, not a floor — `effort: high` does not mean "always think hard," it means "reach for thought when the task warrants it."

### 3.2 Adaptive thinking

Both Opus 4.7 and Sonnet 4.6 use the same adaptive-thinking dial. Opus 4.7 requires it (always on, automatically tuned by `effort:`). Sonnet 4.6 is opt-in — adopted uniformly across the roster via the `thinking: { budget_tokens: N }` block. Budget scales with effort:

| Effort | budget_tokens |
|--------|---------------|
| low    | 2000 |
| medium | 5000 |
| high   | 10000 |
| xhigh  | 16000 (Swain only) |

Opus agents do not need an explicit `thinking:` block — adaptive thinking is automatic per-effort. Sonnet agents must declare it explicitly to enable.

### 3.3 Pair-mate fields

Every paired agent carries:

```yaml
tier: complex | normal
pair_mate: <other-agent-name>
role_slot: architect | breakdown | test-plan | test-impl | builder | frontend-design | frontend-impl | ai-specialist
```

Single-lane agents omit these.

### 3.4 Coordinator fields

Coordinators carry `concern: personal | work` instead of `pair_mate:` / `tier:` / `role_slot:`. Non-coordinators do not carry `concern:`.

The pair-mate symmetry hook (§4.2) skips any agent with `concern:` set — coordinators pair by life domain, not complexity.

---

## 4. Pre-commit hook (`scripts/hooks/pre-commit-agent-shared-rules.sh`)

Runs on every commit touching `.claude/agents/`. Three checks:

### 4.1 Shared-rules drift (primary)

For every paired agent, the inlined content below the include marker must byte-match the canonical `_shared/<role>.md`. Failure → "run sync-shared-rules.sh".

This catches the case where someone edits `_shared/builder.md` but forgets to re-sync into `viktor.md` and `jayce.md`.

### 4.2 Pair-mate symmetry

For any agent with `pair_mate: <other>` in frontmatter, the hook verifies `<other>`'s definition carries `pair_mate: <this>` in reverse. Asymmetric pairings (A→B but B→A missing or B→C) are rejected.

Coordinators (any agent with `concern:`) are exempt — they do not pair by complexity.

### 4.3 Model-frontmatter convention

- Sonnet agents MUST declare `model: sonnet`.
- Opus agents MUST omit `model:` entirely.
- Cross-references each agent's `role_slot:` + `tier:` against the matrix in §1.1 to determine expected model family.
- Violations: `model: opus` declared (warning, redundant); `model:` missing on a Sonnet-role agent (error).

---

## 5. Sync script (`scripts/sync-shared-rules.sh`)

Reads each `_shared/<role>.md` file and re-inlines its content into both pair-mates of that role. Preserves the per-agent header (frontmatter + personality block + pair-context + startup sequence). Rewrites everything from the include marker onward.

Idempotent — running twice produces identical output. Run after editing any `_shared/<role>.md` file, before committing.

Wired into `scripts/install-hooks.sh` indirectly: the hook dispatcher globs `pre-commit-*.sh` so the new hook is auto-discovered on fresh installs.

---

## 6. Routing — how Evelynn picks a track

When delegating a task, Evelynn classifies the task's complexity per §D6 of the source ADR. Heuristics:

**Complex indicators (any 2 → complex):**
1. Estimated AI-minutes total > 180 across the plan
2. Tasks in breakdown > 10
3. Cross-cutting impact (multiple top-level domains, CLAUDE.md changes, universal-invariant changes)
4. Invasive schema changes (data model propagation)
5. New external system integrations (first-time MCP, new API client)
6. Plan governance meta-work (changes to the plan lifecycle itself)

**Normal indicators (all must hold to default normal):**
- AI-minutes ≤ 180
- Tasks ≤ 10
- Single top-level domain
- No schema propagation
- No new external integrations

**Default lean:** If exactly one complex indicator fires and the rest look normal, go **normal**. Re-routing upward mid-plan is cheap; routing complex when normal would suffice is wasted budget.

### 6.1 Complexity declaration

Plans authored under this taxonomy SHOULD include a `complexity: complex | normal` frontmatter field — informational, records the classification at authoring time so mid-lifecycle agents know the track.

Missing field defaults to `normal`. Enforcement is deferred to a future ADR.

---

## 7. Migration phases

| Phase | Status | Scope |
|-------|--------|-------|
| A — Additions | implemented 2026-04-20 | `_shared/` dir + 8 role files; 4 new agent defs (Xayah, Rakan, Soraka, Syndra); sync script + pre-commit hook; coordinator `concern:` frontmatter |
| B — Rescopes | implemented 2026-04-20 | Lux narrow scope + effort bump; Viktor rescope (drop refactor-only); Swain effort bump to xhigh; agent-network.md delegation language |
| C — Routing | implemented 2026-04-20 | `agents/evelynn/CLAUDE.md` delegation table swap; "Classifying task complexity" section |
| D — Optional enforcement | deferred | `complexity:` frontmatter gate in Orianna's `proposed → approved` check |

### 7.1 Grandfathering

Plans currently in `plans/in-progress/` that named Viktor under the old "refactor-only" scope continue to run under the old semantics. New plans authored after Phase B use the new complex-track-builder semantics. Mid-plan ambiguity escalates to Evelynn rather than silent reinterpretation.

---

## 8. Cost calibration

| Comparison | Approximate burn ratio |
|------------|------------------------|
| Opus vs Sonnet at equal effort | 5× |
| Opus-xhigh vs Sonnet-low (full ladder) | ~50× |
| Within-family effort tier compounding | ~10× across low → xhigh |

Every Opus slot should justify its presence against "could Sonnet-high do this?" Every `xhigh` should justify against "could Opus-high do this?"

This is informational, not enforced. The matrix in §1.1 is a budget document as much as a capability one.

---

## 9. Future work (out of scope today)

- **Tier-aware Orianna gate** — `complexity:` frontmatter enforcement in `proposed → approved` (Phase D, deferred).
- **Senna/Lucian split by complexity** — review concerns already partition by type; complexity split would mean 4 reviewers per PR (rejected).
- **DevOps split** — Heimerdinger → Ekko works as single-lane (rejected).
- **Akali split** — task shape doesn't partition by complexity (rejected).
- **Auto-routing scripts** — could grep frontmatter to resolve "complex-track architect" → Swain at delegation time. Possible but not required today.
