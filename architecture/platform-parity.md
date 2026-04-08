# Platform Parity

Strawberry runs on macOS (primary) and Windows (Git Bash + Claude Code subagents). All skills and scripts are POSIX-portable by default. Platform-specific affordances are listed explicitly here and only here.

## Intent

See `plans/proposed/2026-04-09-operating-protocol-v2.md` Layer 0 for the governance contract. This document is the single source of truth for what is Mac-only, what is Windows-only, and what each platform does in place of the other.

## Skill parity

| skill | macOS | Windows | notes |
|---|---|---|---|
| `/end-session` | supported | supported | POSIX-only body. |
| `/end-subagent-session` | supported | supported | POSIX-only body. |
| `/agent-ops` | supported | supported | POSIX-only body. No macOS-specific commands. All subcommands (send, list, new) use Bash, Read, Write tools. |

## Script parity

| script | macOS | Windows | notes |
|---|---|---|---|
| `scripts/mac/launch-evelynn.sh` | supported | NOT SUPPORTED | Mac iTerm launcher for Evelynn. Windows uses Task subagent. |
| `scripts/windows/restart-evelynn.ps1` | NOT SUPPORTED | supported | Windows-only PowerShell restart helper. Marked for deletion under Operating Protocol v2 / MCP restructure D4. |
| `scripts/windows/launch-evelynn.bat` | NOT SUPPORTED | supported | Windows batch launcher. |
| `scripts/windows/launch-evelynn.ps1` | NOT SUPPORTED | supported | Windows PowerShell launcher. |
| `scripts/windows/launch-yuumi.bat` | NOT SUPPORTED | supported | Windows batch launcher for Yuumi. |
| `scripts/safe-checkout.sh` | supported | supported | POSIX. Required by CLAUDE.md Rule 5. |
| `scripts/plan-promote.sh` | supported | supported | POSIX. Required by CLAUDE.md Rule 12. |
| `scripts/plan-publish.sh` | supported | supported | POSIX. Drive mirror publish path. |
| `scripts/plan-unpublish.sh` | supported | supported | POSIX. Drive mirror unpublish path. |
| `scripts/plan-fetch.sh` | supported | supported | POSIX. Drive mirror fetch path. |
| `scripts/clean-jsonl.py` | supported | supported | Python. Used by /end-session. |
| `scripts/pre-commit-secrets-guard.sh` | supported | supported | POSIX. Required by CLAUDE.md Rule 11. |
| `scripts/mac/iterm-backgrounds/*.jpg` | supported | NOT SUPPORTED | Per-agent iTerm2 background images. Used by the Mac iTerm launcher. Not relevant on Windows. |
| `scripts/mac/launch-agent-iterm.sh` | supported | NOT SUPPORTED | macOS iTerm2 launcher for any agent. Uses osascript + grid positioning. Windows counterpart: use Task subagent — no launch script. |
| `scripts/windows/launch-agent.sh` | NOT SUPPORTED | stub only | Stub that prints non-support message and exits 2. Documents that Windows spawning is via Task subagent. |
| `scripts/list-agents.sh` | supported | supported | POSIX. Lists agents with role. |
| `scripts/new-agent.sh` | supported | supported | POSIX. Scaffolds new agent directory layout. |
| `scripts/launch-evelynn.sh` | macOS only (pre-restructure top-level copy) | NOT SUPPORTED | Unchanged by Phase 1. Windows counterpart: Task subagent. |
| `scripts/windows/restart-evelynn.ps1` | NOT SUPPORTED | supported | Windows-only PowerShell restart helper. Marked for deletion under Operating Protocol v2 / MCP restructure D4. |

(Other `scripts/*` files are pending a classification audit. They remain at the top level until the audit confirms portability or moves them.)

## MCP parity

`agent-manager` MCP is archived as of Phase 1 of the MCP restructure. `/agent-ops` replaces it on both platforms. The `evelynn` MCP is unchanged in Phase 1 and is pending Phase 2 scope.

## Launcher parity rule

**Windows has no Claude-invoked agent launcher.** Windows agent spawning is via the Claude Code `Task` subagent tool exclusively. The `.bat`/`.ps1` files under `scripts/windows/` are human-invoked (by Duong, from a Windows terminal), NOT Claude-invoked.

## Cross-references

- `plans/proposed/2026-04-09-operating-protocol-v2.md` Layer 0
- `plans/proposed/2026-04-09-mcp-restructure-phase-1-detailed.md` (Phase 1 spec — governs this document's initial content)
- `plans/proposed/2026-04-08-mcp-restructure.md` (rough plan, governs Phases 2–3)
- `plans/in-progress/2026-04-09-protocol-migration-detailed.md` (commits 5, 6, 9)
- `CLAUDE.md` Rules 16/17 (POSIX portability and MCP governance, added in Phase 1)
- `CLAUDE.md` Rules 18/19 (Roster SSOT and Universal parity, from Operating Protocol v2)
- `.claude/skills/agent-ops/SKILL.md`
