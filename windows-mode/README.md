# Windows Mode

Portable Strawberry setup for non-Mac machines (borrowed laptops, travel boxes, anywhere the Mac stack doesn't run).

## What this is

A parallel, isolated mode for running Evelynn without:

- iTerm2 dynamic profiles
- MCP servers (`agent-manager`, `evelynn`)
- Telegram relay / VPS bridge / bot tokens
- GH dual-account auth dance
- Firebase task board

The Mac stack stays untouched. This mode adds new files only — it doesn't change anything Mac-side.

## How it works

**Subagents replace iTerm windows.** Each Strawberry agent has a definition in `.claude/agents/<name>.md`. When Evelynn (the host session) needs another agent, she invokes them via Claude Code's built-in `Agent` tool. The subagent runs in an isolated context window inside the same Claude Code process. No new terminal, no MCP, no IPC.

**Remote Control replaces Telegram relay.** Evelynn launches with `--remote-control`, registering a session with the Anthropic API. Duong drives the session from his phone via the Claude mobile app or claude.ai/code. Push notifications come through the app.

**Memory continuity is preserved through files.** Subagents read the same `agents/<name>/memory/<name>.md`, `learnings/`, and `last-session.md` files the Mac iTerm versions read. The two invocation paths (iTerm window on Mac vs subagent on Windows) are the same agent identity.

## How to launch

From a terminal in the repo root:

```cmd
windows-mode\launch-evelynn.bat
```

Or PowerShell:

```powershell
windows-mode\launch-evelynn.ps1
```

This runs:

```
claude --dangerously-skip-permissions --remote-control "Evelynn"
```

Once the session starts, you'll see a Remote Control session URL and a QR code prompt. Open the URL in any browser, or press spacebar in the terminal to show the QR code and scan it from the Claude mobile app.

You don't need to type "Hey Evelynn" — per `CLAUDE.md`, Evelynn is the default agent when no greeting is given. Just start with whatever you need.

## Available subagents

| Agent | Tier | Role |
|---|---|---|
| Syndra | Opus | AI strategy / agent architecture planning |
| Swain | Opus | System architecture planning |
| Pyke | Opus | Git workflows & IT security planning |
| Bard | Opus | MCP & tool integration planning |
| Katarina | Sonnet | Quick fullstack tasks (executor) |
| Lissandra | Sonnet | PR review (logic, security, edge cases) |

To add more agents: write `.claude/agents/<name>.md` following the same shape as existing definitions.

## What's NOT available in Windows Mode

- `launch_agent` — no iTerm, no Windows Terminal equivalent
- `message_agent` / inbox — no persistent agent processes to message
- Multi-agent conversations (`start_turn_conversation` etc.) — no MCP
- `telegram_send_message` / `telegram_poll_messages` — no bot, no bridge
- Firebase task board MCP tools
- `commit_agent_state_to_main` — Evelynn commits manually here
- Heartbeats, journals, session logs — write manually if needed

If you need any of the above, you're on the wrong machine — go back to the Mac.

## `--dangerously-skip-permissions`

Evelynn launches with this flag on this machine, by Duong's explicit choice. It means:

- Evelynn will edit files, run bash commands, and make git operations without stopping for approval prompts
- Subagents she spawns inherit the same permission level
- Acceptable scope: Duong's personal machine, personal repo, personal work

Don't run this in a borrowed environment that has access to anything you don't want touched.

## See also

- `plans/in-progress/2026-04-08-windows-mode.md` — the plan that introduced this mode
- `architecture/agent-system.md` — the full Strawberry agent system design (Mac-centric)
- `CLAUDE.md` — project rules (apply to both modes)
