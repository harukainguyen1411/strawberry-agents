# agent-manager (archived — Phase 1 of MCP restructure)

This MCP server is archived as of the Phase 1 MCP restructure.

Replacement surfaces:

- `/agent-ops send <agent> <message>` — inbox messaging
- `/agent-ops list` — agent roster
- `/agent-ops new <agent-name>` — scaffold a new agent
- `scripts/mac/launch-agent-iterm.sh` — macOS-only launcher
- Windows: launch via Task subagent (no script)

See:

- `plans/implemented/2026-04-09-mcp-restructure-phase-1-detailed.md` (once this plan lands)
- `plans/proposed/2026-04-08-mcp-restructure.md` (rough plan, governs Phases 2–3)
- `.claude/skills/agent-ops/SKILL.md`
- `architecture/platform-parity.md`

The Python source remains in this directory as reference. Deletion is scheduled for Phase 3.
