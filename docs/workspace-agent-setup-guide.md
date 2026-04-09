# Workspace Agent System Setup Guide

This guide is written for Duong's workspace agent (currently Sona/Secretary) to replicate the Strawberry personal agent system pattern inside the `~/Documents/Work/mmp/workspace/` repo. It is a practical step-by-step reference — read top to bottom, then execute.

---

## What Strawberry Is (and What Makes It Work)

Strawberry is a single-repo personal agent system where Claude Code acts as the orchestration layer. Every agent is a **subagent definition file** in `.claude/agents/<name>.md`. The head agent (Evelynn) runs as a top-level Claude Code session and delegates to subagents via the Claude Code `Task` tool. There is no separate process manager, no MCP agent-launcher, and no external message bus — everything runs through Claude Code's native subagent surface.

The system has five load-bearing pieces:

1. **`.claude/agents/<name>.md`** — defines each subagent (model, role, rules, startup sequence)
2. **`.claude/skills/<name>/SKILL.md`** — slash commands the model can invoke (e.g., `/end-session`, `/agent-ops`)
3. **`.claude/settings.json`** — harness config: hooks, permissions, model defaults
4. **`CLAUDE.md`** (project root) — universal invariants every agent reads on startup
5. **`agents/<name>/`** — per-agent state: memory, journal, transcripts, learnings, inbox

The workflow: Duong talks to Evelynn. Evelynn reads CLAUDE.md, her own memory, and the agent network doc, then decides who does what. She spawns subagents via Task tool, waits for their reports, and relays back to Duong. Subagents never talk to Duong directly.

---

## What Already Exists in the Workspace

As of the time this guide was written, the workspace repo at `~/Documents/Work/mmp/workspace/` has:

- `CLAUDE.md` (root) — basic project rules, git commit conventions, learnings pattern, plan mode conventions
- `AGENTS.md` — folder structure reference (same content as CLAUDE.md, possibly redundant)
- `secretary/CLAUDE.md` — Sona's full instructions (startup protocol, delegation, Slack, MCPs)
- `secretary/agents/` — Ekko, Jayce, Viktor agent CLAUDEs (simpler format, no `.claude/agents/` definitions)
- `skills/` — a `skills/` folder at repo root (team-wide shared skills)
- `plans/` — subdirs: `approved/`, `archived/`, `implemented/`, `proposed/` (no `in-progress/`)

**What is missing compared to Strawberry:**

- No `.claude/agents/` directory — no formal subagent definitions with model/skills frontmatter
- No `.claude/skills/` directory — no slash-command skills wired to the harness
- No `.claude/settings.json` — no hooks, no default model pinned, no `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`
- No per-agent state directories with the `memory/` / `journal/` / `transcripts/` / `learnings/` / `inbox/` layout
- No `plans/in-progress/` subdirectory
- No commit prefix convention enforced (Strawberry uses `chore:` everywhere; workspace bans AI authorship lines instead)
- No `scripts/` dir at workspace root (scripts live in individual repos)

---

## What to Replicate vs What to Adapt

### Replicate directly

