---
status: archived
owner: evelynn
created: 2026-04-08
---

# Cross-Platform MCP Setup (Mac + Windows)

## Problem

`.mcp.json` has hardcoded absolute Mac paths (`/Users/duongntd99/...`). On any other machine — like the borrowed Windows box Duong is on today — Claude Code can't connect to either MCP server. The start scripts are mostly portable, but the JSON config blocks everything before they run.

Secondary issue: `.venv/bin/python` (Mac/Linux) vs `.venv/Scripts/python.exe` (Windows) inside `start.sh`.

Tertiary issue: `agent-manager` and `helpers.py` reference iTerm2 dynamic profiles for `launch_agent`. iTerm2 doesn't exist on Windows. **Out of scope for this plan** — accept that `launch_agent` is Mac-only for now; cross-platform agent launching is a separate, larger problem.

## Goal

After this lands, Duong can clone Strawberry on any machine (Mac or Windows), run one setup command, and have both MCP servers connect successfully. Tools that don't depend on iTerm (messaging, conversations, task board, telegram, git) should work everywhere. Tools that do depend on iTerm (`launch_agent`, `restart_agents`) gracefully fail on Windows with a clear error.

## Approach

**Template + per-OS setup script.**

1. Convert `.mcp.json` to `.mcp.json.template` with placeholders: `{{WORKSPACE_PATH}}`, `{{AGENTS_PATH}}`, `{{ITERM_PROFILES_PATH}}`, `{{TELEGRAM_CHAT_ID}}`.
2. Add `.mcp.json` to `.gitignore` (it's machine-local now).
3. Add `scripts/setup-mcp.sh` (Mac/Linux) and `scripts/setup-mcp.ps1` (Windows) that:
   - Detect repo root
   - Read the template
   - Substitute placeholders with the right values for the host OS
   - Write `.mcp.json`
4. Patch `mcps/*/scripts/start.sh` to pick the right venv python path:
   ```bash
   PYTHON="$DIR/.venv/bin/python"
   [[ -f "$DIR/.venv/Scripts/python.exe" ]] && PYTHON="$DIR/.venv/Scripts/python.exe"
   exec "$PYTHON" "$DIR/server.py"
   ```
5. Guard iTerm-dependent tools in `agent-manager/server.py` and `shared/helpers.py`: detect platform, return a clear error on non-Darwin.
6. Add a one-paragraph "First-time setup" section to `architecture/mcp-servers.md` pointing at the setup scripts.

## Files Touched

- `.mcp.json` → delete from git, regenerate locally
- `.mcp.json.template` → new
- `.gitignore` → add `.mcp.json`
- `scripts/setup-mcp.sh` → new
- `scripts/setup-mcp.ps1` → new
- `mcps/agent-manager/scripts/start.sh` → patch venv path
- `mcps/evelynn/scripts/start.sh` → patch venv path
- `mcps/agent-manager/server.py` → guard iTerm tools
- `mcps/shared/helpers.py` → guard iTerm helpers
- `architecture/mcp-servers.md` → add setup section

## Out of Scope

- Cross-platform agent launching (Windows Terminal / wt.exe equivalent of iTerm dynamic profiles). Separate plan if Duong wants it.
- Migrating away from iTerm entirely.

## Validation

- On the current Windows machine: run `scripts/setup-mcp.ps1`, restart Claude Code, verify `/mcp` shows both servers connected.
- `list_agents`, `message_agent`, task board tools work.
- `launch_agent` returns a clean "not supported on Windows" error.
- On Duong's Mac next session: re-run `scripts/setup-mcp.sh`, confirm nothing regressed.

## Notes

This is a bootstrap problem — until MCP works, no Sonnet agent can be delegated to. Duong may want Evelynn to execute this directly rather than wait for normal delegation flow.
