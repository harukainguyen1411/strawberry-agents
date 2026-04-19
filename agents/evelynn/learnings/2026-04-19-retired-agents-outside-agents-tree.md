# 2026-04-19 — Retired agent defs must live outside `.claude/agents/`

## Context

Duong listed Available agents at session start and noticed lowercase names (bard, fiora, katarina, lissandra, lux [Sonnet], ornn, poppy, pyke, reksai, shen, syndra, zoe) alongside the active capitalized roster. These are retired agents and shouldn't be callable.

Ekko confirmed all 12 files were already moved to `.claude/agents/_retired/` in a prior session. The harness was walking into `_retired/` subfolder and surfacing its defs as valid subagent_types anyway.

## Fix

`git mv .claude/agents/_retired/ .claude/_retired-agents/` — move the retired pile OUTSIDE the `agents/` subtree the harness scans. 3 doc refs rewritten to new path.

## Pattern

The harness does not respect a `_retired/` naming convention to skip directories. It registers any `.md` file under `.claude/agents/` regardless of nesting. Retirement requires physical relocation outside that tree.

## Recommendation

For future deprecations: move the agent def to `.claude/_retired-agents/` in the same PR that removes it from the active roster. Don't use underscore-prefix subfolders as a soft-delete — the harness doesn't care.