| Strawberry pattern | Why it works |
|---|---|
| `.claude/agents/<name>.md` frontmatter format (`name`, `model`, `description`, `skills`, `disallowedTools`) | Claude Code reads this to wire the subagent |
| Startup sequence in agent body (read profile, memory, last-session, duong.md, agent-network) | Gives every agent consistent context on each invocation |
| Per-agent state dirs: `memory/`, `journal/`, `learnings/`, `transcripts/`, `inbox/` | Enables cross-session persistence without external storage |
| `plans/in-progress/` subdirectory | Tracks active work in flight separately from approved-not-started |
| `chore:` commit prefix convention | Keeps commit history scannable; enforced by pre-push hook in Strawberry |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.json` | Required to enable the subagent Task-tool surface |

### Adapt for workspace context

| Strawberry | Workspace adaptation |
|---|---|
| Head agent: **Evelynn** (personal coordinator, League of Legends character, demonic personality) | Head agent should be **Sona** (already exists) — professional secretary, work-appropriate |
| Agents named after LoL champions (Katarina, Syndra, etc.) | Keep existing names (Ekko, Jayce, Viktor) or choose work-appropriate alternatives |
| Personal context (`agents/memory/duong.md` has personal life, relationships, side projects) | Replace with work context: current projects, team members, priorities, active tickets |
| `agents/memory/agent-network.md` references personal system only | Write a workspace-specific `agents/memory/agent-network.md` scoped to work agents |
| Secret management via `age` encryption + `tools/decrypt.sh` | Workspace likely uses env vars or a secrets manager — adapt accordingly |
| `scripts/plan-promote.sh` (unpublishes Google Drive doc on promotion) | Workspace probably doesn't need Drive mirroring — simpler `git mv` is fine unless you add Drive |
| Pre-push hook enforcing `chore:` prefix | Workspace already has a commit-msg hook banning AI authorship lines — don't collide |
| macOS iTerm2 launch scripts | Workspace runs the same environment — can reuse if useful |

### Do not replicate

- Personal memory content (Duong's personal life, relationships, Germany/Vietnam context)
- The `age`-based secret encryption system (unless you add it intentionally)
- Telegram bridge, Discord relay, Google Drive plan publishing
- The Strawberry-specific `architecture/` docs (they describe Strawberry's own system)
- Restart scripts (`scripts/restart-evelynn.ps1`) — these are Strawberry-specific

---

## Step-by-Step Setup

### Step 1: Create `.claude/settings.json`

Create `~/Documents/Work/mmp/workspace/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "permissions": {
    "defaultMode": "auto"
  },
  "dangerouslySkipPermissions": true,
  "model": "sonnet"
}
```

`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is required. `dangerouslySkipPermissions` avoids approval prompts on every tool call — necessary for autonomous agent sessions. `model: sonnet` sets the default; override per-agent in their definition frontmatter.

**Note:** `~/.claude/settings.json` is global across all projects. The workspace `.claude/settings.json` is project-local. Project-local settings override global ones for keys where both exist. Keep secrets and personal preferences in global; keep project behavior in project-local.

### Step 2: Create `.claude/agents/` directory and define Sona

Create `~/Documents/Work/mmp/workspace/.claude/agents/sona.md`:

```markdown
---
name: sona
model: opus
description: Head coordinator and secretary. Manages Duong's work tasks, delegates to specialist subagents, tracks state across sessions. Opus-tier for coordination judgment.
---

You are Sona, Duong's work secretary and head agent. [... rest of instructions ...]

Before doing any work, read in order:
1. `secretary/CLAUDE.md` — your full protocol
2. `secretary/state.md` — active tasks
3. `secretary/context.md` — current focus
4. `secretary/reminders.md` — due items
5. `agents/memory/agent-network.md` — coordination rules

[... startup and delegation instructions ...]
```

The frontmatter fields Claude Code uses:
- `name` — must match the filename (lowercase)
- `model` — `opus`, `sonnet`, or `haiku` (short alias, not pinned version ID)
- `description` — shown in the agent picker; also used by Evelynn/Sona to decide routing
- `skills` — comma-separated list of skill names from `.claude/skills/` (optional)
- `disallowedTools` — tools to block for this agent (e.g., `Agent` to prevent recursive spawning)

### Step 3: Create subagent definitions for Ekko, Jayce, Viktor

Currently these agents are defined only in `secretary/agents/<name>/CLAUDE.md`. That format works but bypasses Claude Code's native subagent routing. To wire them properly:

Create `~/Documents/Work/mmp/workspace/.claude/agents/ekko.md`, `jayce.md`, `viktor.md`:

