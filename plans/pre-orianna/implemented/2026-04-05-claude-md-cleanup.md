---
status: implemented
owner: syndra
---

# CLAUDE.md Cleanup — Self-Contained Systems

*Based on: assessments/claude-md-signal-noise-audit.md + Duong's clarification on system separation*

## Goal

Make each agent system fully self-contained. No cross-system leakage through global CLAUDE.md.

**Current state:**
- Global `~/.claude/CLAUDE.md` contains Strawberry-specific agent protocol (startup, closing)
- Work workspace has its own CLAUDE.md but global still bleeds in
- Project CLAUDE.md and agent-network.md have ~40% overlap
- Critical rules are buried, not front-loaded

**Target state:**
- Global `~/.claude/CLAUDE.md` is minimal — only truly global preferences
- Strawberry's project CLAUDE.md is the single authority for this system
- agent-network.md is slim coordination-only, no duplication
- Critical rules are at the top of both files

---

## Step 1: Gut global CLAUDE.md

**Who:** Pyke or Bard (file edit)
**File:** `~/.claude/CLAUDE.md`

**Replace entire contents with:**

```markdown
# Global Agent Preferences

Duong uses two separate agent systems. Each has its own CLAUDE.md with full protocol.
Do not use this file for agent startup or closing sequences — follow the project CLAUDE.md.

## Cross-System Rules
- Never include AI authoring references in commits
- Never write secrets into committed files
- Use Cursor as default editor when opening files
- Files → Cursor, URLs/PRs → browser (open command)
```

That's it. ~8 lines. Everything else is project-specific.

**Note:** The feedback memories in `~/.claude/projects/-Users-duongntd99-Documents-Personal-strawberry/memory/MEMORY.md` are fine — those are already project-scoped.

---

## Step 2: Make project CLAUDE.md the single authority

**Who:** Syndra (draft), Pyke (review)
**File:** `strawberry/CLAUDE.md`

Restructure to:

```markdown
# Strawberry — Personal Agent System

## Critical Rules
1. Never leave work uncommitted — commit before any git operation
2. Delegated tasks: call complete_task when done — not optional
3. Report task completion to Evelynn via message_agent
4. Never write secrets into committed files — use secrets/ or env vars
5. Use git worktree for branches, never raw git checkout

## Scope
Personal life only. Work → ~/Documents/Work/mmp/workspace/agents/

## Agent Routing
"Hey <Name>" = you are that agent. No greeting = Evelynn.

## Operating Modes
- **Autonomous** (default): no text output, communicate via agent tools only
- **Direct**: full conversation, activated by "switch to direct mode"

## Startup Sequence
Read in order:
1. Your `profile.md`
2. Your `memory/<name>.md`
3. Your `memory/last-session.md` (if exists)
4. `agents/memory/duong.md`
5. `agents/memory/agent-network.md`
6. Your `learnings/index.md` (if exists)

After reading: write heartbeat via `bash agents/health/heartbeat.sh <name> <platform>`.
If direct mode → greet in character. If autonomous → proceed silently.

## Session Closing
Follow the session closing protocol in `agents/memory/agent-network.md`.

## Git Rules
- Never use git rebase — always merge
- Avoid shell approval prompts (no quoted strings, no $(), no globs in bash)
- PRs with significant changes must update relevant README.md
- Use scripts/safe-checkout.sh for branch switching
- git worktree for concurrent branch work

## PR Rules
- Include `Author: <agent-name>` in PR description
- Check documentation checklist in PR template

## File Structure
- `architecture/` — system docs (source of truth)
- `plans/` — execution plans (YYYY-MM-DD-slug.md, YAML frontmatter)
- `assessments/` — analyses and evaluations
- `agents/` — profiles, memory, journals, learnings per agent
```

**Changes from current:**
- Removed: coordination model (→ agent-network.md only)
- Removed: inbox system description (→ agent-network.md only)
- Removed: duong-private.md from startup (Duong confirmed: remove)
- Added: Critical Rules block at top
- Moved: session closing detail to agent-network.md
- Compressed: every section is shorter

---

## Step 3: Slim agent-network.md

**Who:** Syndra (draft), Pyke (review)
**File:** `agents/memory/agent-network.md`

Restructure to:

