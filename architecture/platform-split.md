# Mac / Windows / GCE Platform Split Contract

## Overview

Duong runs Strawberry across three environments with strictly separated roles. This document defines the invariants that keep the shared git repository consistent.

## Mac (Interactive)

- Runs Evelynn sessions, planning, coordination, and the full agent roster.
- Commits agent state to `main`: transcripts, memory, journal entries, learnings, plan promotions.
- Uses `git worktree` for branch isolation; never raw `git checkout`.
- Session closing protocol (`/end-session`, `/end-subagent-session`) archives transcripts and refreshes memory.

## Windows (Autonomous)

- Runs the coder-worker in headless mode (`claude -p`).
- Polls labeled GitHub issues and executes implementation work.
- Creates branches named `bot/issue-{number}` only. Never pushes to `main`.
- Never writes to `agents/`, `plans/`, `architecture/`, or `.claude/`.
- No interactive sessions; no session closing protocol; no transcript generation.

## GCE (Autonomous)

- Runs bee-worker on an `e2-micro` VM (Debian 12) as a systemd service.
- Polls Firestore job queue and invokes Claude Code headlessly (`claude -p`).
- Same constraints as Windows: never writes to agent state, never pushes to main.
- Claude Code authenticates via `claude login` (OAuth, Claude Max). Health check cron alerts on auth expiry.
- Deployment scripts: `scripts/gce/`. Service unit: `scripts/gce/bee-worker.service`.

## Shared

- Same agent roster definitions in `.claude/agents/` (read-only on Windows).
- Same commit conventions: `chore:` / `ops:` prefix required.
- Same `CLAUDE.md` rules loaded by Claude Code automatically.
- Same pre-commit hooks (gitleaks, secrets check).

## Hard Invariants

1. **Separate git clones.** Mac and Windows must never share the same git clone directory. `git checkout -B` on Windows would destroy Mac's working tree if the clone were shared.
2. **Windows never touches agent state.** `agents/`, `plans/`, `architecture/`, `.claude/` are off-limits for the coder-worker — enforced by the system prompt and by scoped `git add apps/myapps/`.
3. **Windows never pushes to main.** Branch protection requires PR review; the worker only pushes to `bot/issue-{number}` branches.
4. **Mac owns the session lifecycle.** Only Mac sessions run `/end-session` or `/end-subagent-session`. The Windows worker has no slash commands and no closing protocol.
