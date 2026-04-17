---
slug: mirror-secretary-roster
status: proposed
owner: evelynn
created: 2026-04-17
---

# Mirror Secretary Roster onto Strawberry

## Goal
Replace the strawberry agent roster with the secretary (work) roster verbatim — same names, same tiers, same advisor→executor pairings. Evelynn stays as the top-level coordinator (replacing Sona's role in the secretary system). All other strawberry agents are retired or renamed to match.

## Target roster (16 subagents + Evelynn coordinator)

**Opus advisors/planners (9):**
- Azir — head product architect, ADR plans
- Kayn — backend task planner (breaks ADRs down)
- Aphelios — backend task planner, parallel with Kayn
- Caitlyn — QA audit lead, hands off to Vi
- Lulu — frontend/UI/UX design advisor (Opus) — provides design principles, critiques, pattern guidance
- Neeko — designer (Opus) — produces actual design artifacts (wireframes, component specs, UI mockups, interaction flows) that Seraphine then implements
- Heimerdinger — DevOps advisor, hands off to Ekko
- Camille — Git/GitHub/security advisor
- Lux — AI, Agents & MCP specialist

**Sonnet executors (7):**
- Jayce — builder (new features)
- Viktor — builder (refactoring, optimization)
- Vi — tester (executes Caitlyn's plans)
- Ekko — quick tasks and DevOps execution
- Jhin — PR reviewer
- Seraphine — frontend implementation (executes Neeko's design specs)
- Yuumi — Evelynn's errand runner

**Haiku (1):**
- Skarner — memory excavator

## Scope

### Add (new .claude/agents/*.md + agents/<name>/ dirs)
- azir, kayn, aphelios, lulu, heimerdinger, camille, jayce, vi, jhin, seraphine

### Promote (tier change)
- neeko: Sonnet frontend shapeshifter → **Opus** design advisor (paired with Lulu). Hands off to Seraphine.

### Rewrite (role changes)
- caitlyn: Sonnet debugger → Opus QA audit lead
- ekko: Sonnet fullstack → Sonnet quick-task + DevOps exec
- lux: Sonnet frontend → Opus AI/Agents/MCP specialist
- viktor: keep backend focus but frame as "refactor/optimization builder"
- yuumi: keep (errand runner — same role)
- skarner: keep (memory retrieval — same role)

### Retire (move to .claude/agents/_retired/)
- bard (absorbed into Lux)
- fiora (absorbed into Viktor's refactor scope)
- katarina (absorbed into Ekko's quick-task scope)
- lissandra (absorbed into Jhin)
- ornn (absorbed into Heimerdinger→Ekko chain)
- poppy (dropped — not in secretary roster)
- pyke (absorbed into Camille)
- reksai (absorbed into Jhin)
- shen (absorbed into Camille→Ekko chain)
- swain (absorbed into Azir)
- syndra (absorbed into Lux)
- zoe (dropped — not in secretary roster)

### Update
- `agents/memory/agent-network.md` — rewrite to match secretary's network doc, but with Evelynn as hub (not Sona) and strawberry-specific plan-lifecycle + rules
- `agents/evelynn/CLAUDE.md` — update delegation map to new roster
- Existing `agents/<name>/` dirs for retired agents: preserve as `agents/_retired/<name>/` so historical memory/transcripts aren't lost, but move out of the active roster

## Source of definitions
Copy `.claude/agents/<name>.md` files from `/Users/duongntd99/Documents/Work/mmp/workspace/.claude/agents/` for each of the 16 target agents, then adapt:
- Change any `sona` references to `evelynn`
- Change `secretary/` path references to strawberry equivalents (`agents/<name>/`)
- Preserve strawberry-specific CLAUDE.md rules (plans via main, chore: prefix, worktrees, age-decrypt rule, etc.)

## Steps

1. **Plan commit** — this file to main.
2. **Fetch secretary defs** — read all 16 target agent defs from the work repo.
3. **Archive retired strawberry agents** — `git mv .claude/agents/<name>.md` into `.claude/agents/_retired/` for bard, fiora, katarina, lissandra, neeko, ornn, poppy, pyke, reksai, shen, swain, syndra, zoe. Same for `agents/<name>/` dirs.
4. **Write new/rewritten defs** — create or overwrite .claude/agents/*.md for: azir, kayn, aphelios, caitlyn, lulu, heimerdinger, camille, lux, jayce, viktor, vi, ekko, jhin, seraphine, yuumi, skarner.
5. **Scaffold memory dirs** — for each new agent, create `agents/<name>/{profile.md, memory/MEMORY.md, learnings/, transcripts/}` with minimal starter content.
6. **Rewrite `agents/memory/agent-network.md`** to match secretary's shape, Evelynn-centered.
7. **Update `agents/evelynn/CLAUDE.md`** — new roster, new delegation chain.
8. **Commit + push** — single `chore:` commit.

## Learnings & memory migration (mandatory — nothing is lost)

For each retired or role-shifted agent, its `agents/<old>/memory/*.md` and `agents/<old>/learnings/*.md` are copied into the new owner's directories before the old dir is moved to `_retired/`. Migration map:

| Old agent | New owner(s) | Rationale |
|---|---|---|
| bard | lux | bard's MCP/tool work absorbed into lux (AI/Agents/MCP specialist) |
| fiora | viktor | fiora's refactor/bugfix work absorbed into viktor (refactor builder) |
| katarina | ekko | katarina's quick-task work absorbed into ekko (quick-task exec) |
| lissandra | jhin | lissandra's PR review absorbed into jhin (sole PR reviewer) |
| neeko | *(kept + promoted)* | neeko stays and is promoted to **Opus design advisor**. Existing Sonnet frontend learnings move to Seraphine; neeko keeps only design-judgment / UX-pattern learnings. |
| ornn | heimerdinger (advisor memory) + ekko (implementation learnings) | ornn's infra/CI advisor voice → heimerdinger; hands-on CI/toolchain fixes → ekko |
| poppy | yuumi | poppy's mechanical-edit patterns fold into yuumi's errand-runner scope |
| pyke | camille | pyke's git/security planner role → camille |
| reksai | jhin | reksai's PR review + regression-hunting → jhin |
| shen | camille (security patterns) + ekko (implementation learnings) | shen was pyke's executor; split mirrors pyke→camille advisor shift |
| swain | azir | swain's architecture planner role → azir (product architect) |
| syndra | lux | syndra's AI/agent strategy → lux (AI specialist) |
| zoe | ekko | zoe's throwaway scripting → ekko (quick tasks) |
| lux (old, frontend) | seraphine | old strawberry lux was frontend Sonnet → seraphine (the new Sonnet FE executor). New Lux is a different persona (Opus AI). Old lux learnings MUST NOT end up in new lux. |

**Neeko's own learnings split:** neeko's existing frontend/Sonnet learnings → seraphine (since neeko is promoted to Opus design advisor and shouldn't carry implementation-tier notes). Neeko keeps only design-pattern / UX-judgment learnings going forward.

**Same-name, same-role (no migration needed):** caitlyn (widened to Opus QA lead — prior debugger learnings stay), viktor (backend widened to refactor — prior learnings stay), ekko (widened — prior learnings stay, plus katarina+zoe+ornn-impl), yuumi (same role, plus poppy), skarner (same role).

### Migration procedure (per old agent)

1. `mkdir -p agents/<new>/learnings/_migrated-from-<old>/`
2. `cp agents/<old>/learnings/*.md agents/<new>/learnings/_migrated-from-<old>/`
3. Append `agents/<old>/memory/MEMORY.md` (or equivalent) into `agents/<new>/memory/MEMORY.md` under a new section header `## Migrated from <old> (2026-04-17)` — don't overwrite existing memory.
4. Copy `agents/<old>/profile.md` to `agents/<new>/_archive/profile-<old>.md` for reference.
5. `git mv agents/<old>/ agents/_retired/<old>/` once copies are confirmed.

Do the migration in step 3a of the main Steps list (between archiving retired agent defs and writing new agent defs) so new agents start life with their inherited knowledge.

## Out of scope
- Rewriting historical plans / journals that reference old agent names (they stay as historical record).
- Updating hooks, scripts, or skills that reference old agent names (audit separately after the roster swap).

## Risks
- Breaking any script that hard-codes an old agent name (e.g., `scripts/agent-*`). Mitigation: grep for each retired name after the commit and patch references.
- Loss of retired agents' context. Mitigation: archive under `_retired/`, don't delete outright.
