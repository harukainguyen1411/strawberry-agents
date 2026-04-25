---
Supersedes: archive/pre-network-v1/system-overview.md
---

# System Overview — Strawberry v1

Strawberry is Duong's personal agent system. A network of Claude-powered agents handles life admin, side projects, health, finance, social, and learning tasks. Work tasks go through a parallel system at `~/Documents/Work/mmp/workspace/agents/` (coordinated by Sona).

## Entry point

All user-facing interaction flows through a head coordinator:

- **Personal concern** — Evelynn (default when no greeting given)
- **Work concern** — Sona (invoked as "Hey Sona")

Duong speaks to the coordinator. The coordinator delegates to specialist subagents via the Agent tool.

## Agent network

The current agent roster is maintained as live data at `agents/memory/agent-network.md`. That file is the authoritative participant list; this overview describes structure, not enumeration.

For the full agent-pair taxonomy and role-slot matrix, see `taxonomy.md`. For delegation chains, see `routing.md`.

## Repository structure

The system spans two repositories after the 2026-04-19 two-repo split.

### `harukainguyen1411/strawberry-agents` (private — agent infrastructure)

```
strawberry-agents/
├── agents/           # Agent profiles, memory, journals, learnings
│   ├── evelynn/      # Head agent — personal concern
│   ├── sona/         # Head agent — work concern
│   ├── <name>/       # Specialist subagents
│   ├── memory/       # Shared memory (agent-network.md, etc.)
│   └── health/       # Heartbeat scripts
├── architecture/     # This folder — system docs
│   ├── agent-network-v1/  # Canonical heart — law of the land
│   ├── apps/              # App-domain knowledge
│   └── archive/           # Historical record — read only
├── plans/            # Execution plans (YAML frontmatter)
├── assessments/      # Analyses, recommendations
├── scripts/          # POSIX-portable shell scripts
├── .claude/agents/   # Agent definition files
└── CLAUDE.md         # Universal invariants
```

### `harukainguyen1411/strawberry-app` (public — application code)

```
strawberry-app/
├── apps/             # Applications (portal, myapps, landing, functions, ...)
├── dashboards/       # Test and monitoring dashboards
├── .github/
│   └── workflows/    # All CI/CD workflows
├── scripts/          # Deploy, setup, and maintenance scripts
└── tools/            # Helper binaries (decrypt.sh, etc.)
```

The former monorepo `Duongntd/strawberry` is the read-only archive (90-day retention through 2026-07-18).

## Design principles

1. **Evelynn and Sona are the hubs** — all user-facing communication goes through the relevant coordinator
2. **Two-tier escalation** — subagent → coordinator → Duong
3. **Operational state is ephemeral** — `~/.strawberry/ops/` is gitignored; only memory and learnings are committed
4. **Plans are transient, architecture is permanent** — plans drive execution, `architecture/agent-network-v1/` is the lasting record
5. **Identity is explicit** — every agent def declares `model:` and operates under a named GitHub identity; no silent inheritance
