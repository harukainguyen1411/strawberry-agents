---
date: 2026-04-10
topic: Claude Code configuration audit — duplication, hierarchy, and best-practice gaps
---

# Claude Code Config Audit — Key Findings

## The Problem

Duong's workspace has configuration spread across 5 layers with significant duplication:

1. `~/.claude/CLAUDE.md` (global) — 3 rules
2. `CLAUDE.md` (workspace root) — 71 lines, loaded every session
3. `secretary/CLAUDE.md` — 94 lines, Sona's protocol
4. `.claude/agents/*.md` — 25 agent files, 1784 total lines
5. `secretary/agents/_shared/agent-network.md` — 70 lines, roster + shared rules
6. User auto-memory (MEMORY.md) — 32 entries, ~384 lines

Plus 10+ repo-specific CLAUDE.md files (wallet-studio, flight-delay, tse, etc.)

## Duplication Map

| Rule | Locations where it appears |
|---|---|
| "Never include AI authoring in commits" | Global CLAUDE.md, workspace CLAUDE.md, wallet-studio CLAUDE.md, mmp-tech-docs CLAUDE.md, mcps CLAUDE.md, skills CLAUDE.md, ekko.md, jayce.md, viktor.md, agent-network.md |
| "Never use git rebase" | workspace CLAUDE.md, flight-delay CLAUDE.md, ekko.md, jayce.md, viktor.md, agent-network.md |
| "Don't modify secretary state files" | sona.md body, ekko.md, jayce.md, viktor.md, jhin.md, senna.md, caitlyn.md, seraphine.md, thresh.md, camille.md, karma.md, etc. (18+ agents) |
| "Sona never writes code" | sona.md body, secretary/CLAUDE.md, agent-network.md |
| Agent roster | secretary/CLAUDE.md (partial), agent-network.md (full), sona.md (references) |
| Session logging / Skarner call | Every single agent file (25 files) |
| Closeout protocol (learnings + memory) | Every agent file except Skarner and Yuumi |
| CI verification (`gh pr checks`) | ekko.md, jayce.md, viktor.md, seraphine.md, thresh.md, lulu.md, nautilus.md, heimerdinger.md, aphelios.md, kayn.md, zilean.md |

## Contradictions

1. `agent-network.md` lists all agents as "Sonnet" model — but `.claude/agents/*.md` frontmatter shows Lux, Senna, Orianna, Azir, Aphelios, Kayn, Zilean as Opus
2. `secretary/CLAUDE.md` lists only 3 worker agents (Ekko, Jayce, Viktor) — the actual roster is 24 agents
3. Tool lists in agent frontmatter have duplicate entries (Grep, Agent, WebSearch, WebFetch listed twice in many files)

## Context Budget Impact

The workspace root CLAUDE.md (71 lines) is loaded into EVERY session, including subagent sessions. It contains secretary-specific content (Sona description, state file pointers) that is irrelevant to coding agents. This wastes context budget.

## State-of-the-Art Gap

Per Anthropic's official docs (April 2026):
- CLAUDE.md should target under 200 lines and contain only rules Claude would violate without them
- Use hooks (deterministic) for critical rules, not CLAUDE.md (advisory, ~70% compliance)
- Use skills for domain workflows loaded on demand
- Subagent files should be lean — system prompt only, not reference documentation
- The `memory` frontmatter field now gives agents built-in persistent memory — no need for manual memory/learnings directories
- Agent teams are now the proper way to coordinate multi-agent work (vs. manual Agent tool spawning)

## Recommendations Summary

1. Split workspace CLAUDE.md into workspace-wide rules vs. secretary-specific rules
2. Extract shared agent rules into a reusable skill or use hooks
3. Use the native `memory` frontmatter field instead of manual secretary/agents/<name>/memory/ directories
4. Enforce "no AI authoring" via a git hook (already exists for flight-status-service), not CLAUDE.md
5. Remove duplicate tool entries from agent frontmatter
6. Fix model contradictions in agent-network.md
7. Update secretary/CLAUDE.md agent roster to reflect reality