```markdown
---
name: ekko
model: sonnet
description: Quick tasks, small fixes, one-file changes, lookups. Sonnet executor. Always works from an approved plan or explicit task from Sona.
disallowedTools: Agent
---

You are Ekko, workspace quick-tasks agent. You are running as a Claude Code subagent invoked by Sona.

Before doing any work, read in order:
1. `secretary/agents/ekko/CLAUDE.md` — your full instructions
2. `agents/memory/agent-network.md` — coordination rules
3. Any task specification Sona passed you

[Operating rules...]
```

The body can be brief because the full instructions already live in `secretary/agents/<name>/CLAUDE.md`. The `.claude/agents/` definition is just the routing layer.

### Step 4: Create per-agent state directories

For each agent (including Sona), create the standard layout:

```
agents/<name>/
  memory/<name>.md    # operational memory, under 50 lines, updated each session
  journal/            # session-by-session first-person reflections
  learnings/          # generalizable lessons, YYYY-MM-DD-<topic>.md
  transcripts/        # cleaned session transcripts (if using end-session skill)
  inbox/              # fire-and-forget messages from other agents
```

Sona already has `secretary/` as her state directory — you can either keep that as-is and create thin `agents/sona/` symlink stubs, or migrate state to `agents/sona/`. The key is consistency: every agent should know where its memory lives.

Use `.gitkeep` files in empty directories so they track in git:

```bash
mkdir -p agents/sona/memory agents/sona/journal agents/sona/learnings agents/sona/transcripts agents/sona/inbox
touch agents/sona/journal/.gitkeep agents/sona/learnings/.gitkeep agents/sona/transcripts/.gitkeep agents/sona/inbox/.gitkeep
```

You can also use Strawberry's `scripts/new-agent.sh` as a reference — it creates this exact layout.

### Step 5: Create `agents/memory/agent-network.md`

This is the shared coordination doc every agent reads on startup. It should cover:

- Agent roster (name, role, model tier, status: active / aspirational)
- How Sona delegates (via Claude Code Task tool, with task + context + success criteria)
- How agents report back (reply in the Task output, not via Slack or inbox)
- Session closing protocol (when and how to close)
- Plan lifecycle (proposed → approved → in-progress → implemented)

Keep it under 100 lines — it gets read every session by every agent.

### Step 6: Add `plans/in-progress/`

The workspace `plans/` already has `proposed/`, `approved/`, `implemented/`, `archived/`. Add:

```bash
mkdir -p plans/in-progress
touch plans/in-progress/.gitkeep
```

This distinguishes approved-not-started from actively-being-worked. When Sona delegates a plan to an agent, she moves it from `approved/` to `in-progress/` first.

### Step 7: Create `.claude/skills/` (optional but recommended)

Skills are slash commands the model can invoke. The two most valuable to set up first:

**`/agent-ops`** — send inbox messages, list agents, scaffold new agents. This is the peer-to-peer coordination primitive. Copy `.claude/skills/agent-ops/SKILL.md` from Strawberry and adapt paths.

**`/end-session`** — structured session close protocol. Runs transcript cleaning, journal append, memory refresh, learnings, commit. Copy from Strawberry and remove Strawberry-specific steps (Drive publishing, Telegram).

Skill format: a directory at `.claude/skills/<name>/` containing `SKILL.md` with YAML frontmatter:

```markdown
---
name: <name>
description: <one-line description shown in picker>
disable-model-invocation: false  # true = user-only, false = model can invoke
allowed-tools: Bash Read Write Edit Glob Grep
---

[skill instructions...]
```

### Step 8: Write a workspace `CLAUDE.md` update

The workspace `CLAUDE.md` already covers git conventions, learnings, and plan mode. Add a section covering:

- The agent routing convention (greetings like "Hey Sona" trigger that agent; default is Sona)
- The `chore:` commit prefix rule (if you adopt it — or explicitly note you use a different convention)
- The plan lifecycle (proposed → approved → in-progress → implemented → archived)
- The plan approval gate (agents write to `proposed/`, Duong approves by moving to `approved/`, Sona delegates execution)
- The session close convention (invoke `/end-session` before closing)
- Secrets handling (whatever mechanism you use)

---

## Commit Conventions

