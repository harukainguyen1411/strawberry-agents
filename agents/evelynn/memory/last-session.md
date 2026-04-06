# Last Session — 2026-04-06 evening, CLI (Opus)

- Work agent isolation system fully implemented
- Three-tier architecture: Coordinator → Planners (Opus) → Workers (Sonnet)
- Plan at plans/implemented/2026-04-06-work-agent-isolation.md
- MCP server at ~/Documents/Work/mmp/workspace/agents/mcps/work-agent-manager/
- Duong can start Claude in /workspace, say "Hey Coordinator" — greeting-based routing
- Launch script: no --model/--settings for coordinator+planner (inherit default Opus 1M), --model sonnet for workers
- .mcp.json only sets AGENT_BASE_DIR — role vars omitted so parent env passes through

Open threads (carried over):
- PR #54 (myapps) ready to merge, needs firestore index deploy
- Bard's launch-verification + Evelynn liveness plan — proposed, awaiting approval
- Swain's plan viewer plan — proposed, needs manual setup
- Stale PRs #26 #27 #28 — can be closed
