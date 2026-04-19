# Retired Agents Harness Scan Fix

**Date:** 2026-04-19
**Task:** Move `.claude/agents/_retired/` out of harness scan subtree

## Problem

The Claude Code harness scans the entire `.claude/agents/` subtree for agent
definition files and surfaces every `.md` it finds as a callable subagent_type.
This caused 13 retired agents (bard, fiora, jhin, katarina, lissandra,
lux-frontend-sonnet, ornn, poppy, pyke, reksai, shen, syndra, zoe) to appear
in the "Available agents" list.

## Fix

`git mv .claude/agents/_retired/ .claude/_retired-agents/` — moves the
directory one level up, outside the `agents/` subtree the harness scans.
History preserved (all 13 files tracked as renames in the commit).

## References updated

- `agents/memory/agents-table.md` — jhin row definition file path
- `assessments/migration-audits/2026-04-19-a7-orphan-path-sentinel.md` — allowlist entry
- `assessments/memory-audits/2026-04-18-memory-audit.md` — finding #6 text + reconciliation checklist

Historical transcripts, learnings, and other assessment docs left as-is
(frozen records; rewriting them would be incorrect).

## Push note

`origin` is `harukainguyen1411/strawberry-agents` (private). Push requires
the harukainguyen1411 reviewer PAT from `secrets/reviewer-auth.env` — the
default `duongntd99` auth token gets "Repository not found" (no access to
private repo under harukainguyen1411). Use:
```
git push https://harukainguyen1411:<TOKEN>@github.com/harukainguyen1411/strawberry-agents.git main
```

## Orianna note

`~/.claude/agents/orianna.md` is a user-level definition (identical content to
the project-level `.claude/agents/orianna.md`). Both are active and not in
conflict — the harness merges user-level and project-level agent defs. No action
needed; Duong's call whether to remove one.
