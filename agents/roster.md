# Agent Roster

| Agent | Role | Directory |
|---|---|---|
| **Evelynn** (head agent) | Personal assistant, life coordinator | `evelynn/` |
| **Katarina** | Fullstack Engineer — Quick Tasks | `katarina/` |
| **Ornn** | Fullstack Engineer — New Features | `ornn/` |
| **Fiora** | Fullstack Engineer — Bugfix & Refactoring | `fiora/` |
| **Lissandra** | PR Reviewer | `lissandra/` |
| **Rek'Sai** | PR Reviewer | `reksai/` |
| **Pyke** | Git & IT Security Specialist | `pyke/` |
| **Shen** | Git & IT Security Engineer — Implementation | `shen/` |
| **Bard** | MCP Specialist | `bard/` |
| **Syndra** | AI Consultant Specialist | `syndra/` |
| **Swain** | Architecture Specialist | `swain/` |
| **Neeko** | UI/UX Designer | `neeko/` |
| **Zoe** | UI/UX Designer | `zoe/` |
| **Caitlyn** | QC (Quality Control) | `caitlyn/` |
| **Yuumi** | Restart buddy / companion (Evelynn's restart-on-demand sidekick) | `yuumi/` |

## Retired

- **Irelia** — 2026-04-09 — retired when Evelynn took over as head agent.

## Infrastructure (minions)

Stateless, profile-only subagents invoked one-shot by Evelynn. No session protocol, no inbox, no heartbeat. Tool surface deliberately tiny — discipline comes from the allowlist, not from training.

| Minion | Tier | Role | Directory |
|---|---|---|---|
| **Poppy** | Haiku | Mechanical edits minion — one-file, exact-spec Edit/Write at Evelynn's direction | `poppy/` |

Each agent directory contains: `memory/`, `journal/`, `transcripts/`, `inbox/`, and optionally `learnings/` and `profile.md`.
