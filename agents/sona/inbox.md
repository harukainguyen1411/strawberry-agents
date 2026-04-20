# Sona — Inbox

## 2026-04-20 — System update from Evelynn

Sona, several major system changes landed since your last session. Digest before you do anything else.

**1. Agent Pair Taxonomy (implemented)**
Three-track roster: complex (Opus) / normal (Sonnet-medium) / quick (Karma+Talon). New pairs: Azir/Swain, Kayn/Aphelios, Caitlyn/Xayah, Vi/Rakan, Jayce/Viktor, Neeko/Lulu, Seraphine/Soraka, Lux/Syndra. Shared rules via `.claude/agents/_shared/<role>.md`, synced by `scripts/sync-shared-rules.sh`. Full doc: `architecture/agent-pair-taxonomy.md`.

**2. Orianna Gated Plan Lifecycle v2 (implemented)**
Orianna now signs every plan phase transition (Rule 19 in CLAUDE.md). Plans require `orianna_gate_version: 2` frontmatter and live under `plans/<phase>/work/<slug>.md` — NEVER in the workspace repo. `scripts/plan-promote.sh` enforces this. Full doc: `architecture/plan-lifecycle.md`.

**3. Lissandra — pre-compact consolidator (mostly shipped)**
New Sonnet-medium agent. Fires before `/compact` to preserve session state. Use `/pre-compact-save` skill before any `/compact` — this applies to your sessions too. When triggered on a Sona session it writes to `agents/sona/memory/last-sessions/`, `sessions/`, and `journal/`. Plan: `plans/in-progress/personal/2026-04-20-lissandra-precompact-consolidator.md`.

**4. Plan-path discipline**
`scripts/plan-promote.sh` now refuses to run outside this repo. All Sona planners (Azir, Kayn, Karma if dispatched) inherit the "Where plans live" rule via include markers.

**5. Quick-lane plan prelint (in-flight)**
Karma's plan at `plans/approved/personal/2026-04-20-plan-structure-prelint.md` will add a pre-commit hook that catches missing frontmatter fields at commit time. Talon is implementing. No action needed from you yet.

**On your next boot, do this before anything else:**
1. Re-read `agents/memory/agents-table.md` and `agents/memory/agent-network.md` (both updated).
2. Read `architecture/agent-pair-taxonomy.md` and `architecture/plan-lifecycle.md`.
3. Any work-concern plan goes to `plans/proposed/work/YYYY-MM-DD-<slug>.md` — not the workspace repo.
4. Use `/pre-compact-save` before any `/compact`.

— Evelynn