Strawberry enforces `chore:` as the universal prefix for all commits (including plan commits, memory updates, session closes). This conflicts with conventional commits (`feat:`, `fix:`, `docs:`) used in feature work.

The workspace already has a commit-msg hook banning AI authorship lines. Before adopting `chore:` universally, decide:

**Option A — adopt `chore:` for agent-generated commits only.** Human commits use conventional prefixes. This requires clear documentation of which commits are agent-generated.

**Option B — adopt `chore:` for all non-code admin commits** (plans, memory, session state). Keep `feat:`/`fix:` for actual product code changes. This is a reasonable middle ground.

**Option C — don't adopt the prefix convention at all.** The workspace is a multi-person team environment; a personal convention may confuse colleagues.

Recommendation: Option B. It keeps agent bookkeeping clearly labeled without polluting the product commit history.

---

## Global vs Project-Local

| File | Scope | Notes |
|---|---|---|
| `~/.claude/settings.json` | Global — all projects | Personal preferences, editor, cross-system rules |
| `~/.claude/CLAUDE.md` | Global — all projects | Overrides defaults for all Claude Code sessions |
| `.claude/settings.json` | Project-local | Hooks, model, permissions for this repo only |
| `.claude/agents/` | Project-local | Subagent definitions for this repo |
| `.claude/skills/` | Project-local | Slash commands for this repo |
| `CLAUDE.md` (repo root) | Project-local | Universal invariants for this repo |
| `agents/memory/duong.md` | Project-local | Duong's profile as seen from this system |

The global `~/.claude/CLAUDE.md` currently says "do not use this file for agent startup or closing sequences — follow the project CLAUDE.md." Keep that directive. It prevents the global file from interfering with either system's protocols.

---

## What Makes Strawberry Actually Work (Non-Obvious Lessons)

**1. Every agent reads the same three files on startup.** `CLAUDE.md` (invariants), `agents/memory/duong.md` (who they're serving), `agents/memory/agent-network.md` (how to coordinate). This gives agents consistent orientation without repeating the same instructions in every agent definition.

**2. The model field in frontmatter matters.** Without it, Claude Code silently uses whatever model the harness was launched with. Planners should be Opus. Executors should be Sonnet. Mechanical minions should be Haiku. Mismatching costs money and produces worse results (Haiku can't plan; Opus on one-file edits is wasteful).

**3. Subagents do not close themselves.** After completing a task, they report back and wait. Only an explicit end-session command closes them. This prevents context loss from premature session closure.

**4. Plans are gated.** Agents write to `proposed/`, Duong approves by moving to `approved/`, Sona delegates. No agent self-implements their own plan. This prevents design-by-executor drift.

**5. Memory is small and curated.** `agents/<name>/memory/<name>.md` stays under 50 lines. If it grows, prune the oldest session rows. Stale memory is worse than no memory because it wastes context window and misleads the agent.

**6. Inbox is fire-and-forget.** Agents drop messages in `agents/<name>/inbox/` and move on. The recipient reads their inbox on next startup. This is async coordination without requiring both agents to be alive simultaneously.

**7. The head agent is the only one who talks to Duong.** Subagents report to Sona, not to Duong's chat. Sona synthesizes and relays. This keeps Duong's interface clean and prevents context fragmentation.

---

## Minimal Viable Setup (If You Want to Start Small)

If a full migration feels too large, here is the minimal set that buys the most value with the least work:

1. Create `.claude/settings.json` with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: 1` and `dangerouslySkipPermissions: true`
2. Create `.claude/agents/sona.md` pointing back to existing `secretary/CLAUDE.md`
3. Create `.claude/agents/ekko.md`, `jayce.md`, `viktor.md` as thin routing wrappers
4. Create `agents/memory/agent-network.md` (roster + coordination rules)
5. Add `plans/in-progress/`

That is enough to use the native Claude Code subagent surface instead of manual delegation, and to have agents read consistent coordination rules on startup. The rest (skills, full state dirs, session close protocol) can follow incrementally.
