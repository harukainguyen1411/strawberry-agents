# Learning: P5 Phase 2 — strawberry-agents canonical rename (2026-04-19)

## Context

Second P5 run. The first P5 (commit 085b781) updated docs for the two-repo split
(strawberry + strawberry-app) but left `Duongntd/strawberry` as the agent-infra
slug because strawberry-agents migration was still "proposed" at that time.

By this session the migration has executed: `git remote get-url origin` returns
`https://github.com/harukainguyen1411/strawberry-agents.git`. The living docs
still referred to `Duongntd/strawberry` as the active agent-infra repo.

## What Changed (8 files)

- `architecture/cross-repo-workflow.md` — three-repo table now shows
  `harukainguyen1411/strawberry-agents` as Active and `Duongntd/strawberry` as
  Archive. Account roles, plan-store section, PR permalink template, secrets
  section, worktree paths, cross-repo search examples, and conventions summary
  all updated.
- `architecture/git-workflow.md` — Two-Repo Model bullet rewrote lead repo slug;
  break-glass API URL updated from `Duongntd/strawberry` to
  `harukainguyen1411/strawberry-agents`.
- `architecture/pr-rules.md` — opening line plan-commit target updated.
- `architecture/system-overview.md` — repo structure heading updated from
  `Duongntd/strawberry` to `harukainguyen1411/strawberry-agents`; archive note
  replaces "planned third repo" sentence.
- `agents/evelynn/CLAUDE.md` — two-repo reminder slug updated.
- `agents/evelynn/memory/evelynn.md` — myapps-prod-deploy.yml secrets note
  updated: workflows now live in `strawberry-app`, not `Duongntd/strawberry`.
- `agents/memory/agent-network.md` — CLAUDE.md absolute local path corrected
  from `strawberry/` to `strawberry-agents/`.
- `agents/viktor/memory/MEMORY.md` — Key Knowledge two-repo model entry updated.

## Frozen Records — Left Untouched

- `agents/*/learnings/` and `agents/*/transcripts/` — always frozen.
- `agents/*/memory/MEMORY.md` session-narration entries — frozen per constraint.
- Archive-note footers in all MEMORY.md files — correct as written.
- `assessments/` — internal analyses, frozen records.
- `plans/` — reflect state at time of writing.
- `agents/azir/memory/MEMORY.md:9` — already correctly labels `Duongntd/strawberry`
  as archive.
- `agents/evelynn/memory/evelynn.md:42` — correctly references `Duongntd/strawberry`
  as the old archive in parenthetical context.

## Decision Note

The previous P5 learning (2026-04-19-p5-two-repo-architecture-docs.md) applied a
"conservative rule: leave if ambiguous." That was correct for the first pass when
`strawberry-agents` was still proposed. For this pass, the verification step is
`git remote get-url origin` — if it returns `strawberry-agents`, the migration is
complete and living docs must be updated.