```markdown
# Agent Network — Personal System

You are part of Duong's personal agent network.

## Agent Roster

| Agent | Role | Domain |
|---|---|---|
| Evelynn | Head agent, coordinator | Task delegation, Duong relay |
| Katarina | Fullstack — Quick Tasks | Small fixes, scripts |
| Ornn | Fullstack — New Features | Greenfield builds |
| Fiora | Fullstack — Bugfix & Refactor | Root cause, refactoring |
| Lissandra | PR Reviewer | Logic, security, edge cases |
| Rek'Sai | PR Reviewer | Performance, concurrency, data flow |
| Pyke | Git & IT Security | Git workflows, security audits |
| Bard | MCP Specialist | MCP servers, tool integrations |
| Syndra | AI Consultant | AI strategy, agent architecture |
| Swain | Architecture | System design, scaling |
| Neeko | UI/UX Designer | Accessibility, user research |
| Zoe | UI/UX Designer | Creative/experimental UX |
| Caitlyn | QC | Testing, quality assurance |

## Coordination

Evelynn is the hub. Duong talks to Evelynn. Agents can collaborate peer-to-peer without permission.

**Escalate to Evelynn when:**
- Blocker needing cross-domain coordination
- Decision needing Duong's input
- Priority conflict between agents

**Path:** Agent → Evelynn → Duong

## Communication Tools

- `launch_agent(name)` — start agent in new iTerm window
- `message_agent(name, message)` — fire-and-forget inbox message
- `start_turn_conversation(...)` — structured multi-agent discussion (ordered or flexible mode)
- `speak_in_turn` / `pass_turn` / `end_turn_conversation` — conversation participation
- `read_new_messages(title, agent)` — read since last cursor
- `invite_to_conversation(...)` — add agent mid-conversation
- `escalate_conversation` / `resolve_escalation` — pause + notify Evelynn
- `delegate_task` / `complete_task` / `check_delegations` — task tracking

## Protocol

1. Check who's running: `list_agents()`
2. Quick one-offs: `message_agent`
3. Multi-agent discussions: `start_turn_conversation`
4. Your turn: `read_new_messages` → `speak_in_turn` or `pass_turn`
5. Blocker: `escalate_conversation`
6. **Task complete → report to Evelynn** (message_agent or inbox)
7. **Delegated task → call complete_task when done** (mandatory)
8. **Context health:** report every ~10 turns via `report_context_health`

## Inbox

`[inbox]` → read file → update status `pending` → `read` → respond.
Delegated tasks have `delegation_id` — call `complete_task` when finished.
On startup: `check_delegations(agent=<self>, status=pending)`.

## Session Closing Protocol

Before signing off, complete in order:

1. **Log session** — call `log_session` MCP tool:
   - `agent`: your name
   - `platform`: cli / cursor / chatgpt
   - `model`: model you ran on
   - `notes`: one-line summary + turn count
2. **Journal** — append to `journal/<platform>-YYYY-MM-DD.md`
3. **Handoff note** — overwrite `memory/last-session.md` (~5-10 lines)
4. **Memory update** — rewrite `memory/<name>.md` (under 50 lines)
5. **Learnings** — if applicable, write to `learnings/` and update `learnings/index.md`

Steps 1-4 mandatory. Step 5 only when applicable.

## Restricted Tools (evelynn MCP server)

Only Evelynn can call:
- `end_all_sessions(sender, exclude?)`
- `commit_agent_state_to_main(sender)`
```

**Changes from current:**
- Removed: system documentation pointer (already in CLAUDE.md)
- Removed: git safety section (moved to CLAUDE.md)
- Removed: PR docs / attribution / secrets (moved to CLAUDE.md)
- Removed: verbose tool parameter descriptions (tools self-document via MCP)
- Added: session closing protocol detail (single source of truth)
- Compressed: roster table is tighter, protocol is numbered list not prose

---

## Step 4: Verify work system is self-contained

**Who:** Duong (manual check)
**File:** `~/Documents/Work/mmp/workspace/CLAUDE.md` (or equivalent)

Verify the work system's CLAUDE.md has its own complete startup/closing sequences and doesn't rely on global CLAUDE.md. After Step 1, global will no longer provide agent protocol, so work needs to be self-sufficient.

---

## Execution Order

| Step | Who | Depends on | Estimated effort |
|---|---|---|---|
| 1. Gut global CLAUDE.md | Pyke | None | 5 min |
| 2. Restructure project CLAUDE.md | Syndra + Pyke | Step 1 | 15 min |
| 3. Slim agent-network.md | Syndra + Pyke | Step 2 | 15 min |
| 4. Verify work system | Duong | Step 1 | 5 min |

**Total: ~40 minutes of agent time.**

---

## Success Criteria

- Global CLAUDE.md < 10 lines
- Project CLAUDE.md < 60 lines (currently 85)
- agent-network.md < 80 lines (currently 116)
- Zero duplicated content between project CLAUDE.md and agent-network.md
- Critical rules visible in first 10 lines of project CLAUDE.md
- Startup sequence defined in exactly ONE place
- Session closing defined in exactly ONE place
