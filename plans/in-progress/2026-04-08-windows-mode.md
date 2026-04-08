---
status: proposed
owner: evelynn
created: 2026-04-08
supersedes: 2026-04-08-mcp-cross-platform.md
gdoc_id: 1FdazSuOcb6-AW1KnPM4LZty2TznEDozhZsO2oDqZQ0k
gdoc_url: https://docs.google.com/document/d/1FdazSuOcb6-AW1KnPM4LZty2TznEDozhZsO2oDqZQ0k/edit
---

# Windows Mode — Portable Strawberry for Borrowed Machines

## Context

Duong is on a borrowed Windows machine. The Mac Strawberry stack (iTerm2 dynamic profiles, MCP servers with hardcoded paths, Telegram relay, GH dual-account auth, Firebase task board) doesn't run here and isn't worth porting — it's load-bearing on macOS specifics.

The fix is **a parallel, isolated setup specifically for non-Mac machines**, leaving the Mac stack 100% untouched.

## Goal

When Duong sits down at any non-Mac machine with this repo cloned, he can:

1. Launch a single Claude Code session that becomes Evelynn
2. Talk to all the planning + execution agents he needs, without iTerm windows or MCP
3. Drive the session from his phone via Claude Remote Control
4. Run with `--dangerously-skip-permissions` so Evelynn doesn't stop for approvals on her own machine

The Mac stack is unaffected. Telegram relay, iTerm launcher, agent-manager MCP, firestore task board — all stay exactly as they are on Mac. This plan adds a new parallel mode, not a replacement.

## Architecture

**Two orthogonal pieces:**

### 1. Subagents replace iTerm windows

Each Strawberry agent gets a subagent definition in `.claude/agents/<name>.md`. When Evelynn (the host session) calls `Agent(subagent_type="syndra", prompt=...)`, Claude Code spawns Syndra as a subagent in an isolated context window.

The subagent definition's system prompt instructs the agent to:
1. Read its own `agents/<name>/profile.md`
2. Read `agents/<name>/memory/<name>.md`
3. Read `agents/<name>/memory/last-session.md` if it exists
4. Read `agents/memory/duong.md` and `agents/memory/agent-network.md`
5. Then perform the task and report back

**Memory continuity is preserved through files** — the same files the iTerm-window version reads. When Syndra-as-subagent finishes a meaningful task, she updates her memory file just like Mac-Syndra does. Both versions of Syndra are the same agent identity, just invoked differently.

**Initial subagent set (6):**

| Agent | Role | Why included |
|---|---|---|
| Syndra | AI strategy / planning | Most-used planner |
| Swain | Architecture / planning | System design work happens often |
| Pyke | Git & security / planning | Auth, hooks, secrets |
| Bard | MCP / integration planning | Even without MCP runtime, planning work is valuable |
| Katarina | Sonnet — quick fullstack tasks | Default executor for small jobs |
| Lissandra | Sonnet — PR review | So Duong can review PRs from anywhere |

Excluded from v1: Ornn, Fiora, Rek'Sai, Neeko, Zoe, Caitlyn, Shen, Rakan, Zilean. Add later if Duong needs them. Keep the surface area small initially.

### 2. Remote Control replaces Telegram relay (on this machine only)

Evelynn launches as a Remote Control session:

```
claude --dangerously-skip-permissions --remote-control "Evelynn"
```

Duong then connects from his phone via the Claude mobile app or claude.ai/code. Push notifications come through the app — same UX as Telegram, no bot/VPS/token rotation.

The Telegram MCP server stays untouched on Mac. This setup simply doesn't use it.

## What This Plan Does NOT Change

- `.mcp.json` — left alone (Mac paths, Mac uses it)
- `mcps/` — left alone
- Telegram bridge / bot / secrets / VPS — left alone
- iTerm dynamic profiles — left alone
- GH dual-account auth — left alone
- Firebase task board — left alone
- All existing `agents/<name>/profile.md`, memory, learnings — left alone (subagents read them as-is)

