# Agent Roster — v1

This file is a 30-line roster view of the current agent network. For the full pair-mapping matrix, track model, frontmatter contracts, and routing mechanics, see `taxonomy.md`.

Live participant data (additions, retirements, status changes) is maintained at `agents/memory/agent-network.md`. That file is agent-owned data; this file is architecture canon describing the stable role structure.

---

## Coordinators

| Agent | Concern | Model |
|---|---|---|
| **Evelynn** | Personal (default when no greeting given) | Opus medium |
| **Sona** | Work (invoked as "Hey Sona") | Opus medium |

## Advisors and planners (Opus)

| Agent | Role |
|---|---|
| **Swain** | System architect — complex track |
| **Azir** | ADR planner — normal track |
| **Aphelios** | Task breakdown — complex track |
| **Kayn** | Task breakdown — normal track |
| **Xayah** | Test plan / QA audit — complex track |
| **Caitlyn** | Test plan / QA audit — normal track |
| **Neeko** | Frontend design — complex track |
| **Lulu** | Frontend design — normal track |
| **Lux** | AI/Agents/MCP specialist — complex track |
| **Heimerdinger** | DevOps advisor — single-lane |
| **Camille** | Git/GitHub/security advisor — single-lane |
| **Senna** | PR reviewer — code quality + security — single-lane |
| **Lucian** | PR reviewer — plan/ADR fidelity — single-lane |
| **Karma** | Quick-lane planner (architect + breakdown + test plan, collapsed) |

## Executors (Sonnet)

| Agent | Role |
|---|---|
| **Viktor** | Feature builder — complex track |
| **Jayce** | Feature builder — normal track |
| **Rakan** | Test implementer — complex track |
| **Vi** | Test implementer — normal track |
| **Seraphine** | Frontend implementation — complex track |
| **Soraka** | Frontend implementation — normal track |
| **Syndra** | AI/Agents/MCP normal-track executor |
| **Talon** | Quick-lane executor (builder + test impl, collapsed) |
| **Ekko** | DevOps executor + quick errands — single-lane |
| **Akali** | QA Playwright + Figma diff — single-lane |
| **Skarner** | Memory excavator — read-only — single-lane |
| **Yuumi** | Evelynn's errand runner — single-lane |
| **Lissandra** | Memory consolidator — coordinator close protocol — single-lane |
| **Orianna** | Plan lifecycle gatekeeper — callable via Agent tool at `.claude/agents/orianna.md` — single-lane |

---

See `taxonomy.md` for the full role-slot matrix, track model rationale, and frontmatter contracts.
See `routing.md` for the delegation chains Evelynn uses to route work.
See `agents/memory/agent-network.md` for the live roster including status, pair-mate links, and auto-isolation flags.
