# MCP Project-Scope Migration

## Context

User-scope MCPs (registered via `claude mcp add -s user`) are stored in `~/.claude/` and available globally. Project-scope MCPs are stored in `.mcp.json` at the workspace root and scoped to that project.

## Key Findings

1. **MCP config storage**: User-scope MCPs are NOT in `~/.claude/settings.json`. They're managed by Claude Code CLI and stored separately. Use `claude mcp list` and `claude mcp get <name>` to inspect them.

2. **Project-scope storage**: Project MCPs go into `.mcp.json` at the repo root (not `.claude/settings.json`). Added via `claude mcp add --scope project`.

3. **Missing scripts/start.sh is a common failure mode**: Three MCPs (`gcalendar`, `spotler`, `slack-relay`) were failing because `scripts/start.sh` didn't exist. The gcalendar one was fixable — it's a Node.js MCP with `dist/index.js` present. Spotler and slack-relay are missing their `server.py` source entirely (orphaned `.venv` and `.env` only).

4. **Spotler and slack-relay are broken at source level**: These dirs are untracked in the mcps repo (`git ls-files` shows nothing). The `.pyc` cache suggests `server.py` existed once but is gone. These need source recovery before they'll work.

## How to Migrate

```bash
# For each user-scope MCP
claude mcp add --scope project -t stdio <name> bash /path/to/scripts/start.sh
# This writes to .mcp.json
```

## What Stays Broken

- `spotler` and `slack-relay`: need `server.py` restored. Check if they have a separate git repo or were deleted accidentally.
- `goodmem` plugin: plugin-layer issue, not MCP config issue.
