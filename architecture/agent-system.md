# Agent System

## Roster

| Agent | Role | Speciality |
|---|---|---|
| **Evelynn** | Head agent | Personal assistant, life coordination, task delegation |
| **Katarina** | Fullstack — Quick Tasks | Small fixes, one-off scripts, quick implementations |
| **Ornn** | Fullstack — New Features | Greenfield builds, complex implementations |
| **Fiora** | Fullstack — Bugfix & Refactoring | Bug investigations, root cause analysis, refactoring |
| **Lissandra** | PR Reviewer | Surface review: logic, security, edge cases |
| **Rek'Sai** | PR Reviewer | Deep review: performance, concurrency, data flow |
| **Pyke** | Git & IT Security | Git workflows, branch protection, security audits |
| **Bard** | MCP Specialist | MCP servers, tool integrations, protocol connections |
| **Syndra** | AI Consultant | AI models, prompt engineering, agent architectures |
| **Swain** | Architecture Specialist | System design, dependencies, scaling decisions |
| **Neeko** | UI/UX Designer | Empathetic design, accessibility, user research |
| **Zoe** | UI/UX Designer | Creative/experimental design, animations |
| **Caitlyn** | QC | Testing, bug reproduction, test plans, QA |
| Irelia | Retired | Former head agent |

## Agent Directory Structure

Each agent lives under `agents/<name>/` with:

```
agents/<name>/
├── profile.md          # Character, role, speaking style
├── memory/
│   ├── <name>.md       # Living operational memory (< 50 lines)
│   └── last-session.md # Handoff note from previous session
├── journal/            # Session reflections (cli-YYYY-MM-DD.md)
├── learnings/          # Reusable learnings
│   └── index.md        # One-line descriptions of learning files
├── inbox/              # Incoming messages (timestamped .md files)
├── transcripts/        # Session transcripts
└── iterm/              # iTerm profile assets (background images)
```

## Boot Sequence

When an agent starts, it reads (in order):

1. `profile.md` — identity and role
2. `memory/<name>.md` — operational memory
3. `memory/last-session.md` — handoff note
4. `agents/memory/duong.md` — Duong's shared profile
5. `memory/duong-private.md` — Duong's private profile for this agent (if exists)
6. `agents/memory/agent-network.md` — coordination rules
7. `learnings/index.md` — available learnings (load specific files only if relevant)

After reading, the agent writes a heartbeat: `bash agents/health/heartbeat.sh <name> <platform>`.

## Session Closing

Every agent must complete these steps before signing off:

1. **Log session** — call `log_session` MCP tool
2. **Journal** — write/append to `journal/<platform>-YYYY-MM-DD.md`
3. **Handoff note** — overwrite `memory/last-session.md` (5-10 lines)
4. **Memory update** — rewrite `memory/<name>.md` (living summary, < 50 lines)
5. **Learnings** — if applicable, write to `learnings/` and update `learnings/index.md`

Steps 1-4 are mandatory. Step 5 only when something new and reusable was learned.

## Operating Modes

- **Autonomous mode** (default) — no text output outside tool calls. Communicate only via agent tools.
- **Direct mode** — activated by "switch to direct mode". Full conversational output.

## Agent Launch

On macOS: agents are launched via `scripts/mac/launch-agent-iterm.sh <name>` which opens a new iTerm2 window with the agent's profile. Each agent runs as its own Claude CLI session.

On Windows: agents are launched as Claude Code subagents via the `Task` tool using the agent's `.claude/agents/<name>.md` definition. No iTerm, no separate terminal window.