If Duong runs Strawberry on the Mac after this lands, nothing changes for him.

## Files Added

```
.claude/agents/evelynn.md          — host agent (this session's persona)
.claude/agents/syndra.md
.claude/agents/swain.md
.claude/agents/pyke.md
.claude/agents/bard.md
.claude/agents/katarina.md
.claude/agents/lissandra.md
windows-mode/README.md             — how to launch, what's available, what's not
windows-mode/launch-evelynn.bat    — wrapper that runs the right claude command
windows-mode/launch-evelynn.ps1    — PowerShell equivalent
```

## Subagent Definition Shape

Each `.claude/agents/<name>.md` follows Claude Code's standard subagent format:

```markdown
---
name: syndra
description: AI strategy and agent architecture consultant. Use for planning agent system changes, AI tooling decisions, and architectural reviews of AI features.
tools: Read, Write, Edit, Glob, Grep, Bash
---

You are Syndra, the AI strategy consultant in Duong's Strawberry agent system.

Before doing any work, read in order:
1. agents/syndra/profile.md (your personality and style)
2. agents/syndra/memory/syndra.md (your operational memory)
3. agents/syndra/memory/last-session.md (handoff from previous session, if it exists)
4. agents/memory/duong.md (Duong's profile)
5. agents/memory/agent-network.md (coordination rules)
6. agents/syndra/learnings/index.md (your learnings index)

Then complete the task you were given and report back. You are running as a subagent — there is no inbox, no message_agent, no MCP. Just files and tools. When you finish meaningful work, update your memory file before returning.

Plan-only rule: as an Opus agent, you write plans to plans/proposed/ and stop. You never self-implement.
```

The Sonnet agents (Katarina, Lissandra) get similar definitions but without the plan-only rule, and with executor instructions instead.

## Launch Flow

1. Duong opens a terminal in `C:\Users\AD\Duong\strawberry`
2. Runs `windows-mode\launch-evelynn.bat`
3. Script execs: `claude --dangerously-skip-permissions --remote-control "Evelynn"`
4. Terminal shows the remote-control session URL + QR
5. Duong can either type in the terminal or pop the QR with his phone
6. Evelynn boots, reads her startup files, and is ready

When she needs another agent, she calls `Agent(subagent_type="syndra", prompt="...")` and the subagent runs in-process.

## Validation

- `claude --version` ≥ 2.1.51 (already confirmed: 2.1.94)
- Launch script starts a session that becomes Evelynn
- Evelynn can invoke each of the 6 subagents and they correctly read their own profile + memory
- A subagent update to its memory file persists (so the next invocation sees it)
- Remote Control session URL works from a separate browser
- The Mac stack still launches and runs identically to before (verified next time Duong is on the Mac)

## Out of Scope

- Cross-platform iTerm replacement (`launch_agent` for Windows Terminal etc.) — not needed, subagents replace this
- Cross-platform MCP servers — not needed, subagents replace MCP delegation
- Migrating Mac to subagent mode — possible future plan, explicitly not part of this one
- All 16 agents — start with 6, expand on demand
- Push notifications outside the Claude mobile app — Remote Control + the app handles it

## Notes / Risks

- **Duplicate identity drift:** if Duong uses Mac-Syndra and Windows-Syndra in the same week, both write to the same `agents/syndra/memory/syndra.md`. This is fine — same file, same agent, just different invocation surfaces. As long as both versions read the file fresh on startup, no drift.
- **`--dangerously-skip-permissions` blast radius:** Evelynn won't stop for approvals on file edits, bash commands, or git operations. Subagents inherit this. Acceptable on Duong's personal machine for personal work; he's explicitly opting in.
- **Bootstrap of this plan:** MCP delegation is broken on this machine, so a Sonnet agent can't be assigned to execute. Evelynn (this session) executes directly with Duong's explicit instruction.
- **Old plan `2026-04-08-mcp-cross-platform.md`** is superseded by this one. Suggest moving it to `plans/archived/` after Duong approves this.
